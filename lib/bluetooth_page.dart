import 'dart:async';

import 'package:backpackhelp/bluetooth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothPage extends StatefulWidget {
  final BluetoothManager? bluetoothManager;

  const BluetoothPage({super.key, this.bluetoothManager});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothManager get _ble =>
      widget.bluetoothManager ?? BluetoothManager.instance;

  final List<String> _log = [];
  final TextEditingController _sendController = TextEditingController();

  List<String> scannedItems = [];
  bool _btOn = false;

  StreamSubscription<String>? _dataStreamSub;

  @override
  void initState() {
    super.initState();
    _ble.addListener(_onBleStateChanged);
    _dataStreamSub = _ble.dataStream.listen(_onDataMessage);
    _ble.requestPermissions();
    scannedItems = List.of(_ble.scannedItems);
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    final on = await _ble.isBluetoothOn();
    if (!mounted) return;
    setState(() => _btOn = on);
  }

  @override
  void dispose() {
    _ble.removeListener(_onBleStateChanged);
    _dataStreamSub?.cancel();
    _sendController.dispose();
    super.dispose();
  }

  void _onBleStateChanged() {
    if (!mounted) return;
    setState(() {
      scannedItems = List.of(_ble.scannedItems);
    });
  }

  void _onDataMessage(String message) {
    if (!mounted) return;
    setState(() => _log.insert(0, '← Pi: $message'));

    if (message.contains('Book Detected!')) {
      setState(() {
        scannedItems = List.of(_ble.scannedItems);
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _log.insert(0, '🔍 Scanning for devices…');
    });
    await _ble.startScan(filterByDeviceName: true);
    if (!mounted) return;
    setState(() => _log.insert(0, '🔍 Scan complete.'));
  }

  Future<void> _connect(ScanResult result) async {
    final name = result.device.platformName.isEmpty
        ? result.advertisementData.advName
        : result.device.platformName;
    setState(() => _log.insert(0, '🔗 Connecting to $name…'));

    await _ble.stopScan();
    await _ble.connectToDevice(result.device, replaceExisting: true);

    if (!mounted) return;
    setState(() {
      if (_ble.isConnected) {
        _log.insert(0, '✅ Connected');
      } else {
        _log.insert(0, '❌ Connection failed');
      }
    });
  }

  Future<void> _disconnect() async {
    await _ble.disconnect();
    if (!mounted) return;
    setState(() => _log.insert(0, '🔌 Disconnected.'));
  }

  Future<void> _sendMessage() async {
    final text = _sendController.text.trim();
    if (text.isEmpty) return;

    final ok = await _ble.sendData(text);
    if (!mounted) return;
    setState(() {
      if (ok) {
        _log.insert(0, '→ You: $text');
        _sendController.clear();
      } else {
        _log.insert(0, '⚠ Send failed — not connected?');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scanResults = _ble.scanResults;
    final isConnected = _ble.isConnected;
    final isScanning = _ble.isScanning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Debug'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.circle,
              size: 14,
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: !_btOn
          ? _buildBluetoothOffBanner()
          : Column(
              children: [
                _buildControlRow(isConnected, isScanning),
                if (scannedItems.isNotEmpty) _buildScannedItems(),
                const Divider(height: 1),
                if (!isConnected) _buildScanList(scanResults),
                const Divider(height: 1),
                _buildLog(),
                if (isConnected) _buildSendBar(),
              ],
            ),
    );
  }

  Widget _buildBluetoothOffBanner() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Bluetooth is off. Please enable it in device settings.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildControlRow(bool isConnected, bool isScanning) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: isScanning ? null : _startScan,
              icon: const Icon(Icons.search),
              label: Text(isScanning ? 'Scanning…' : 'Scan'),
            ),
            const SizedBox(width: 12),
            if (isConnected)
              ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
              ),
          ],
        ),
      );

  Widget _buildScannedItems() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.black12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Books detected (${scannedItems.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...scannedItems.take(3).map(
                  (item) => Text(
                    item,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
          ],
        ),
      );

  Widget _buildScanList(List<ScanResult> scanResults) {
    if (scanResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No devices found. Tap Scan to search.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (ctx, i) {
          final r = scanResults[i];
          final name = r.device.platformName.isEmpty
              ? (r.advertisementData.advName.isEmpty
                  ? 'Unknown (${r.device.remoteId})'
                  : r.advertisementData.advName)
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

  Widget _buildLog() => Expanded(
        child: Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(8),
          child: _log.isEmpty
              ? const Center(
                  child: Text(
                    'Log is empty.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (ctx, i) {
                    final entry = _log[i];
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

  Widget _buildSendBar() => SafeArea(
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
