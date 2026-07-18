import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:backpackhelp/constants.dart';
import 'package:backpackhelp/GuestSession.dart';
import 'package:backpackhelp/bluetooth.dart';
import 'package:backpackhelp/raspberry_pi_client.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _background = AppColors.background;

  final _ble = BluetoothManager.instance;
  final _pi = RaspberryPiClient.instance;

  User? _user;
  bool _btOn = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _nothingFound = false;
  int _scanGeneration = 0;
  String? _weight;
  List<String> _localScannedItems = [];
  String _statusTitle = 'Ready to scan';
  String _statusSubtitle = 'Tap Scan to search for your backpack';

  StreamSubscription<String>? _dataStreamSub;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _btOn = true;
  }

  // Kept for compatibility with the existing BLE scanner implementation.
  // ignore: unused_element
  void _onBleStateChanged() {
    if (!mounted || !_isScanning) return;

    final results = _ble.scanResults;
    if (results.isNotEmpty && !_isConnecting) {
      _connectToBackpack(results.first);
    }

    if (!_ble.isScanning && _isScanning && !_ble.isConnected) {
      setState(() {
        _nothingFound = true;
        _statusTitle = 'Nothing found';
        _statusSubtitle = 'No backpack detected nearby — tap Scan to retry';
      });
      _stopScanningUi(found: false);
    }
  }

  // ignore: unused_element
  Future<void> _initBluetooth() async {
    final on = await _ble.isBluetoothOn();
    if (!mounted) return;
    setState(() => _btOn = on);
  }

  Future<void> _connectToBackpack(ScanResult result) async {
    if (_isConnecting) return;
    _isConnecting = true;

    final name = result.device.platformName.isEmpty
        ? 'Backpack'
        : result.device.platformName;

    setState(() {
      _statusTitle = 'Backpack found';
      _statusSubtitle = 'Connecting to $name…';
    });

    await _ble.stopScan();
    await _ble.connectToDevice(result.device, replaceExisting: true);
    if (!mounted) return;

    if (_ble.isConnected) {
      setState(() {
        _statusTitle = 'Connected';
        _statusSubtitle = 'Reading items from your backpack…';
      });
      await _ble.sendData('SCAN');
    } else {
      setState(() {
        _statusTitle = 'Connection failed';
        _statusSubtitle = 'Tap Scan to try again';
      });
      _stopScanningUi(found: false);
    }

    _isConnecting = false;
  }

  // ignore: unused_element
  void _onDataReceived(String message) {
    if (message.contains('Book Detected!')) {
      final items = List.of(_ble.scannedItems);
      if (items.isNotEmpty) {
        _saveScannedItems(items);
      }
    }

    final items = _parseItems(message);
    final weight = _parseWeight(message);

    if (items.isEmpty && weight == null) return;

    if (items.isNotEmpty) {
      _saveScannedItems(items);
    }

    if (!mounted) return;
    setState(() {
      if (weight != null) _weight = weight;
      if (items.isNotEmpty) {
        _statusTitle = 'Scan complete';
        _statusSubtitle =
            '${items.length} item${items.length == 1 ? '' : 's'} detected';
      }
    });

    if (items.isNotEmpty) {
      _stopScanningUi(found: true);
    }
  }

  List<String> _parseItems(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return [];

    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map) {
        final raw = decoded['items'] ?? decoded['scanned_items'];
        if (raw is List) {
          return raw
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
      if (decoded is List) {
        return decoded
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return trimmed
        .split(RegExp(r'[,;\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String? _parseWeight(String message) {
    try {
      final decoded = json.decode(message.trim());
      if (decoded is Map && decoded['weight'] != null) {
        final w = decoded['weight'];
        return w is num ? '${w.toStringAsFixed(1)} kg' : w.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveScannedItems(List<String> items) async {
    // Guests aren't signed in, so scanned items stay in memory for this
    // session instead of being written to a Firestore user doc.
    if (GuestSession.isGuest) {
      if (mounted) setState(() => _localScannedItems = items);
      return;
    }
    final uid = _user?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'scanned_items': items,
    });
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    final generation = ++_scanGeneration;

    setState(() {
      _isScanning = true;
      _nothingFound = false;
      _statusTitle = 'Scanning...';
      _statusSubtitle = 'Hold RFID tags near the backpack reader';
    });

    try {
      final items = await _pi.scan();
      if (generation != _scanGeneration) return;
      if (items.isNotEmpty) await _saveScannedItems(items);
      if (!mounted) return;
      setState(() {
        _nothingFound = items.isEmpty;
        _statusTitle = items.isEmpty ? 'Nothing found' : 'Scan complete';
        _statusSubtitle = items.isEmpty
            ? 'No RFID tags were detected'
            : '${items.length} item${items.length == 1 ? '' : 's'} detected';
      });
    } on RaspberryPiException catch (error) {
      if (!mounted) return;
      setState(() {
        _nothingFound = true;
        _statusTitle = 'Connection failed';
        _statusSubtitle = error.message;
      });
    } finally {
      if (generation == _scanGeneration) _stopScanningUi();
    }
  }

  void _stopScanningUi({bool? found}) {
    if (mounted) {
      setState(() {
        _isScanning = false;
        if (found == true) _nothingFound = false;
      });
    }
  }

  Future<void> _cancelScan() async {
    if (!mounted) return;
    _scanGeneration++;
    setState(() {
      _nothingFound = false;
      _statusTitle = 'Scan cancelled';
      _statusSubtitle = 'Tap Scan when you are ready';
    });
    _stopScanningUi(found: false);
  }

  @override
  void dispose() {
    _dataStreamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(title: const Text('Bag Scan')),
      body: GuestSession.isGuest
          ? _buildContent(_localScannedItems)
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.black45,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load scan data',
                      style: TextStyle(color: Colors.black45, fontSize: 14),
                    ),
                  );
                }

                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                final rawItems = userData?['scanned_items'];
                final scannedItems = rawItems != null
                    ? List<String>.from(rawItems as List)
                    : <String>[];

                return _buildContent(scannedItems);
              },
            ),
    );
  }

  Widget _buildContent(List<String> scannedItems) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Scan Backpack",
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Use the RFID reader to update what is inside.",
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildScanButton(),
          const SizedBox(height: 28),
          _buildItemsSection(scannedItems),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        gradient: LinearGradient(
          colors: _nothingFound
              ? const [AppColors.danger, AppColors.coral]
              : const [AppColors.primary, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Center(child: _buildLogoOrIcon()),
              ),
              if (_weight != null)
                Positioned(
                  top: -6,
                  right: -48,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _weight!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _statusTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _statusSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          if (!_btOn) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_disabled,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Bluetooth unavailable',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoOrIcon() {
    if (_isScanning) {
      return const SizedBox(
        width: 52,
        height: 52,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    if (_nothingFound) {
      return const Icon(Icons.close, size: 64, color: Colors.redAccent);
    }
    return Icon(Icons.sensors, size: 45, color: Colors.white);
  }

  Widget _buildScanButton() {
    if (_isScanning) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _cancelScan,
          icon: const Icon(Icons.close, size: 18),
          label: const Text(
            'Cancel scan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            side: const BorderSide(color: Colors.black26),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startScan,
        icon: const Icon(Icons.sensors, size: 18),
        label: const Text(
          'Start scan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSection(List<String> scannedItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Detected Items',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Text(
                '${scannedItems.length} items',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (scannedItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  _isScanning ? Icons.radar : Icons.inventory_2_outlined,
                  size: 32,
                  color: _isScanning ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(height: 10),
                Text(
                  _isScanning
                      ? 'Searching for items…'
                      : 'No items detected yet',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(scannedItems.length, (i) {
                final item = scannedItems[i];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _background,
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 16,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '#${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < scannedItems.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF0F0EE),
                      ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }
}
