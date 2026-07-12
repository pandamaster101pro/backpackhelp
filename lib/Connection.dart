import 'package:backpackhelp/raspberry_pi_client.dart';
import 'package:flutter/material.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _client = RaspberryPiClient.instance;
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  bool _busy = true;
  bool? _connected;
  String _message = 'Loading saved connection...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _urlController.text = await _client.getBaseUrl();
    _apiKeyController.text = await _client.getApiKey();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = 'Enter the Raspberry Pi address, then test the connection.';
    });
  }

  Future<void> _saveAndTest() async {
    if (_urlController.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _connected = null;
      _message = 'Connecting to Raspberry Pi...';
    });

    try {
      await _client.saveSettings(_urlController.text, _apiKeyController.text);
      await _client.testConnection();
      if (!mounted) return;
      setState(() {
        _connected = true;
        _message = 'Connected. The RFID reader service is ready.';
      });
    } on RaspberryPiException catch (error) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _message = error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _connected == true
        ? Colors.green
        : _connected == false
        ? Colors.redAccent
        : Colors.black45;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: const Text('Raspberry Pi Connection'),
        backgroundColor: const Color(0xFFF7F7F5),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              children: [
                Icon(
                  _connected == true ? Icons.link : Icons.settings_ethernet,
                  size: 48,
                  color: statusColor,
                ),
                const SizedBox(height: 12),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Raspberry Pi address',
              hintText: 'http://100.x.x.x:8000',
              helperText: 'Use the Pi Tailscale IP for different Wi-Fi.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key',
              helperText: 'Use the key printed by setup_remote_access.sh.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _saveAndTest,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: const Text('Save and test connection'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Remote connection setup',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Install Tailscale on the phone and Raspberry Pi, then sign in to '
            'the same Tailscale account. On the Pi, run "tailscale ip -4" and '
            'enter that 100.x.x.x address above.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
