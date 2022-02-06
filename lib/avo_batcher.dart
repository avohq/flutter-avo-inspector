import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:avo_inspector/avo_network_calls_handler.dart';

import 'avo_inspector.dart';
import 'avo_session_tracker.dart';

class AvoBatcher {
  static const String diskBatcherStorageCacheKey = "AvoInspectorEvents";

  static int batchSizeThreshold = 30;
  static int batchFlushSecondsThreshold = 30;

  List<BaseBody> _events = [];
  List<BaseBody> get events => _events;

  int _batchFlushAttemptTimestamp;
  get batchFlushAttemptTimestamp => _batchFlushAttemptTimestamp;

  final SharedPreferences sharedPreferences;
  final AvoNetworkCallsHandler networkCallsHandler;

  final String avoInstallationId;

  final AvoSessionTracker sessionTracker;

  AvoBatcher(
      {required this.sharedPreferences,
      required this.networkCallsHandler,
      required this.sessionTracker,
      required this.avoInstallationId})
      : this._batchFlushAttemptTimestamp =
            DateTime.now().millisecondsSinceEpoch {
    _events = sharedPreferences
            .getStringList(diskBatcherStorageCacheKey)
            ?.map((String savedItem) {
          Map<String, dynamic> eventMap = jsonDecode(savedItem);
          if (eventMap["type"] == "sessionStarted") {
            return SessionStartedBody.fromJson(eventMap);
          } else {
            return EventSchemaBody.fromJson(eventMap);
          }
        }).toList() ??
        [];

    _checkIfBatchNeedsToBeSent();
  }

  void _startOrProlongSession(int atTimeMillis) {
    final timeSinceLastSession =
        atTimeMillis - sessionTracker.lastSessionTimestamp;

    if (timeSinceLastSession >= AvoSessionTracker.sessionLengthMillis) {
      sessionTracker.updateSessionId();

      _events.add(networkCallsHandler.bodyForSessionStaretedCall(
          sessionId: sessionTracker.sessionId,
          installationId: avoInstallationId));

      _checkIfBatchNeedsToBeSent();
    }

    sessionTracker.lastSessionTimestamp = atTimeMillis;
  }

  void handleTrackSchema(
      {required String eventName,
      required List<Map<String, dynamic>> eventSchema,
      String? eventId,
      String? eventHash}) {
    _startOrProlongSession(DateTime.now().millisecondsSinceEpoch);

    _events.add(networkCallsHandler.bodyForEventSchemaCall(
        eventName: eventName,
        eventSchema: eventSchema,
        sessionId: sessionTracker.sessionId,
        installationId: avoInstallationId));

    _saveEvents();

    if (AvoInspector.shouldLog) {
      print("Avo Inspector: saved event " +
          eventName +
          " with schema " +
          jsonEncode(eventSchema));
    }

    _checkIfBatchNeedsToBeSent();
  }

  void _checkIfBatchNeedsToBeSent() {
    int batchSize = _events.length;
    int now = DateTime.now().millisecondsSinceEpoch;
    int timeSinceLastFlushAttempt = now - _batchFlushAttemptTimestamp;

    bool sendBySize = batchSize != 0 && batchSize % batchSizeThreshold == 0;
    bool sendByTime =
        timeSinceLastFlushAttempt >= batchFlushSecondsThreshold * 1000;

    if (sendBySize || sendByTime) {
      _batchFlushAttemptTimestamp = now;
      final sendingEvents = _events.toList();
      _events = [];

      networkCallsHandler.callInspectorWith(
          events: sendingEvents,
          onCompleted: (String? error) {
            if (error != null) {
              final newEvents = _events.toList();
              newEvents.addAll(sendingEvents);
              _events = newEvents;

              if (AvoInspector.shouldLog) {
                print("Avo Inspector: batch sending failed: " +
                    error +
                    ". We will attempt to send your schemas with next batch");
              }
            } else {
              if (AvoInspector.shouldLog) {
                print("Avo Inspector: batch sent successfully.");
              }
            }
            _saveEvents();
          });
    }
  }

  void _saveEvents() {
    if (_events.length > 1000) {
      final extraElements = _events.length - 1000;
      _events = _events.sublist(extraElements);
    }

    final eventsJson = _eventsAsJson();

    sharedPreferences.setStringList(
        diskBatcherStorageCacheKey, eventsJson);
  }

  List<String> _eventsAsJson() {
    return _events.map((BaseBody event) => jsonEncode(event.toJson())).toList();
  }
}
