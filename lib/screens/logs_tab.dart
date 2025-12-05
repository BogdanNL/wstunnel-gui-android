import 'package:flutter/material.dart';
import '../services/wstunnel_service.dart';

class LogsTab extends StatefulWidget {
  final WstunnelService wstunnelService;

  const LogsTab({
    super.key,
    required this.wstunnelService,
  });

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  late ScrollController _scrollController;
  int _previousLogCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _previousLogCount = widget.wstunnelService.logs.length;
    // Scroll to end on initialization if logs exist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.wstunnelService.logs.isNotEmpty) {
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Use StreamBuilder for reactive counter updates
              StreamBuilder<String>(
                stream: widget.wstunnelService.logStream,
                builder: (context, snapshot) {
                  // Update counter on any stream change
                  final logCount = widget.wstunnelService.logs.length;
                  return Text('Logs ($logCount)');
                },
              ),
              ElevatedButton.icon(
                onPressed: () {
                  widget.wstunnelService.clearLogs();
                  setState(() {});
                },
                icon: const Icon(Icons.delete),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<String>(
            stream: widget.wstunnelService.logStream,
            builder: (context, snapshot) {
              // Ignore special clear message
              if (snapshot.hasData && snapshot.data == '[LOGS_CLEARED]') {
                // Just update counter
                _previousLogCount = 0;
              } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                // Check if new logs appeared
                final currentLogCount = widget.wstunnelService.logs.length;
                if (currentLogCount > _previousLogCount) {
                  _previousLogCount = currentLogCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }
              }

              final logs = widget.wstunnelService.logs;

              return ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isError = log.contains('[STDERR]');
                  
                  return Container(
                    color: isError ? Colors.red.shade50 : null,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: isError ? Colors.red : Colors.black87,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
