import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// ---------------------------------------------------------------------------
/// BluetoothService — Singleton
///
/// A globally accessible Bluetooth manager designed to communicate with a
/// Raspberry Pi 5 acting as a BLE peripheral (using BlueZ / bluezdbus).
///
/// The Pi 5 is expected to advertise a custom GATT service with:
///   • SERVICE_UUID        — primary service
///   • TX_CHAR_UUID        — Pi writes data HERE  (notify / indicate)
///   • RX_CHAR_UUID        — Flutter writes data HERE (write-without-response)
///
/// Usage:
///   final bt = BluetoothService.instance;
///   await bt.startScan();
///   bt.dataStream.listen((data) => print(data));
/// ---------------------------------------------------------------------------

// ─── Raspberry Pi 5 GATT UUIDs ─────────────────────────────────────────────
// Change these to match the UUIDs defined in your Pi's GATT server script.
const String kServiceUUID = '12345678-1234-5678-1234-56789abcdef0';
const String kTxCharUUID  = '12345678-1234-5678-1234-56789abcdef1'; // Pi → Flutter
const String kRxCharUUID  = '12345678-1234-5678-1234-56789abcdef2'; // Flutter → Pi

class CustomBluetoothService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  CustomBluetoothService._internal();
  static final CustomBluetoothService instance = CustomBluetoothService._internal();
  factory CustomBluetoothService() => instance;

  // ── Public state ───────────────────────────────────────────────────────────

  /// The currently connected Raspberry Pi 5 device (null if disconnected).
  BluetoothDevice? connectedDevice;

  /// True while a BLE scan is running.
  bool isScanning = false;

  /// True while a connection attempt is in progress.
  bool isConnecting = false;

  /// Decoded text / bytes received from the Pi via the TX characteristic.
  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  /// Raw scan results as they arrive.
  final StreamController<List<ScanResult>> _scanController =
      StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanStream => _scanController.stream;

  /// Connection state changes.
  final StreamController<BluetoothConnectionState> _connectionController =
      StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionStream =>
      _connectionController.stream;

  // ── Private internals ──────────────────────────────────────────────────────
  BluetoothCharacteristic? _txCharacteristic; // notify  (Pi → Flutter)
  BluetoothCharacteristic? _rxCharacteristic; // write   (Flutter → Pi)
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  // ── Bluetooth adapter helpers ──────────────────────────────────────────────

  /// Returns true if the host device's Bluetooth adapter is on.
  Future<bool> isBluetoothOn() async {
    return await FlutterBluePlus.adapterState.first ==
        BluetoothAdapterState.on;
  }

  // ── Scanning ───────────────────────────────────────────────────────────────

  /// Starts a BLE scan filtered to devices advertising [kServiceUUID].
  /// Automatically stops after [timeout] (default 10 s).
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (isScanning) return;

    await FlutterBluePlus.startScan(
      withServices: [Guid(kServiceUUID)],
      timeout: timeout,
    );
    isScanning = true;

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanController.add(results);
    });

    // Mark scanning done when the scan completes naturally.
    await Future.delayed(timeout);
    isScanning = false;
  }

  /// Stops an active scan early.
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    isScanning = false;
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  /// Connects to [device] (expected to be the Raspberry Pi 5),
  /// discovers services, and subscribes to the TX characteristic.
  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (isConnecting || connectedDevice != null) return false;
    isConnecting = true;

    try {
      await device.connect(autoConnect: false);
      connectedDevice = device;

      // Monitor connection state.
      _connectionSubscription?.cancel();
      _connectionSubscription =
          device.connectionState.listen((state) {
        _connectionController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _discoverAndSubscribe(device);
      isConnecting = false;
      return true;
    } catch (e) {
      isConnecting = false;
      _handleDisconnect();
      return false;
    }
  }

  /// Discovers the Pi's GATT service and subscribes to notifications.
  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == Guid(kServiceUUID)) {
        for (final char in service.characteristics) {
          if (char.uuid == Guid(kTxCharUUID)) {
            _txCharacteristic = char;
            // Enable notifications so the Pi can push data to Flutter.
            await char.setNotifyValue(true);
            _notifySubscription?.cancel();
            _notifySubscription = char.lastValueStream.listen(_onDataReceived);
          }
          if (char.uuid == Guid(kRxCharUUID)) {
            _rxCharacteristic = char;
          }
        }
      }
    }
  }

  /// Disconnects from the currently connected device.
  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _txCharacteristic = null;
    _rxCharacteristic = null;
    connectedDevice  = null;
    isConnecting     = false;
  }

  // ── Data I/O ───────────────────────────────────────────────────────────────

  /// Called whenever the Pi sends a notification on the TX characteristic.
  void _onDataReceived(List<int> rawBytes) {
    if (rawBytes.isEmpty) return;
    final decoded = utf8.decode(rawBytes, allowMalformed: true);
    _dataController.add(decoded);
  }

  /// Sends [message] as UTF-8 bytes to the Pi via the RX characteristic.
  /// Returns true on success.
  Future<bool> sendData(String message) async {
    if (_rxCharacteristic == null) return false;
    try {
      final bytes = utf8.encode(message);
      await _rxCharacteristic!.write(bytes, withoutResponse: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends raw bytes directly (useful for binary protocols).
  Future<bool> sendBytes(List<int> bytes) async {
    if (_rxCharacteristic == null) return false;
    try {
      await _rxCharacteristic!.write(bytes, withoutResponse: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Call this when the app is closing to free all resources.
  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _connectionSubscription?.cancel();
    _dataController.close();
    _scanController.close();
    _connectionController.close();
  }
}
