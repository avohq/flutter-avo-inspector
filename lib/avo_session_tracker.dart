import 'package:avo_inspector/avo_installation_id.dart';
import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AvoSessionTracker {
  static const sessionIdKey = "AvosSessionId";
  static const lastSessionTimestampKey = "AvoSessionTimestampId";

  static const sessionLengthMillis = 5 * 60 * 1000;

  String? _sessionId;
  get sessionId {
    if (_sessionId == null) {
      final storedSessionId = sharedPreferences.getString(sessionIdKey);

      if (storedSessionId != null) {
        _sessionId = storedSessionId;
      } else {
        _updateSessionId();
      }
    }

    return _sessionId;
  }

  int? _lastSessionTimestamp;
  get lastSessionTimestamp {
    if (_lastSessionTimestamp == null || _lastSessionTimestamp == 0) {
      final storedTimestamp = sharedPreferences.getInt(lastSessionTimestampKey);

      if (storedTimestamp != null) {
        _lastSessionTimestamp = storedTimestamp;
      } else {
        _lastSessionTimestamp = 0;
      }
    }

    return _lastSessionTimestamp;
  }

  final AvoNetworkCallsHandler networkCallsHandler;
  final SharedPreferences sharedPreferences;
  final AvoInstallationId avoInstallationId = AvoInstallationId();

  AvoSessionTracker(
      {required this.networkCallsHandler, required this.sharedPreferences});

  void _updateSessionId() {
    final newSessionId = Uuid().v1();
    sharedPreferences.setString(sessionIdKey, newSessionId);
    _sessionId = newSessionId;
  }

  void startOrProlongSession(int atTimeMillis) {
    final timeSinceLastSession = atTimeMillis - lastSessionTimestamp;

    if (timeSinceLastSession > sessionLengthMillis) {
      _updateSessionId();
      networkCallsHandler.callInspectorWith(events: [
        networkCallsHandler.bodyForSessionStaretedCall(
            sessionId: sessionId,
            installationId:
                avoInstallationId.getInstallationId(sharedPreferences))
      ]);
    }

    _lastSessionTimestamp = atTimeMillis;

    sharedPreferences.setInt(lastSessionTimestampKey, atTimeMillis);
  }
}
