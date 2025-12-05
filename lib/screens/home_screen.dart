import 'package:flutter/material.dart';
import '../models/wstunnel_config.dart';
import '../services/wstunnel_service.dart';
import '../services/config_storage.dart';
import 'config_tab.dart';
import 'logs_tab.dart';
import 'help_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WstunnelService _wstunnelService;
  late WstunnelConfig _config;
  bool _isRunning = false;
  Map<String, String> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _wstunnelService = WstunnelService();
    _config = WstunnelConfig();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final savedConfig = await ConfigStorage.loadConfig();
      if (savedConfig != null) {
        setState(() {
          _config = savedConfig;
        });
      }
    } catch (e) {
      print('Error loading config: $e');
    }
  }

  @override
  void dispose() {
    _wstunnelService.dispose();
    super.dispose();
  }

  Future<void> _toggleWstunnel() async {
    print('[UI DEBUG] _toggleWstunnel called, _isRunning=$_isRunning');
    try {
      if (_isRunning) {
        print('[UI DEBUG] Calling stop()...');
        await _wstunnelService.stop();
        print('[UI DEBUG] stop() completed');
        setState(() {
          _isRunning = _wstunnelService.isRunning;
          _validationErrors = {}; // Clear errors on stop
        });
      } else {
        // Validate before starting
        final errors = await _config.validate();
        if (errors.isNotEmpty) {
          setState(() {
            _validationErrors = errors;
          });
          // Show message to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please fix validation errors: ${errors.values.join(", ")}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Clear errors if validation passed successfully
        setState(() {
          _validationErrors = {};
        });

        print('[UI DEBUG] Calling start()...');
        await _wstunnelService.start(_config);
        print('[UI DEBUG] start() completed');

        setState(() {
          _isRunning = _wstunnelService.isRunning;
        });
      }
      print('[UI DEBUG] State updated, _isRunning=$_isRunning');
    } catch (e, stackTrace) {
      print('[UI DEBUG] EXCEPTION in _toggleWstunnel: $e');
      print('[UI DEBUG] Stack trace: $stackTrace');
      setState(() {
        _isRunning = _wstunnelService.isRunning;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wstunnel GUI'),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'Configuration'),
              Tab(icon: Icon(Icons.description), text: 'Logs'),
              Tab(icon: Icon(Icons.help), text: 'Help'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ConfigTab(
              config: _config,
              onConfigChanged: () {
                setState(() {
                  // Clear validation errors when configuration changes
                  _validationErrors = {};
                });
              },
              wstunnelService: _wstunnelService,
              validationErrors: _validationErrors,
            ),
            LogsTab(
              wstunnelService: _wstunnelService,
            ),
            const HelpTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _toggleWstunnel,
          backgroundColor: _isRunning ? Colors.red : Colors.green,
          icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
          label: Text(_isRunning ? 'Stop' : 'Start'),
        ),
      ),
    );
  }
}
