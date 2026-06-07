import 'dart:convert';

/// Holds live BLE message state and notifies listeners when new data arrives.
class BleSession {
  String lastMessage = '';
  final List<String> scannedItems = [];
  final List<void Function(String)> _listeners = [];

  void onDataReceived(List<int> data) {
    final message = utf8.decode(data, allowMalformed: true).trim();
    if (message.isEmpty) return;

    lastMessage = message;

    if (message.contains('Book Detected!')) {
      scannedItems.insert(0, message);
    }

    for (final listener in List.of(_listeners)) {
      listener(message);
    }
  }

  void addListener(void Function(String) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(String) listener) {
    _listeners.remove(listener);
  }

  void clearScannedItems() {
    scannedItems.clear();
  }
}
