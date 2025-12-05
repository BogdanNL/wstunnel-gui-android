import 'dart:io';

class WstunnelConfig {
  String localAddress = '127.0.0.1';
  int localPort = 60000;
  int connectionMinIdle = 5;
  String httpUpgradePathPrefix = 'secret';
  String remoteUrl = 'wss://myhost.example.org';

  WstunnelConfig();

  Map<String, dynamic> toJson() {
    return {
      'localAddress': localAddress,
      'localPort': localPort,
      'connectionMinIdle': connectionMinIdle,
      'httpUpgradePathPrefix': httpUpgradePathPrefix,
      'remoteUrl': remoteUrl,
    };
  }

  factory WstunnelConfig.fromJson(Map<String, dynamic> json) {
    final config = WstunnelConfig();
    config.localAddress = json['localAddress'] ?? '127.0.0.1';
    config.localPort = json['localPort'] ?? 60000;
    config.connectionMinIdle = json['connectionMinIdle'] ?? 5;
    config.httpUpgradePathPrefix = json['httpUpgradePathPrefix'] ?? 'secret';
    config.remoteUrl = json['remoteUrl'] ?? 'wss://myhost.example.org';
    return config;
  }

  Map<String, String> toCommandLineArgs() {
    return {
      'local': 'socks5://$localAddress:$localPort',
      'connection-min-idle': connectionMinIdle.toString(),
      'http-upgrade-path-prefix': httpUpgradePathPrefix,
      'remote': remoteUrl,
    };
  }

  List<String> buildCommand(String binaryPath) {
    final args = toCommandLineArgs();
    return [
      binaryPath,
      'client',
      '-L',
      args['local']!,
      '--connection-min-idle',
      args['connection-min-idle']!,
      '--http-upgrade-path-prefix',
      args['http-upgrade-path-prefix']!,
      args['remote']!,
    ];
  }

  /// Validate configuration. Returns Map with field names and error messages.
  /// If Map is empty, validation passed successfully.
  Future<Map<String, String>> validate() async {
    final errors = <String, String>{};

    if (localAddress.trim().isEmpty) {
      errors['localAddress'] = 'Local Address cannot be empty';
    }

    if (localPort <= 0 || localPort > 65535) {
      errors['localPort'] = 'Local Port must be in range 1-65535';
    }

    if (connectionMinIdle < 0) {
      errors['connectionMinIdle'] = 'Connection Min Idle cannot be negative';
    }

    if (httpUpgradePathPrefix.trim().isEmpty) {
      errors['httpUpgradePathPrefix'] = 'HTTP Upgrade Path Prefix cannot be empty';
    }

    final trimmedUrl = remoteUrl.trim();
    if (trimmedUrl.isEmpty) {
      errors['remoteUrl'] = 'Remote URL cannot be empty';
    } else {
      // Check for ws:// or wss:// prefix
      if (!trimmedUrl.startsWith('ws://') && !trimmedUrl.startsWith('wss://')) {
        errors['remoteUrl'] = 'Remote URL must start with ws:// or wss://';
      } else {
        // Extract host from URL
        try {
          final uri = Uri.parse(trimmedUrl);
          final host = uri.host;
          
          if (host.isEmpty) {
            errors['remoteUrl'] = 'Remote URL must contain a valid hostname';
          } else {
            // Check DNS resolution
            try {
              final addresses = await InternetAddress.lookup(host);
              if (addresses.isEmpty) {
                errors['remoteUrl'] = 'Hostname "$host" cannot be resolved (DNS lookup failed)';
              }
            } on SocketException catch (e) {
              errors['remoteUrl'] = 'Hostname "$host" cannot be resolved: ${e.message}';
            } catch (e) {
              errors['remoteUrl'] = 'Hostname "$host" cannot be resolved: $e';
            }
          }
        } on FormatException catch (e) {
          errors['remoteUrl'] = 'Invalid URL format: ${e.message}';
        } catch (e) {
          errors['remoteUrl'] = 'Invalid URL: $e';
        }
      }
    }

    return errors;
  }
}
