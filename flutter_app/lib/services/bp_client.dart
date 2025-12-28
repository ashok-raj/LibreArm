import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/bp_reading.dart';

enum MeasurementMode { single, average3 }

class BPClient extends ChangeNotifier {
  // UI state
  String status = 'Searching for device…';
  BPReading? lastReading;
  bool isConnected = false;
  bool canMeasure = false;
  bool isMeasuring = false;

  double _delayBetweenRuns = 15;
  double get delayBetweenRuns => _delayBetweenRuns;
  set delayBetweenRuns(double value) {
    _delayBetweenRuns = value;
    notifyListeners();
  }

  MeasurementMode _measurementMode = MeasurementMode.single;
  MeasurementMode get measurementMode => _measurementMode;
  set measurementMode(MeasurementMode value) {
    _measurementMode = value;
    notifyListeners();
  }

  // Callback for final reading
  void Function(BPReading)? onFinalReading;

  // BLE
  BluetoothDevice? _device;
  BluetoothCharacteristic? _measurementChar;
  BluetoothCharacteristic? _controlChar;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _measurementSubscription;

  // Session state
  bool _sessionActive = false;
  Timer? _completionTimer;
  static const _completionDebounceSeconds = 1.5;

  // Averaging
  int _remainingRuns = 0;
  final List<BPReading> _accumulatedReadings = [];

  // Inflation detection
  DateTime? _measurementStartTime;
  static const _minimumMeasurementSeconds = 10.0;

  // Connect timeout
  Timer? _connectTimeoutTimer;

  // BLE UUIDs
  static final _bpsServiceUuid = Guid('00001810-0000-1000-8000-00805f9b34fb');
  static final _measurementUuid = Guid('00002a35-0000-1000-8000-00805f9b34fb');
  static final _controlUuid = Guid('583cb5b3-875d-40ed-9098-c39eb0c1983d');

  // Commands
  static final _startCommand = Uint8List.fromList([0xF1, 0x01]);
  static final _cancelCommand = Uint8List.fromList([0xF1, 0x02]);

  BPClient() {
    _init();
  }

  Future<void> _init() async {
    // Listen for Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        status = 'Bluetooth not available';
        isConnected = false;
        canMeasure = false;
        isMeasuring = false;
        notifyListeners();
      }
    });
  }

  /// Begin scanning/connecting to the cuff
  Future<void> startConnect({int timeout = 30}) async {
    // Check Bluetooth state
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      status = 'Bluetooth unavailable';
      notifyListeners();
      return;
    }

    // Reset state
    isConnected = false;
    canMeasure = false;
    isMeasuring = false;
    lastReading = null;
    _sessionActive = false;
    _completionTimer?.cancel();
    _connectTimeoutTimer?.cancel();

    status = 'Searching for device…';
    notifyListeners();

    // Stop any existing scan
    await FlutterBluePlus.stopScan();

    // Start scanning
    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        if (result.advertisementData.serviceUuids.contains(_bpsServiceUuid)) {
          _onDeviceFound(result.device);
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [_bpsServiceUuid],
      timeout: Duration(seconds: timeout),
    );

    // Timeout handler
    _connectTimeoutTimer = Timer(Duration(seconds: timeout), () {
      if (!isConnected) {
        FlutterBluePlus.stopScan();
        status = 'Not connected (timeout). Check power & Bluetooth.';
        notifyListeners();
      }
    });
  }

  Future<void> _onDeviceFound(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    _connectTimeoutTimer?.cancel();
    _scanSubscription?.cancel();

    status = 'Connecting…';
    notifyListeners();

    _device = device;

    // Listen for connection state
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        isConnected = false;
        canMeasure = false;
        isMeasuring = false;
        status = 'Disconnected';
        _measurementChar = null;
        _controlChar = null;
        notifyListeners();
      }
    });

    try {
      await device.connect(license: License.free);
      isConnected = true;
      status = 'Connected — discovering…';
      notifyListeners();

      await _discoverServices(device);
    } catch (e) {
      isConnected = false;
      canMeasure = false;
      status = 'Failed to connect';
      notifyListeners();
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == _bpsServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid == _measurementUuid) {
            _measurementChar = char;
            await char.setNotifyValue(true);
            _measurementSubscription?.cancel();
            _measurementSubscription = char.onValueReceived.listen(_parseBPM);
          } else if (char.uuid == _controlUuid) {
            _controlChar = char;
          }
        }
      }
    }

    canMeasure = _measurementChar != null && _controlChar != null;
    if (canMeasure) {
      status = 'Connected — ready';
    }
    notifyListeners();
  }

  /// Start measurement
  Future<void> startMeasurement() async {
    if (_device == null || _controlChar == null || !canMeasure) return;

    if (measurementMode == MeasurementMode.average3 && _sessionActive) {
      return;
    }

    status = measurementMode == MeasurementMode.average3
        ? 'Measuring (run 1 of 3)…'
        : 'Measuring…';
    _sessionActive = true;
    isMeasuring = true;
    _completionTimer?.cancel();
    notifyListeners();

    if (measurementMode == MeasurementMode.single) {
      _accumulatedReadings.clear();
      _remainingRuns = 0;
      await _performSingleRunStart();
    } else {
      _accumulatedReadings.clear();
      _remainingRuns = 3;
      await _performSingleRunStart();
    }
  }

  Future<void> _performSingleRunStart() async {
    if (_controlChar == null) return;
    _measurementStartTime = DateTime.now();
    await _controlChar!.write(_startCommand, withoutResponse: false);
  }

  /// Cancel measurement
  Future<void> cancelMeasurement() async {
    if (_controlChar == null) return;

    await _controlChar!.write(_cancelCommand, withoutResponse: false);
    _remainingRuns = 0;
    _accumulatedReadings.clear();
    _sessionActive = false;
    isMeasuring = false;
    status = 'Connected — ready';
    notifyListeners();
  }

  void _parseBPM(List<int> data) {
    if (data.length < 7) return;

    double sfloat(int lo, int hi) {
      final raw = (hi << 8) | lo;
      var mantissa = raw & 0x0FFF;
      final exponent = (raw >> 12).toSigned(4);
      if (mantissa >= 0x0800) mantissa = mantissa - 0x1000;
      return mantissa * pow(10.0, exponent.toDouble()).toDouble();
    }

    final flags = data[0];
    final sys = sfloat(data[1], data[2]);
    final dia = sfloat(data[3], data[4]);
    final map = sfloat(data[5], data[6]);

    var idx = 7;
    if ((flags & 0x02) != 0) idx += 7; // timestamp present

    double? hr;
    if ((flags & 0x04) != 0 && data.length >= idx + 2) {
      hr = sfloat(data[idx], data[idx + 1]);
    }

    final reading = BPReading(sys: sys, dia: dia, map: map, hr: hr);

    // Check if reading arrived too quickly (no inflation)
    final elapsedTime = _measurementStartTime != null
        ? DateTime.now().difference(_measurementStartTime!).inSeconds.toDouble()
        : double.infinity;
    final tooQuick = dia > 0 && elapsedTime < _minimumMeasurementSeconds;

    if (tooQuick) {
      _sessionActive = false;
      isMeasuring = false;
      _measurementStartTime = null;
      status = '🪫 Measurement failed — check device battery';
      notifyListeners();
      return;
    }

    lastReading = reading;
    notifyListeners();
    _scheduleFinalize();
  }

  void _scheduleFinalize() {
    _completionTimer?.cancel();
    _completionTimer = Timer(
      Duration(milliseconds: (_completionDebounceSeconds * 1000).toInt()),
      _finalizeIfNeeded,
    );
  }

  void _finalizeIfNeeded() {
    if (!_sessionActive || lastReading == null) return;
    if (lastReading!.dia <= 0) return;

    final reading = lastReading!;

    if (measurementMode == MeasurementMode.average3) {
      if (reading.isPlausible) {
        _accumulatedReadings.add(reading);
      }

      if (_remainingRuns > 1) {
        _remainingRuns--;
        var countdown = delayBetweenRuns.toInt();
        status = 'Measured run ${3 - _remainingRuns} of 3 — next in ${countdown}s…';
        isMeasuring = true;
        notifyListeners();

        Timer.periodic(const Duration(seconds: 1), (timer) {
          countdown--;
          if (countdown > 0) {
            status = 'Measured run ${3 - _remainingRuns} of 3 — next in ${countdown}s…';
            notifyListeners();
          } else {
            timer.cancel();
            status = 'Measuring (run ${4 - _remainingRuns} of 3)…';
            isMeasuring = true;
            notifyListeners();
            _performSingleRunStart();
          }
        });
        return;
      }

      // Last run — compute average
      final avg = _average(_accumulatedReadings);
      _sessionActive = false;
      isMeasuring = false;
      status = 'Connected — ready';
      notifyListeners();
      onFinalReading?.call(avg);
      _remainingRuns = 0;
      _accumulatedReadings.clear();
      return;
    }

    // Single mode
    _sessionActive = false;
    isMeasuring = false;
    status = 'Connected — ready';
    notifyListeners();
    onFinalReading?.call(reading);
  }

  BPReading _average(List<BPReading> readings) {
    final valid = readings.where((r) => r.isPlausible).toList();

    if (valid.isEmpty) {
      if (lastReading != null && lastReading!.isPlausible) {
        return lastReading!;
      }
      return BPReading(sys: 0, dia: 0);
    }

    final n = valid.length.toDouble();
    final sysAvg = valid.map((r) => r.sys).reduce((a, b) => a + b) / n;
    final diaAvg = valid.map((r) => r.dia).reduce((a, b) => a + b) / n;

    final mapVals = valid.where((r) => r.map != null && r.map!.isFinite).map((r) => r.map!).toList();
    final mapAvg = mapVals.isEmpty ? null : mapVals.reduce((a, b) => a + b) / mapVals.length;

    final hrVals = valid
        .where((r) => r.hr != null && r.hr!.isFinite && r.hr! >= 20 && r.hr! <= 220)
        .map((r) => r.hr!)
        .toList();
    final hrAvg = hrVals.isEmpty ? null : hrVals.reduce((a, b) => a + b) / hrVals.length;

    return BPReading(sys: sysAvg, dia: diaAvg, map: mapAvg, hr: hrAvg);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _measurementSubscription?.cancel();
    _completionTimer?.cancel();
    _connectTimeoutTimer?.cancel();
    _device?.disconnect();
    super.dispose();
  }
}
