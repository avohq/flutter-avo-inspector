import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:avo_inspector/avo_session_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'test_utils.dart';

class MockAvoNetworkCallsHandler extends Mock
    implements AvoNetworkCallsHandler {}

class MockSessionStartedBody extends Mock implements SessionStartedBody {}

void main() {
  AvoNetworkCallsHandler mockNetworkHandler = MockAvoNetworkCallsHandler();

  AvoSessionTracker createAvoSessionTracker(SharedPreferences prefs) {
    return AvoSessionTracker(sharedPreferences: prefs);
  }

  setUp(() {
    when(() => mockNetworkHandler.bodyForSessionStaretedCall(
            sessionId: any(named: "sessionId"),
            installationId: "stored-installation-id"))
        .thenReturn(MockSessionStartedBody());
  });

  test('sessionIdKey equal to "AvoSessionId"', () {
    expect(AvoSessionTracker.sessionIdKey, "AvoSessionId");
  });

  test('lastSessionTimestampKey equal to "AvoSessionTimestampId"', () {
    expect(AvoSessionTracker.lastSessionTimestampKey, "AvoSessionTimestampId");
  });

  test('creates session id if not present anywhere', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // When
    final String sessionId = createAvoSessionTracker(prefs).sessionId;

    // Then
    expect(sessionId, isNot(null));
    expect(isUuid(sessionId), true);
  });

  test('reads session id if not present and stored on disk', () async {
    // Given
    SharedPreferences.setMockInitialValues(
        {"AvoSessionId": "stored-session-id"});
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // When
    final String sessionId = createAvoSessionTracker(prefs).sessionId;

    // Then
    expect(sessionId, "stored-session-id");
  });

  test('reuses session id if in memory', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    SharedPreferences prefs = await SharedPreferences.getInstance();
    AvoSessionTracker avoSessionTracker = createAvoSessionTracker(prefs);

    final String generatedSessionId = avoSessionTracker.sessionId;

    // When
    final reusedSessionId = avoSessionTracker.sessionId;

    // Then
    expect(generatedSessionId, reusedSessionId);
    expect(isUuid(reusedSessionId), true);
  });

  test('last session timestamp is 0 if not present anywhere', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // When
    final int lastSessionTimestamp =
        createAvoSessionTracker(prefs).lastSessionTimestamp;

    // Then
    expect(lastSessionTimestamp, 0);
  });

  test('reuses last session timestamp if not in memory and stored on disk',
      () async {
    // Given
    SharedPreferences.setMockInitialValues({"AvoSessionTimestampId": 9001});
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // When
    final int lastSessionTimestamp =
        createAvoSessionTracker(prefs).lastSessionTimestamp;

    // Then
    expect(lastSessionTimestamp, 9001);
  });

  test('reuses last session timestamp if in memory', () async {
    // Given
    SharedPreferences.setMockInitialValues({"AvoSessionTimestampId": 9001});
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final avoSessionTracker = createAvoSessionTracker(prefs);

    final int oldLastSessionTimestamp = avoSessionTracker.lastSessionTimestamp;

    // When
    final int newLastSessionTimestamp = avoSessionTracker.lastSessionTimestamp;

    // Then
    expect(oldLastSessionTimestamp, newLastSessionTimestamp);
  });

  test('starts a session if timestamp is 0', () async {
    // Given
    SharedPreferences.setMockInitialValues({"AvoSessionTimestampId": 9001});
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final avoSessionTracker = createAvoSessionTracker(prefs);

    final int oldLastSessionTimestamp = avoSessionTracker.lastSessionTimestamp;

    // When
    final int newLastSessionTimestamp = avoSessionTracker.lastSessionTimestamp;

    // Then
    expect(oldLastSessionTimestamp, newLastSessionTimestamp);
  });
}
