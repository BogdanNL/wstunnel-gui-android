import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/wstunnel_config.dart';
import '../services/wstunnel_service.dart';
import '../services/config_storage.dart';

class ConfigTab extends StatefulWidget {
  final WstunnelConfig config;
  final VoidCallback onConfigChanged;
  final WstunnelService? wstunnelService;
  final Map<String, String> validationErrors;

  const ConfigTab({
    super.key,
    required this.config,
    required this.onConfigChanged,
    this.wstunnelService,
    this.validationErrors = const {},
  });

  @override
  State<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<ConfigTab> {
  late TextEditingController _localAddressController;
  late TextEditingController _localPortController;
  late TextEditingController _connectionMinIdleController;
  late TextEditingController _httpUpgradePrefixController;
  late TextEditingController _remoteUrlController;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _localAddressController = TextEditingController(text: widget.config.localAddress);
    _localPortController = TextEditingController(text: widget.config.localPort.toString());
    _connectionMinIdleController = TextEditingController(text: widget.config.connectionMinIdle.toString());
    _httpUpgradePrefixController = TextEditingController(text: widget.config.httpUpgradePathPrefix);
    _remoteUrlController = TextEditingController(text: widget.config.remoteUrl);
    _loadPackageInfo();
  }

  @override
  void didUpdateWidget(ConfigTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.localAddress != widget.config.localAddress) {
      _localAddressController.text = widget.config.localAddress;
    }
    if (oldWidget.config.localPort != widget.config.localPort) {
      _localPortController.text = widget.config.localPort.toString();
    }
    if (oldWidget.config.connectionMinIdle != widget.config.connectionMinIdle) {
      _connectionMinIdleController.text = widget.config.connectionMinIdle.toString();
    }
    if (oldWidget.config.httpUpgradePathPrefix != widget.config.httpUpgradePathPrefix) {
      _httpUpgradePrefixController.text = widget.config.httpUpgradePathPrefix;
    }
    if (oldWidget.config.remoteUrl != widget.config.remoteUrl) {
      _remoteUrlController.text = widget.config.remoteUrl;
    }
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  @override
  void dispose() {
    _localAddressController.dispose();
    _localPortController.dispose();
    _connectionMinIdleController.dispose();
    _httpUpgradePrefixController.dispose();
    _remoteUrlController.dispose();
    super.dispose();
  }

  void _updateConfig() {
    widget.config.localAddress = _localAddressController.text;
    widget.config.localPort = int.tryParse(_localPortController.text) ?? 60000;
    widget.config.connectionMinIdle = int.tryParse(_connectionMinIdleController.text) ?? 5;
    widget.config.httpUpgradePathPrefix = _httpUpgradePrefixController.text;
    widget.config.remoteUrl = _remoteUrlController.text;
    widget.onConfigChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _localAddressController,
            decoration: InputDecoration(
              labelText: 'Local Address',
              border: const OutlineInputBorder(),
              helperText: 'e.g., 127.0.0.1',
              errorText: widget.validationErrors['localAddress'],
              errorBorder: widget.validationErrors.containsKey('localAddress')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
              focusedErrorBorder: widget.validationErrors.containsKey('localAddress')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
            ),
            onChanged: (_) => _updateConfig(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _localPortController,
            decoration: InputDecoration(
              labelText: 'Local Port',
              border: const OutlineInputBorder(),
              helperText: 'e.g., 60000',
              errorText: widget.validationErrors['localPort'],
              errorBorder: widget.validationErrors.containsKey('localPort')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
              focusedErrorBorder: widget.validationErrors.containsKey('localPort')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _updateConfig(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connection Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _connectionMinIdleController,
            decoration: InputDecoration(
              labelText: 'Connection Min Idle',
              border: const OutlineInputBorder(),
              helperText: 'Minimum idle connections to maintain',
              errorText: widget.validationErrors['connectionMinIdle'],
              errorBorder: widget.validationErrors.containsKey('connectionMinIdle')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
              focusedErrorBorder: widget.validationErrors.containsKey('connectionMinIdle')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _updateConfig(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _httpUpgradePrefixController,
            decoration: InputDecoration(
              labelText: 'HTTP Upgrade Path Prefix',
              border: const OutlineInputBorder(),
              helperText: 'Path prefix for HTTP upgrade',
              errorText: widget.validationErrors['httpUpgradePathPrefix'],
              errorBorder: widget.validationErrors.containsKey('httpUpgradePathPrefix')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
              focusedErrorBorder: widget.validationErrors.containsKey('httpUpgradePathPrefix')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
            ),
            onChanged: (_) => _updateConfig(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Remote Server',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _remoteUrlController,
            decoration: InputDecoration(
              labelText: 'Remote URL',
              border: const OutlineInputBorder(),
              helperText: 'e.g., wss://myhost.example.org',
              errorText: widget.validationErrors['remoteUrl'],
              errorBorder: widget.validationErrors.containsKey('remoteUrl')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
              focusedErrorBorder: widget.validationErrors.containsKey('remoteUrl')
                  ? const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    )
                  : null,
            ),
            onChanged: (_) => _updateConfig(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                _updateConfig();
                try {
                  await ConfigStorage.saveConfig(widget.config);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Configuration saved successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving configuration: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Config'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Command Preview:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'wstunnel client -L socks5://${widget.config.localAddress}:${widget.config.localPort} --connection-min-idle ${widget.config.connectionMinIdle} --http-upgrade-path-prefix ${widget.config.httpUpgradePathPrefix} ${widget.config.remoteUrl}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.only(right: 80),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_packageInfo != null) ...[
                  Text(
                    'Version: ${_packageInfo!.version}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Package: ${_packageInfo!.packageName}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ] else
                  const Text(
                    'Loading package information...',
                    style: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
