import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:backpackhelp/bluetooth_service.dart';

import 'bluetooth_service.dart'; // <-- the singleton class above

/// ---------------------------------------------------------------------------
/// BluetoothPage
///
/// A ready-to-use Flutter screen that:
///   1. Checks Bluetooth adapter state.
///   2. Scans for the Raspberry Pi 5 BLE peripheral.
///   3. Connects / disconnects.
///   4. Displays live data streamed from the Pi.
///   5. Lets the user type and send messages back to the Pi.
///
/// Drop this Widget into your MaterialApp routes:
///   routes: { '/bluetooth': (_) => const BluetoothPage() }
/// ---------------------------------------------------------------------------

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  // ── Singleton reference ──────────────────────────────────────────────────
  final _bt = CustomBluetoothService.instance;

  // ── Local UI state ───────────────────────────────────────────────────────
  final List<ScanResult> _scanResults = [];
  final List<String>     _log         = [];
  final TextEditingController _sendController = TextEditingController();

  StreamSubscription<List<ScanResult>>?        _scanSub;
  StreamSubscription<String>?                  _dataSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool _btOn        = false;
  bool _isConnected = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    final on = await _bt.isBluetoothOn();
    setState(() => _btOn = on);
    if (!on) return;

    // Listen to scan results from the service.
    _scanSub = _bt.scanStream.listen((results) {
      setState(() {
        _scanResults
          ..clear()
          ..addAll(results);
      });
    });

    // Listen to incoming data from the Pi.
    _dataSub = _bt.dataStream.listen((msg) {
      setState(() => _log.add('← Pi: $msg'));
    });

    // Listen to connection state changes.
    _connSub = _bt.connectionStream.listen((state) {
      setState(() {
        _isConnected = state == BluetoothConnectionState.connected;
        if (!_isConnected) _log.add('⚡ Disconnected from Pi');
      });
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _dataSub?.cancel();
    _connSub?.cancel();
    _sendController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    setState(() {
      _scanResults.clear();
      _log.add('🔍 Scanning for Raspberry Pi 5…');
    });
    await _bt.startScan(timeout: const Duration(seconds: 10));
    setState(() => _log.add('🔍 Scan complete.'));
  }

  Future<void> _connect(ScanResult result) async {
    setState(() => _log.add('🔗 Connecting to ${result.device.platformName}…'));
    await _bt.stopScan();

    final ok = await _bt.connectToDevice(result.device);
    setState(() {
      if (ok) {
        _isConnected = true;
        _log.add('✅ Connected to Raspberry Pi 5');
      } else {
        _log.add('❌ Connection failed');
      }
    });
  }

  Future<void> _disconnect() async {
    await _bt.disconnect();
    setState(() {
      _isConnected = false;
      _log.add('🔌 Disconnected.');
    });
  }

  Future<void> _sendMessage() async {
    final text = _sendController.text.trim();
    if (text.isEmpty) return;

    final ok = await _bt.sendData(text);
    setState(() {
      if (ok) {
        _log.add('→ You: $text');
        _sendController.clear();
      } else {
        _log.add('⚠ Send failed — not connected?');
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raspberry Pi 5 Bluetooth'),
        actions: [
          // Connection indicator dot.
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.circle,
              size: 14,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: !_btOn
          ? _buildBluetoothOffBanner()
          : Column(
              children: [
                _buildControlRow(),
                const Divider(height: 1),
                if (!_isConnected) _buildScanList(),
                const Divider(height: 1),
                _buildLog(),
                if (_isConnected) _buildSendBar(),
              ],
            ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildBluetoothOffBanner() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Bluetooth is off. Please enable it in device settings.',
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildControlRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _bt.isScanning ? null : _startScan,
            icon: const Icon(Icons.search),
            label: Text(_bt.isScanning ? 'Scanning…' : 'Scan'),
          ),
          const SizedBox(width: 12),
          if (_isConnected)
            ElevatedButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('Disconnect'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildScanList() {
    if (_scanResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No devices found. Tap Scan to search.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (ctx, i) {
          final r = _scanResults[i];
          final name = r.device.platformName.isEmpty
              ? 'Unknown (${r.device.remoteId})'
              : r.device.platformName;
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(name),
            subtitle: Text('RSSI: ${r.rssi} dBm'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _connect(r),
          );
        },
      ),
    );
  }

  Widget _buildLog() {
    return Expanded(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(8),
        child: _log.isEmpty
            ? const Center(
                child: Text('Log is empty.',
                    style: TextStyle(color: Colors.white38)))
            : ListView.builder(
                reverse: true,
                itemCount: _log.length,
                itemBuilder: (ctx, i) {
                  final entry = _log[_log.length - 1 - i];
                  return Text(
                    entry,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: entry.startsWith('←')
                          ? Colors.greenAccent
                          : entry.startsWith('→')
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSendBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sendController,
                decoration: const InputDecoration(
                  hintText: 'Send message to Pi…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
