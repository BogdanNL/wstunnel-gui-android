import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Callback type for logs
typedef LogCallbackNative = Void Function(Pointer<Utf8>);
typedef LogCallback = void Function(Pointer<Utf8>);

// Native functions
typedef WstunnelSetLogCallbackNative = Void Function(Pointer<NativeFunction<LogCallbackNative>>);
typedef WstunnelSetLogCallback = void Function(Pointer<NativeFunction<LogCallbackNative>>);

typedef WstunnelStartClientNative = Int32 Function(
  Pointer<Utf8>,
  Int32,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Int32,
);
typedef WstunnelStartClient = int Function(
  Pointer<Utf8>,
  int,
  Pointer<Utf8>,
  Pointer<Utf8>,
  int,
);

typedef WstunnelStopNative = Void Function();
typedef WstunnelStop = void Function();

typedef WstunnelIsRunningNative = Int32 Function();
typedef WstunnelIsRunning = int Function();

typedef WstunnelGetNextLogNative = Pointer<Utf8> Function();
typedef WstunnelGetNextLog = Pointer<Utf8> Function();

typedef WstunnelFreeLogMessageNative = Void Function(Pointer<Utf8>);
typedef WstunnelFreeLogMessage = void Function(Pointer<Utf8>);

/// FFI bindings for libwstunnel.so
class WstunnelFFI {
  static DynamicLibrary? _lib;
  static bool _initialized = false;

  static WstunnelSetLogCallback? _setLogCallback;
  static WstunnelStartClient? _startClient;
  static WstunnelStop? _stop;
  static WstunnelIsRunning? _isRunning;
  static WstunnelGetNextLog? _getNextLog;
  static WstunnelFreeLogMessage? _freeLogMessage;

  // Global callback for logs (must be static for FFI)
  static void Function(String)? _logCallback;

  /// Initialize library
  static void initialize() {
    if (_initialized) return;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libwstunnel.so');
      } else {
        // For other platforms use process()
        _lib = DynamicLibrary.process();
      }

      // Get functions
      _setLogCallback = _lib!
          .lookup<NativeFunction<WstunnelSetLogCallbackNative>>('wstunnel_set_log_callback')
          .asFunction();

      _startClient = _lib!
          .lookup<NativeFunction<WstunnelStartClientNative>>('wstunnel_start_client')
          .asFunction();

      _stop = _lib!
          .lookup<NativeFunction<WstunnelStopNative>>('wstunnel_stop')
          .asFunction();

      _isRunning = _lib!
          .lookup<NativeFunction<WstunnelIsRunningNative>>('wstunnel_is_running')
          .asFunction();

      _getNextLog = _lib!
          .lookup<NativeFunction<WstunnelGetNextLogNative>>('wstunnel_get_next_log')
          .asFunction();

      _freeLogMessage = _lib!
          .lookup<NativeFunction<WstunnelFreeLogMessageNative>>('wstunnel_free_log_message')
          .asFunction();

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize wstunnel FFI: $e');
    }
  }

  /// Static function for FFI callback (must be static)
  static void _nativeLogCallback(Pointer<Utf8> ptr) {
    try {
      if (ptr.address == 0) {
        print('[FFI DEBUG] Received null pointer in log callback');
        return;
      }
      final message = ptr.toDartString();
      if (_logCallback != null) {
        _logCallback!.call(message);
      } else {
        print('[FFI DEBUG] Log callback is null, message: $message');
      }
    } catch (e, stackTrace) {
      print('[FFI DEBUG] ERROR in _nativeLogCallback: $e');
      print('[FFI DEBUG] Stack trace: $stackTrace');
    }
  }

  /// Set callback for logs
  static void setLogCallback(void Function(String message) callback) {
    if (!_initialized) initialize();

    // Save callback
    _logCallback = callback;

    // Create native callback from static function
    final nativeCallback = Pointer.fromFunction<LogCallbackNative>(
      _nativeLogCallback,
    );

    _setLogCallback!(nativeCallback);
  }

  /// Start wstunnel client
  static int startClient({
    required String localAddress,
    required int localPort,
    required String remoteUrl,
    required String httpUpgradePathPrefix,
    required int connectionMinIdle,
  }) {
    print('[FFI DEBUG] startClient called');
    try {
      if (!_initialized) {
        print('[FFI DEBUG] Not initialized, initializing...');
        initialize();
      }

      print('[FFI DEBUG] Converting strings to native UTF8...');
      final localAddrPtr = localAddress.toNativeUtf8();
      final remoteUrlPtr = remoteUrl.toNativeUtf8();
      final pathPrefixPtr = httpUpgradePathPrefix.toNativeUtf8();
      print('[FFI DEBUG] Strings converted successfully');

      try {
        print('[FFI DEBUG] Calling native _startClient function...');
        final result = _startClient!(
          localAddrPtr,
          localPort,
          remoteUrlPtr,
          pathPrefixPtr,
          connectionMinIdle,
        );
        print('[FFI DEBUG] Native _startClient returned: $result');
        return result;
      } catch (e, stackTrace) {
        print('[FFI DEBUG] ERROR calling _startClient: $e');
        print('[FFI DEBUG] Stack trace: $stackTrace');
        rethrow;
      } finally {
        print('[FFI DEBUG] Freeing native memory...');
        malloc.free(localAddrPtr);
        malloc.free(remoteUrlPtr);
        malloc.free(pathPrefixPtr);
        print('[FFI DEBUG] Memory freed');
      }
    } catch (e, stackTrace) {
      print('[FFI DEBUG] FATAL ERROR in startClient: $e');
      print('[FFI DEBUG] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Stop wstunnel client
  static void stop() {
    print('[FFI DEBUG] stop() called');
    try {
      if (!_initialized) {
        print('[FFI DEBUG] Not initialized, initializing...');
        initialize();
      }
      print('[FFI DEBUG] Calling native _stop function...');
      _stop!();
      print('[FFI DEBUG] Native _stop returned');
    } catch (e, stackTrace) {
      print('[FFI DEBUG] ERROR in stop: $e');
      print('[FFI DEBUG] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if client is running
  static bool isRunning() {
    if (!_initialized) initialize();
    return _isRunning!() != 0;
  }

  /// Get next message from log queue
  /// Returns null if queue is empty
  static String? getNextLog() {
    if (!_initialized) initialize();
    try {
      final ptr = _getNextLog!();
      if (ptr.address == 0) {
        return null;
      }
      final message = ptr.toDartString();
      _freeLogMessage!(ptr);
      return message;
    } catch (e) {
      print('[FFI DEBUG] Error getting next log: $e');
      return null;
    }
  }
}
