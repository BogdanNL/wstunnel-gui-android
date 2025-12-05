import 'package:flutter/material.dart';

class HelpTab extends StatelessWidget {
  const HelpTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About This Application',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'This application is a prototype Android client for wstunnel, built on top of the library available at https://github.com/erebe/wstunnel.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'What is wstunnel?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'wstunnel is a powerful tunneling tool that allows you to tunnel all your traffic over WebSocket or HTTP/2 protocols. It is designed to bypass firewalls and DPI (Deep Packet Inspection) systems by encapsulating network traffic in WebSocket connections, making it appear as regular web traffic. This makes it particularly useful in restricted network environments where traditional VPN protocols might be blocked.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Server Setup',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'On the server side, you need to run the wstunnel server. A typical setup would look like:',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'wstunnel server --restrict-http-upgrade-path-prefix <secret> ws://[::]:8080',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The server should be covered by a reverse proxy such as Caddy or nginx to handle TLS termination and provide additional security features.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Client Operation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'After starting the client on Android, a SOCKS5 proxy is created on the port selected by the user. This is equivalent to running the following command:',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'wstunnel client -L socks5://127.0.0.1:60000 --connection-min-idle 5 --http-upgrade-path-prefix <secret> wss://myhost.example.org',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Once the SOCKS5 proxy is running, clients can configure their applications to use this proxy to gain internet access through the wstunnel connection.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            '• Local Address: The IP address where the SOCKS5 proxy will listen (typically 127.0.0.1)\n'
            '• Local Port: The port number for the SOCKS5 proxy\n'
            '• Connection Min Idle: Minimum number of idle connections to maintain\n'
            '• HTTP Upgrade Path Prefix: The secret path prefix used for authentication\n'
            '• Remote URL: The WebSocket URL of your wstunnel server (e.g., wss://myhost.example.org)',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

