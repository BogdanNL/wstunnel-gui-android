import 'dart:async';
import 'dart:io';
import '../models/wstunnel_config.dart';
import 'wstunnel_ffi.dart';
import 'foreground_service.dart';

class WstunnelService {
  final StreamController<String> _logController = StreamController<String>.broadcast();
  final List<String> _logs = [];
  bool _isRunning = false;
  Timer? _logPollTimer;

  Stream<String> get logStream => _logController.stream;
  List<String> get logs => List.unmodifiable(_logs);
  bool get isRunning => _isRunning;

  WstunnelService() {
    _addLog('=== WstunnelService CONSTRUCTOR ===');
    // Initialize FFI when creating service
    try {
      _addLog('Initializing FFI...');
      WstunnelFFI.initialize();
      _addLog('FFI initialized successfully');
      
      // Set up log callback
      _addLog('Setting up log callback...');
      WstunnelFFI.setLogCallback((message) {
        try {
          _addLog('[FFI] $message');
        } catch (e) {
          // Don't use _addLog here to avoid recursion
          print('ERROR in log callback: $e');
        }
      });
      _addLog('Log callback set successfully');
      _addLog('=== WstunnelService CONSTRUCTOR COMPLETED ===');
    } catch (e, stackTrace) {
      _addLog('=== ERROR IN CONSTRUCTOR ===');
      _addLog('Error type: ${e.runtimeType}');
      _addLog('Error initializing FFI: $e');
      _addLog('Stack trace: $stackTrace');
      _addLog('=== END CONSTRUCTOR ERROR ===');
    }
  }

  Future<void> start(WstunnelConfig config) async {
    _addLog('=== START METHOD CALLED ===');
    if (_isRunning) {
      _addLog('Already running');
      return;
    }

    try {
      _addLog('Starting wstunnel via FFI...');
      _addLog('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      _addLog('Config: local=${config.localAddress}:${config.localPort}, remote=${config.remoteUrl}');
      _addLog('About to call WstunnelFFI.startClient...');

      // Call FFI function to start client
      _addLog('Calling FFI startClient with parameters:');
      _addLog('  - localAddress: ${config.localAddress}');
      _addLog('  - localPort: ${config.localPort}');
      _addLog('  - remoteUrl: ${config.remoteUrl}');
      _addLog('  - httpUpgradePathPrefix: ${config.httpUpgradePathPrefix}');
      _addLog('  - connectionMinIdle: ${config.connectionMinIdle}');
      
      final result = WstunnelFFI.startClient(
        localAddress: config.localAddress,
        localPort: config.localPort,
        remoteUrl: config.remoteUrl,
        httpUpgradePathPrefix: config.httpUpgradePathPrefix,
        connectionMinIdle: config.connectionMinIdle,
      );

      _addLog('FFI startClient returned with result: $result');

      if (result == 0) {
        _addLog('Setting _isRunning to true...');
        _isRunning = true;
        _addLog('Wstunnel client started successfully');
        
        // Start foreground service for background operation (Android only)
        if (Platform.isAndroid) {
          _addLog('Starting foreground service for background operation...');
          final serviceStarted = await ForegroundService.start();
          if (serviceStarted) {
            _addLog('Foreground service started successfully');
          } else {
            _addLog('Warning: Failed to start foreground service, tunnel may stop in background');
          }
        }
        
        _addLog('State updated, method will return now');
        
        // Start periodic log queue polling
        _startLogPolling();
      } else {
        _addLog('Failed to start wstunnel client (error code: $result)');
        _isRunning = false;
      }
      _addLog('=== START METHOD COMPLETED ===');
    } catch (e, stackTrace) {
      _isRunning = false;
      _addLog('=== EXCEPTION IN START METHOD ===');
      _addLog('Error type: ${e.runtimeType}');
      _addLog('Error starting wstunnel: $e');
      _addLog('Stack trace: $stackTrace');
      _addLog('=== END EXCEPTION ===');
    }
  }

  Future<void> stop() async {
    _addLog('=== STOP METHOD CALLED ===');
    if (!_isRunning) {
      _addLog('Not running');
      return;
    }

    try {
      // Stop log polling
      _stopLogPolling();
      
      _addLog('Stopping wstunnel...');
      _addLog('Calling WstunnelFFI.stop()...');
      WstunnelFFI.stop();
      _addLog('WstunnelFFI.stop() returned');
      
      // Stop foreground service (Android only)
      if (Platform.isAndroid) {
        _addLog('Stopping foreground service...');
        final serviceStopped = await ForegroundService.stop();
        if (serviceStopped) {
          _addLog('Foreground service stopped successfully');
        } else {
          _addLog('Warning: Failed to stop foreground service');
        }
      }
      
      _isRunning = false;
      _addLog('Wstunnel client stopped');
      _addLog('=== STOP METHOD COMPLETED ===');
    } catch (e, stackTrace) {
      _addLog('=== EXCEPTION IN STOP METHOD ===');
      _addLog('Error type: ${e.runtimeType}');
      _addLog('Error stopping: $e');
      _addLog('Stack trace: $stackTrace');
      _addLog('=== END EXCEPTION ===');
      _isRunning = false;
    }
  }

  /// Start periodic log queue polling
  void _startLogPolling() {
    _stopLogPolling(); // Stop previous timer if exists
    _logPollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        // Get all available logs from queue
      while (true) {
        final log = WstunnelFFI.getNextLog();
        if (log == null) {
          break; // Queue is empty
        }
        _addLog('[FFI] $log');
      }
    });
  }

  /// Stop periodic log queue polling
  void _stopLogPolling() {
    _logPollTimer?.cancel();
    _logPollTimer = null;
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    final logMessage = '[$timestamp] $message';
    _logs.add(logMessage);
    if (!_logController.isClosed) {
      _logController.add(logMessage);
    }
  }

  void clearLogs() {
    _logs.clear();
    // Send special message to update UI after clearing
    if (!_logController.isClosed) {
      _logController.add('[LOGS_CLEARED]');
    }
  }

  void dispose() {
    _stopLogPolling();
    if (_isRunning) {
      try {
        WstunnelFFI.stop();
        // Stop foreground service on dispose
        if (Platform.isAndroid) {
          ForegroundService.stop();
        }
      } catch (e) {
        // Ignore errors on stop
      }
    }
    _logController.close();
  }
}
