import 'dart:async';
import 'dart:convert';

import 'package:backpackhelp/ble_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Singleton BLE manager for the backpack RFID scanner (Nordic UART).
class BluetoothManager extends ChangeNotifier {
  BluetoothManager._internal();
  static final BluetoothManager instance = BluetoothManager._internal();

  static const String _uartServiceUuid =
      '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _uartTxCharacteristicUuid =
      '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _uartRxCharacteristicUuid =
      '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  final BleSession session = BleSession();

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  List<String> get scannedItems =>
      List.unmodifiable(session.scannedItems);

  Stream<String> get dataStream => _dataController.stream;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _uartWriteCharacteristic;
  bool _isConnected = false;
  bool _isScanning = false;
  final List<ScanResult> _scanResults = [];

  StreamSubscription<List<int>>? _characteristicSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  final StreamController<String> _dataController =
      StreamController<String>.broadcast();

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<bool> isBluetoothOn() async {
    return await FlutterBluePlus.adapterState.first ==
        BluetoothAdapterState.on;
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 12),
    bool filterByDeviceName = false,
  }) async {
    if (_isScanning) return;

    _isScanning = true;
    _scanResults.clear();
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(timeout: timeout);

      _scanResultsSubscription =
          FlutterBluePlus.scanResults.listen((results) {
        final filtered = filterByDeviceName
            ? results.where(_isBackpackDevice)
            : results.where(
                (r) =>
                    r.device.platformName.isNotEmpty ||
                    r.advertisementData.advName.isNotEmpty,
              );

        _scanResults
          ..clear()
          ..addAll(_dedupeResults(filtered));
        notifyListeners();
      });

      await Future.delayed(timeout);
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('[BluetoothManager] Scan error: $e');
    } finally {
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connectToDevice(
    BluetoothDevice device, {
    bool replaceExisting = false,
  }) async {
    if (_isConnected &&
        _connectedDevice?.remoteId == device.remoteId) {
      return;
    }

    if (_isConnected && replaceExisting) {
      await disconnect();
    } else if (_isConnected) {
      return;
    }

    try {
      await device.connect(timeout: const Duration(seconds: 10));

      _connectedDevice = device;
      _isConnected = true;
      notifyListeners();

      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase() !=
            _uartServiceUuid.toLowerCase()) {
          continue;
        }

        for (final characteristic in service.characteristics) {
          final uuid = characteristic.uuid.toString().toLowerCase();
          if (uuid == _uartRxCharacteristicUuid.toLowerCase()) {
            await characteristic.setNotifyValue(true);
            await _characteristicSubscription?.cancel();
            _characteristicSubscription =
                characteristic.lastValueStream.listen(_onDataReceived);
          }
          if (uuid == _uartTxCharacteristicUuid.toLowerCase()) {
            _uartWriteCharacteristic = characteristic;
          }
        }
        break;
      }

      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription =
          device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          await _handleDisconnection();
        }
      });
    } catch (e) {
      debugPrint('[BluetoothManager] Connection error: $e');
      await _handleDisconnection();
    }
  }

  Future<bool> sendData(String message) async {
    if (_uartWriteCharacteristic == null) return false;
    try {
      await _uartWriteCharacteristic!.write(
        utf8.encode(message),
        withoutResponse: true,
      );
      return true;
    } catch (e) {
      debugPrint('[BluetoothManager] Send error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    await _handleDisconnection();
  }

  Future<void> _handleDisconnection() async {
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;

    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    _connectedDevice = null;
    _uartWriteCharacteristic = null;
    _isConnected = false;
    notifyListeners();
  }

  void _onDataReceived(List<int> data) {
    debugPrint('[BluetoothManager] Raw bytes: $data');

    session.onDataReceived(data);
    final message = session.lastMessage;
    debugPrint('[BluetoothManager] Decoded: "$message"');

    _dataController.add(message);

    if (message.contains('Book Detected!')) {
      notifyListeners();
    }
  }

  bool _isBackpackDevice(ScanResult result) {
    final name = result.device.platformName;
    final advName = result.advertisementData.advName;
    return name.contains('RFID_Scanner') ||
        advName.contains('RFID_Scanner') ||
        name.contains('FallDetector') ||
        advName.contains('FallDetector');
  }

  List<ScanResult> _dedupeResults(Iterable<ScanResult> results) {
    final byId = <String, ScanResult>{};
    for (final result in results) {
      final id = result.device.remoteId.str;
      final existing = byId[id];
      if (existing == null || result.rssi > existing.rssi) {
        byId[id] = result;
      }
    }
    return byId.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  @override
  void dispose() {
    _characteristicSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _dataController.close();
    super.dispose();
  }
}
