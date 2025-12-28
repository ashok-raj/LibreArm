import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();
  bool _authorized = false;

  bool get isAuthorized => _authorized;

  /// Request authorization for blood pressure and heart rate
  Future<bool> requestAuth() async {
    final types = [
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      HealthDataType.HEART_RATE,
    ];

    final permissions = types.map((_) => HealthDataAccess.READ_WRITE).toList();

    try {
      _authorized = await _health.requestAuthorization(types, permissions: permissions);
      return _authorized;
    } catch (e) {
      _authorized = false;
      return false;
    }
  }

  /// Save blood pressure reading to Health
  Future<bool> saveBP({
    required double systolic,
    required double diastolic,
    double? bpm,
    DateTime? date,
  }) async {
    if (!_authorized) return false;

    final now = date ?? DateTime.now();
    var success = true;

    try {
      // Save systolic
      success &= await _health.writeHealthData(
        value: systolic,
        type: HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        startTime: now,
        endTime: now,
        unit: HealthDataUnit.MILLIMETER_OF_MERCURY,
      );

      // Save diastolic
      success &= await _health.writeHealthData(
        value: diastolic,
        type: HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        startTime: now,
        endTime: now,
        unit: HealthDataUnit.MILLIMETER_OF_MERCURY,
      );

      // Save heart rate if available
      if (bpm != null && bpm > 0) {
        success &= await _health.writeHealthData(
          value: bpm,
          type: HealthDataType.HEART_RATE,
          startTime: now,
          endTime: now,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
        );
      }

      return success;
    } catch (e) {
      return false;
    }
  }
}
