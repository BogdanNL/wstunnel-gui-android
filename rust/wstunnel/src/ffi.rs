use crate::config::Client;
use crate::executor::DefaultTokioExecutor;
use crate::tunnel::LocalProtocol;
use crate::create_client_tunnels;
use parking_lot::Mutex;
use std::collections::VecDeque;
use std::ffi::{CStr, CString};
use std::io::{self, LineWriter, Write};
use std::os::raw::{c_char, c_int};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tokio::runtime::Runtime;
use url::Url;

// Global state for managing runtime and client
struct WstunnelState {
    runtime_thread: Option<std::thread::JoinHandle<()>>,
    stop_tx: Option<tokio::sync::oneshot::Sender<()>>,
}

static STATE: Mutex<Option<WstunnelState>> = Mutex::new(None);

// Thread-safe queue for logs (instead of direct callback calls)
static LOG_QUEUE: Mutex<VecDeque<String>> = Mutex::new(VecDeque::new());
const MAX_LOG_QUEUE_SIZE: usize = 1000;

// Callback for logs (used only from main thread)
type LogCallback = extern "C" fn(*const c_char);

static LOG_CALLBACK: Mutex<Option<LogCallback>> = Mutex::new(None);

// Flag to track tracing subscriber initialization
static TRACING_INITIALIZED: AtomicBool = AtomicBool::new(false);

// Add message to log queue (can be called from any thread)
fn log_message(message: &str) {
    let mut queue = LOG_QUEUE.lock();
    queue.push_back(message.to_string());
    
    // Limit queue size
    while queue.len() > MAX_LOG_QUEUE_SIZE {
        queue.pop_front();
    }
}

// Custom writer for tracing that sends logs to log_message()
struct LogQueueWriter {
    buffer: Vec<u8>,
}

impl LogQueueWriter {
    fn new() -> Self {
        Self {
            buffer: Vec::new(),
        }
    }
}

impl Write for LogQueueWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        // Debug message (only first few times)
        static WRITE_COUNT: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
        let count = WRITE_COUNT.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        if count < 10 {
            log_message(&format!("[TRACING DEBUG] LogQueueWriter::write() called #{} with {} bytes, buffer size: {}", 
                count, buf.len(), self.buffer.len()));
        }
        
        self.buffer.extend_from_slice(buf);
        
        // If buffer contains newline, send message immediately
        if buf.contains(&b'\n') {
            if count < 10 {
                log_message("[TRACING DEBUG] Found newline in buffer, will flush");
            }
            // Force flush
            let _ = self.flush();
        }
        
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        // Debug message (only first few times)
        static FLUSH_COUNT: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
        let count = FLUSH_COUNT.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        if count < 10 {
            log_message(&format!("[TRACING DEBUG] LogQueueWriter::flush() called #{} with buffer size: {}", 
                count, self.buffer.len()));
        }
        
        // When flush is called, send accumulated message to log queue
        if !self.buffer.is_empty() {
            if let Ok(message) = String::from_utf8(self.buffer.clone()) {
                let message = message.trim_end();
                if !message.is_empty() {
                    if count < 10 {
                        log_message(&format!("[TRACING DEBUG] Sending message to log_message(): {}", message));
                    }
                    log_message(message);
                } else {
                    if count < 10 {
                        log_message("[TRACING DEBUG] Message is empty after trim, skipping");
                    }
                }
            } else {
                if count < 10 {
                    log_message("[TRACING DEBUG] Failed to convert buffer to UTF-8 string");
                }
            }
            self.buffer.clear();
        } else {
            if count < 10 {
                log_message("[TRACING DEBUG] Buffer is empty, nothing to flush");
            }
        }
        Ok(())
    }
}

// Initialize tracing subscriber to intercept logs
fn init_tracing_subscriber() {
    log_message("[TRACING DEBUG] init_tracing_subscriber() called");
    
    // Check if subscriber is already initialized
    let was_initialized = !TRACING_INITIALIZED.compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst).is_ok();
    
    if was_initialized {
        log_message("[TRACING DEBUG] Tracing subscriber already initialized, skipping");
        return;
    }
    
    log_message("[TRACING DEBUG] Creating tracing subscriber...");
    
    // Create subscriber with custom writer and INFO filter by default
    // Use function that returns new writer for each event
    let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| {
            log_message("[TRACING DEBUG] Using default filter: info");
            tracing_subscriber::EnvFilter::new("info")
        });
    
    log_message(&format!("[TRACING DEBUG] EnvFilter created: {:?}", env_filter));
    
    // Use LineWriter for automatic flush on newline
    let subscriber = tracing_subscriber::fmt()
        .with_writer(|| LineWriter::new(LogQueueWriter::new()))
        .with_target(false) // Remove target from logs for brevity
        .with_thread_ids(false) // Remove thread IDs
        .with_thread_names(false) // Remove thread names
        .with_ansi(false) // Disable ANSI colors
        .with_env_filter(env_filter)
        .finish();
    
    log_message("[TRACING DEBUG] Subscriber created, setting as global default...");
    
    // Set subscriber as global
    match tracing::subscriber::set_global_default(subscriber) {
        Ok(_) => {
            log_message("[TRACING DEBUG] Tracing subscriber set successfully!");
            
            // Verify that subscriber is actually set
            if tracing::dispatcher::has_been_set() {
                log_message("[TRACING DEBUG] Subscriber has been set (verified)");
            } else {
                log_message("[TRACING DEBUG] WARNING: Subscriber may not be set correctly!");
            }
            
            log_message("[TRACING DEBUG] Testing with info! macro...");
            // Try sending test message via tracing
            tracing::info!("[TRACING TEST] This is a test message from tracing::info! macro");
            
            // Give some time for processing
            std::thread::sleep(std::time::Duration::from_millis(10));
            
            // Check that message reached the queue
            let queue_size = LOG_QUEUE.lock().len();
            log_message(&format!("[TRACING DEBUG] Queue size after test message: {}", queue_size));
        }
        Err(e) => {
            log_message(&format!("[TRACING DEBUG] ERROR: Failed to set tracing subscriber: {:?}", e));
        }
    }
}

// Call callback directly (only from main thread)
unsafe fn log_message_direct(message: &str) {
    if let Some(callback) = *LOG_CALLBACK.lock() {
        match CString::new(message) {
            Ok(c_str) => {
                callback(c_str.as_ptr());
            }
            Err(e) => {
                // If failed to create CString (e.g., contains null bytes),
                // try to send error message
                if let Ok(error_msg) = CString::new(format!("[LOG_ERROR] Failed to create CString: {}", e)) {
                    callback(error_msg.as_ptr());
                }
            }
        }
    }
}

/// Set callback for logs
#[unsafe(no_mangle)]
pub extern "C" fn wstunnel_set_log_callback(callback: LogCallback) {
    *LOG_CALLBACK.lock() = Some(callback);
}

/// Get next message from log queue
/// Returns pointer to CString or null if queue is empty
/// Caller must free memory via wstunnel_free_log_message
#[unsafe(no_mangle)]
pub extern "C" fn wstunnel_get_next_log() -> *mut c_char {
    let mut queue = LOG_QUEUE.lock();
    
    if let Some(message) = queue.pop_front() {
        match CString::new(message.clone()) {
            Ok(c_str) => c_str.into_raw(),
            Err(_) => std::ptr::null_mut(),
        }
    } else {
        std::ptr::null_mut()
    }
}

/// Free memory allocated for log message
#[unsafe(no_mangle)]
pub extern "C" fn wstunnel_free_log_message(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Start wstunnel client
/// 
/// Parameters:
/// - local_address: local address to bind (e.g., "127.0.0.1")
/// - local_port: local port
/// - remote_url: remote server URL (e.g., "wss://example.com")
/// - http_upgrade_path_prefix: path prefix for HTTP upgrade
/// - connection_min_idle: minimum number of idle connections
/// 
/// Returns: 0 on success, -1 on error
#[unsafe(no_mangle)]
pub extern "C" fn wstunnel_start_client(
    local_address: *const c_char,
    local_port: c_int,
    remote_url: *const c_char,
    http_upgrade_path_prefix: *const c_char,
    connection_min_idle: c_int,
) -> c_int {
    unsafe {
        log_message("[START] wstunnel_start_client called - BEFORE init_tracing_subscriber");
        
        // Initialize tracing subscriber to intercept logs from info!, warn!, error! etc.
        init_tracing_subscriber();
        
        log_message("[START] wstunnel_start_client called - AFTER init_tracing_subscriber");
        log_message(&format!("[START] Parameters: local_port={}, connection_min_idle={}", local_port, connection_min_idle));
        
        let local_addr = match CStr::from_ptr(local_address).to_str() {
            Ok(s) => s,
            Err(_) => {
                log_message("Error: Invalid local_address");
                return -1;
            }
        };

        let remote_url_str = match CStr::from_ptr(remote_url).to_str() {
            Ok(s) => s,
            Err(_) => {
                log_message("Error: Invalid remote_url");
                return -1;
            }
        };

        let path_prefix = match CStr::from_ptr(http_upgrade_path_prefix).to_str() {
            Ok(s) => s,
            Err(_) => {
                log_message("Error: Invalid http_upgrade_path_prefix");
                return -1;
            }
        };

        log_message("Parsing remote URL...");
        // Parse remote URL
        let remote_url_parsed = match Url::parse(remote_url_str) {
            Ok(url) => {
                log_message(&format!("Remote URL parsed successfully: {}", url));
                url
            }
            Err(e) => {
                log_message(&format!("Error parsing remote URL: {}", e));
                return -1;
            }
        };

        log_message("Parsing local address...");
        // Parse local address
        let local_socket_addr = match format!("{}:{}", local_addr, local_port).parse() {
            Ok(addr) => {
                log_message(&format!("Local address parsed successfully: {}", addr));
                addr
            }
            Err(e) => {
                log_message(&format!("Error parsing local address: {}", e));
                return -1;
            }
        };

        log_message("Creating client configuration...");
        log_message(&format!("[CONFIG] local_address={}, local_port={}, remote_url={}, path_prefix={}, min_idle={}", 
            local_addr, local_port, remote_url_str, path_prefix, connection_min_idle));
        
        // Create client configuration
        // For socks5 tunnel, remote is not used as it's a dynamic proxy
        let client_config = Client {
            local_to_remote: vec![crate::config::LocalToRemote {
                local_protocol: LocalProtocol::Socks5 {
                    timeout: Some(Duration::from_secs(30)),
                    credentials: None,
                },
                local: local_socket_addr,
                remote: (
                    url::Host::Domain("0.0.0.0".to_string()),
                    0,
                ), // Not used for socks5
            }],
            remote_to_local: vec![],
            socket_so_mark: None,
            connection_min_idle: connection_min_idle as u32,
            connection_retry_max_backoff: Duration::from_secs(300),
            reverse_tunnel_connection_retry_max_backoff: Duration::from_secs(1),
            tls_sni_override: None,
            tls_sni_disable: false,
            tls_ech_enable: false,
            tls_verify_certificate: false,
            http_proxy: None,
            http_proxy_login: None,
            http_proxy_password: None,
            http_upgrade_path_prefix: path_prefix.to_string(),
            http_upgrade_credentials: None,
            websocket_ping_frequency: Some(Duration::from_secs(30)),
            websocket_mask_frame: false,
            http_headers: vec![],
            http_headers_file: None,
            remote_addr: remote_url_parsed,
            tls_certificate: None,
            tls_private_key: None,
            dns_resolver: vec![],
            dns_resolver_prefer_ipv4: false,
        };
        log_message("Client configuration created successfully");
        log_message(&format!("[CONFIG] local_to_remote count: {}", client_config.local_to_remote.len()));
        log_message(&format!("[CONFIG] remote_to_local count: {}", client_config.remote_to_local.len()));
        if let Some(tunnel) = client_config.local_to_remote.first() {
            log_message(&format!("[CONFIG] First tunnel: local={:?}, protocol={:?}", tunnel.local, tunnel.local_protocol));
        }

        log_message("Creating stop channel...");
        let (stop_tx, stop_rx) = tokio::sync::oneshot::channel();
        log_message("Stop channel created");

        // Start runtime in separate thread
        log_message("Spawning runtime thread...");
        let runtime_thread = std::thread::spawn(move || {
            log_message("[THREAD] Runtime thread started");
            
            // Test call to tracing::info!() from runtime thread
            tracing::info!("[TRACING TEST FROM THREAD] This is a test message from runtime thread");
            
            // Create runtime in this thread
            log_message("[THREAD] Creating Tokio runtime...");
            let runtime = match Runtime::new() {
                Ok(rt) => {
                    log_message("[THREAD] Tokio runtime created successfully");
                    // Another test call after creating runtime
                    tracing::info!("[TRACING TEST FROM THREAD] Tokio runtime created, testing tracing again");
                    rt
                }
                Err(e) => {
                    log_message(&format!("[THREAD] Error creating runtime: {}", e));
                    return;
                }
            };

            log_message("[THREAD] Entering runtime.block_on...");
            runtime.block_on(async {
                log_message("[ASYNC] Starting wstunnel client...");
                
                log_message("[ASYNC] Getting Tokio handle...");
                let handle = tokio::runtime::Handle::current();
                log_message("[ASYNC] Creating executor...");
                let executor = DefaultTokioExecutor::new(handle.clone());
                log_message("[ASYNC] Executor created");
                
                log_message("[ASYNC] Calling create_client_tunnels...");
                // Test call to tracing::info!() from async context
                tracing::info!("[TRACING TEST FROM ASYNC] This is a test message from async context before create_client_tunnels");
                
                match create_client_tunnels(client_config, executor).await {
                    Ok(tunnels) => {
                        log_message(&format!("[ASYNC] Created {} tunnels", tunnels.len()));
                        // Another test call after creating tunnels
                        tracing::info!("[TRACING TEST FROM ASYNC] Tunnels created successfully, testing tracing again");
                        
                        if tunnels.is_empty() {
                            log_message("[ASYNC] WARNING: No tunnels were created! This is likely a configuration issue.");
                        }
                        
                        // Start all tunnels in parallel
                        log_message("[ASYNC] Spawning tunnel tasks...");
                        let mut join_handles = Vec::new();
                        for (i, tunnel) in tunnels.into_iter().enumerate() {
                            log_message(&format!("[ASYNC] Spawning tunnel {}...", i));
                            let start_time = std::time::Instant::now();
                            let tunnel_handle = handle.spawn(async move {
                                log_message(&format!("[TUNNEL {}] Tunnel task started", i));
                                tunnel.await;
                                let duration = start_time.elapsed();
                                log_message(&format!("[TUNNEL {}] Tunnel task completed after {:?}", i, duration));
                                if duration.as_secs() < 1 {
                                    log_message(&format!("[TUNNEL {}] WARNING: Tunnel completed very quickly ({}ms), this might indicate an error", i, duration.as_millis()));
                                }
                            });
                            join_handles.push(tunnel_handle);
                        }
                        log_message(&format!("[ASYNC] Spawned {} tunnel tasks", join_handles.len()));

                        // Wait for either stop signal or completion of all tunnels
                        log_message("[ASYNC] Setting up select! to wait for tunnels or stop signal...");
                        let wait_all = async {
                            log_message("[ASYNC] Waiting for all tunnels to complete...");
                            // Wait for all tunnels to complete
                            for (i, handle) in join_handles.into_iter().enumerate() {
                                log_message(&format!("[ASYNC] Waiting for tunnel {}...", i));
                                match handle.await {
                                    Ok(_) => log_message(&format!("[ASYNC] Tunnel {} completed successfully", i)),
                                    Err(e) => log_message(&format!("[ASYNC] Tunnel {} panicked or was cancelled: {:?}", i, e)),
                                }
                            }
                            log_message("[ASYNC] All tunnels finished");
                        };
                        
                        log_message("[ASYNC] Entering tokio::select!...");
                        tokio::select! {
                            _ = stop_rx => {
                                log_message("[ASYNC] Stop signal received");
                                // Cancel all tunnels - they will be cancelled on exit from select
                            }
                            _ = wait_all => {
                                log_message("[ASYNC] All tunnels finished (from select)");
                            }
                        }
                        log_message("[ASYNC] Exited tokio::select!");
                    }
                    Err(e) => {
                        log_message(&format!("[ASYNC] Error creating tunnels: {}", e));
                        log_message(&format!("[ASYNC] Error details: {:?}", e));
                    }
                }
                log_message("[ASYNC] Async block completed");
            });
            log_message("[THREAD] Runtime block_on completed");
        });
        log_message("Runtime thread spawned successfully");

        // Save state
        log_message("Saving state to global STATE...");
        *STATE.lock() = Some(WstunnelState {
            runtime_thread: Some(runtime_thread),
            stop_tx: Some(stop_tx),
        });
        log_message("State saved successfully");

        log_message("Wstunnel client started successfully");
        log_message("Returning 0 from wstunnel_start_client");
        0
    }
}

/// Stop wstunnel client
#[unsafe(no_mangle)]
pub extern "C" fn wstunnel_stop() {
    unsafe {
        log_message("[STOP] wstunnel_stop called");
        let mut state = STATE.lock();
        log_message("[STOP] State lock acquired");
        if let Some(mut s) = state.take() {
            log_message("[STOP] State found, stopping...");
            if let Some(tx) = s.stop_tx.take() {
                log_message("[STOP] Sending stop signal...");
                match tx.send(()) {
                    Ok(_) => log_message("[STOP] Stop signal sent successfully"),
                    Err(e) => log_message(&format!("[STOP] Error sending stop signal: {:?}", e)),
                }
            } else {
                log_message("[STOP] No stop_tx found");
            }
            // Wait for runtime thread to complete
            if let Some(thread) = s.runtime_thread.take() {
                log_message("[STOP] Waiting for runtime thread to join...");
                match thread.join() {
                    Ok(_) => log_message("[STOP] Runtime thread joined successfully"),
                    Err(e) => log_message(&format!("[STOP] Error joining runtime thread: {:?}", e)),
                }
            } else {
                log_message("[STOP] No runtime_thread found");
            }
            log_message("[STOP] Wstunnel client stopped");
        } else {
            log_message("[STOP] Wstunnel client is not running");
        }
        log_message("[STOP] wstunnel_stop completed");
    }
}

/// Check if client is running
#[unsafe(no_mangle)]
pub extern "C" fn wstunnel_is_running() -> c_int {
    let state = STATE.lock();
    if state.is_some() {
        1
    } else {
        0
    }
}

