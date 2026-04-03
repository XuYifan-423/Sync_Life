import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothGlobalState extends ChangeNotifier {
  static final BluetoothGlobalState _instance = BluetoothGlobalState._internal();

  factory BluetoothGlobalState() {
    return _instance;
  }

  BluetoothGlobalState._internal();

  bool _isBluetoothConnected = false;
  bool _isCalibrated = false;
  BluetoothDevice? _connectedDevice;
  String _deviceName = '未连接设备';
  bool _isProcessingData = false;

  bool get isBluetoothConnected => _isBluetoothConnected;
  bool get isCalibrated => _isCalibrated;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String get deviceName => _deviceName;
  bool get isProcessingData => _isProcessingData;

  void setBluetoothConnected(bool connected, BluetoothDevice? device, String deviceName) {
    _isBluetoothConnected = connected;
    _connectedDevice = device;
    _deviceName = deviceName;
    notifyListeners();
  }

  void setCalibrated(bool calibrated) {
    _isCalibrated = calibrated;
    if (calibrated) {
      startDataProcessing();
    } else {
      stopDataProcessing();
    }
    notifyListeners();
  }

  void startDataProcessing() {
    _isProcessingData = true;
    notifyListeners();
  }

  void stopDataProcessing() {
    _isProcessingData = false;
    notifyListeners();
  }

  void disconnect() {
    _isBluetoothConnected = false;
    _connectedDevice = null;
    _deviceName = '未连接设备';
    _isCalibrated = false;
    _isProcessingData = false;
    notifyListeners();
  }
}