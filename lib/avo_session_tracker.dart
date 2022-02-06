import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AvoSessionTracker {
  static const sessionIdKey = "AvoSessionId";
  static const lastSessionTimestampKey = "AvoSessionTimestampId";

  static const sessionLengthMillis = 5 * 60 * 1000;

  String? _sessionId;
  String get sessionId {
    if (_sessionId == null) {
      final storedSessionId = sharedPreferences.getString(sessionIdKey);

      if (storedSessionId != null) {
        _sessionId = storedSessionId;
      } else {
        updateSessionId();
      }
    }

    return _sessionId!;
  }

  int? _lastSessionTimestamp;
  int get lastSessionTimestamp {
    if (_lastSessionTimestamp == null || _lastSessionTimestamp == 0) {
      final storedTimestamp = sharedPreferences.getInt(lastSessionTimestampKey);

      if (storedTimestamp != null) {
        _lastSessionTimestamp = storedTimestamp;
      } else {
        _lastSessionTimestamp = 0;
      }
    }

    return _lastSessionTimestamp!;
  }

  set lastSessionTimestamp(int newTimestamp) {
    _lastSessionTimestamp = newTimestamp;

    sharedPreferences.setInt(
        AvoSessionTracker.lastSessionTimestampKey, newTimestamp);
  }

  final SharedPreferences sharedPreferences;

  AvoSessionTracker({required this.sharedPreferences});

  void updateSessionId() {
    final newSessionId = Uuid().v1();
    sharedPreferences.setString(sessionIdKey, newSessionId);
    _sessionId = newSessionId;
  }
}
