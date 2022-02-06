import 'dart:convert';

import 'package:avo_inspector/avo_batcher.dart';
import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:avo_inspector/avo_session_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAvoNetworkCallsHandler extends Mock
    implements AvoNetworkCallsHandler {}

class MockAvoSessionTracker extends Mock implements AvoSessionTracker {}

void main() {
  final List<Map<String, Object>> eventSchema = [
    {
      "propertyType": "object",
      "children": [
        {"propertyName": "one", "propertyType": "int"},
        {"propertyName": "two", "propertyType": "int"},
        {"propertyName": "three", "propertyType": "null"},
        {"propertyName": "four", "propertyType": "string"},
        {
          "propertyName": "five",
          "propertyType": "list",
          "children": ["string"]
        },
        {
          "propertyName": "six",
          "propertyType": "object",
          "children": [
            {"propertyName": "a", "propertyType": "int"}
          ]
        }
      ]
    }
  ];

  final sessionStartedBody = SessionStartedBody(
      apiKey: 'test-api-key',
      appName: 'test-app-name',
      appVersion: 'test-app-version',
      libVersion: 'test-lib-version',
      env: 'test-env',
      messageId: 'test-message-id',
      trackingId: 'test-tracking-id',
      createdAt: 'test-created-at',
      sessionId: 'test-session-id',
      samplingRate: 1.0);

  final eventScemaBody = EventSchemaBody(
      apiKey: 'test-api-key',
      appName: 'test-app-name',
      appVersion: 'test-app-version',
      libVersion: 'test-lib-version',
      env: 'test-env',
      messageId: 'test-message-id',
      trackingId: 'test-tracking-id',
      createdAt: 'test-created-at',
      sessionId: 'test-session-id',
      samplingRate: 1.0,
      eventName: 'test-event',
      eventSchema: [{}]);

  MockAvoNetworkCallsHandler createMockNetworkCallsHandler() {
    final MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        MockAvoNetworkCallsHandler();
    when(() => mockAvoNetworkCallsHandler.callInspectorWith(
            events: any(named: 'events'),
            onCompleted: any(named: 'onCompleted')))
        .thenAnswer((_) async => Future.value());
    when(() => mockAvoNetworkCallsHandler.bodyForEventSchemaCall(
            eventName: any(named: "eventName"),
            eventSchema: any(named: "eventSchema"),
            sessionId: any(named: "sessionId"),
            installationId: "test-installation-id"))
        .thenAnswer((_) => eventScemaBody);
    when(() => mockAvoNetworkCallsHandler.bodyForSessionStaretedCall(
            sessionId: any(named: "sessionId"),
            installationId: "test-installation-id"))
        .thenAnswer((_) => sessionStartedBody);
    return mockAvoNetworkCallsHandler;
  }

  MockAvoSessionTracker createMockSessionTracker() {
    var mockAvoSessionTracker = MockAvoSessionTracker();
    when(() => mockAvoSessionTracker.lastSessionTimestamp)
        .thenAnswer((_) => DateTime.now().millisecondsSinceEpoch);
    when(() => mockAvoSessionTracker.sessionId)
        .thenAnswer((_) => "test-session-id");
    return mockAvoSessionTracker;
  }

  test('diskBatcherStorageCacheKey is AvoInspectorEvents', () {
    expect(AvoBatcher.diskBatcherStorageCacheKey, 'AvoInspectorEvents');
  });

  test('flush attempt timestamp is set to now on cretion', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();

    final installationId = "test-installation-id";

    // When
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: MockAvoNetworkCallsHandler(),
        sessionTracker: MockAvoSessionTracker(),
        avoInstallationId: installationId);

    // Then
    expect(
        avoBatcher.batchFlushAttemptTimestamp <
            DateTime.now().millisecondsSinceEpoch,
        true);
    expect(
        avoBatcher.batchFlushAttemptTimestamp >
            DateTime.now().millisecondsSinceEpoch - 1000,
        true);
  });

  test('events from shared prefs are parsed and added to the batch on creation',
      () async {
    // Given
    SharedPreferences.setMockInitialValues({
      'AvoInspectorEvents': [
        jsonEncode(sessionStartedBody.toJson()),
        jsonEncode(eventScemaBody.toJson())
      ]
    });
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final installationId = "test-installation-id";
    AvoBatcher.batchSizeThreshold = 3;
    final MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        MockAvoNetworkCallsHandler();

    // When
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        sessionTracker: MockAvoSessionTracker(),
        avoInstallationId: installationId);

    // Then
    expect(avoBatcher.events.length, 2);
    expect(avoBatcher.events[0].type, "sessionStarted");
    expect(avoBatcher.events[1].type, "event");
    verifyNever(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: 'events'), onCompleted: any(named: 'onCompleted')));
  });

  test('batch sending is triggered by size', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final installationId = "test-installation-id";
    AvoBatcher.batchSizeThreshold = 1;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    MockAvoSessionTracker mockAvoSessionTracker = createMockSessionTracker();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        sessionTracker: mockAvoSessionTracker,
        avoInstallationId: installationId);

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    verify(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: 'events'), onCompleted: any(named: 'onCompleted')));
  });

  // batch sending is not triggered by time or size if both under threshold
  test('batch sending is not triggered by time or size if both under threshold',
      () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final installationId = "test-installation-id";
    AvoBatcher.batchSizeThreshold = 2;
    AvoBatcher.batchFlushSecondsThreshold = 2;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    MockAvoSessionTracker mockAvoSessionTracker = createMockSessionTracker();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        sessionTracker: mockAvoSessionTracker,
        avoInstallationId: installationId);

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    verifyNever(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: 'events'), onCompleted: any(named: 'onCompleted')));
  });

  test('batch sending is triggered by time', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final installationId = "test-installation-id";
    AvoBatcher.batchSizeThreshold = 3;
    AvoBatcher.batchFlushSecondsThreshold = 0;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    MockAvoSessionTracker mockAvoSessionTracker = createMockSessionTracker();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        sessionTracker: mockAvoSessionTracker,
        avoInstallationId: installationId);

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    verify(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: 'events'), onCompleted: any(named: 'onCompleted')));
  });

  test('handle track schema starts a session if timestamp is 5+ mins ago',
      () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final installationId = "test-installation-id";
    AvoBatcher.batchSizeThreshold = 3;
    AvoBatcher.batchFlushSecondsThreshold = 20;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    AvoSessionTracker avoSessionTracker =
        AvoSessionTracker(sharedPreferences: sharedPreferences);
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        sessionTracker: avoSessionTracker,
        avoInstallationId: installationId);

    final rightBeforeTime = DateTime.now().millisecondsSinceEpoch;
    avoSessionTracker.lastSessionTimestamp = rightBeforeTime - (5 * 60 * 1000);
    final initialSessionId = avoSessionTracker.sessionId;

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    expect(avoSessionTracker.lastSessionTimestamp > rightBeforeTime, true);
    expect(
        avoSessionTracker.lastSessionTimestamp <
            DateTime.now().millisecondsSinceEpoch,
        true);
    verify(() => mockAvoNetworkCallsHandler.bodyForSessionStaretedCall(
        sessionId: avoSessionTracker.sessionId,
        installationId: "test-installation-id")).called(1);
    verifyNever(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: "events")));
    expect(avoSessionTracker.sessionId, isNot(initialSessionId));
    expect(sharedPreferences.getInt("AvoSessionTimestampId"),
        avoSessionTracker.lastSessionTimestamp);
    expect(avoBatcher.events.length, 2);
    expect(avoBatcher.events[0].type, "sessionStarted");
  });

  test('handle track schema not starts a session if timestamp is 5- mins ago',
      () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final installationId = "test-installation-id";
    AvoBatcher.batchSizeThreshold = 3;
    AvoBatcher.batchFlushSecondsThreshold = 20;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    AvoSessionTracker avoSessionTracker =
        AvoSessionTracker(sharedPreferences: sharedPreferences);
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        sessionTracker: avoSessionTracker,
        avoInstallationId: installationId);

    final rightBeforeTime = DateTime.now().millisecondsSinceEpoch;
    avoSessionTracker.lastSessionTimestamp =
        rightBeforeTime - (5 * 60 * 1000) + 1000;
    final initialSessionId = avoSessionTracker.sessionId;

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    expect(avoSessionTracker.lastSessionTimestamp >= rightBeforeTime, true);
    expect(
        avoSessionTracker.lastSessionTimestamp <=
            DateTime.now().millisecondsSinceEpoch,
        true);
    verifyNever(() => mockAvoNetworkCallsHandler.bodyForSessionStaretedCall(
        sessionId: avoSessionTracker.sessionId,
        installationId: "test-installation-id"));
    verifyNever(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: "events")));
    expect(avoSessionTracker.sessionId, initialSessionId);
    expect(sharedPreferences.getInt("AvoSessionTimestampId"),
        avoSessionTracker.lastSessionTimestamp);
    expect(avoBatcher.events.length, 1);
    expect(avoBatcher.events[0].type, "event");
  });

  test('handle track session saves events to disk', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    final installationId = "test-installation-id";
    AvoBatcher.batchSizeThreshold = 2;
    AvoBatcher.batchFlushSecondsThreshold = 2;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    MockAvoSessionTracker mockAvoSessionTracker = createMockSessionTracker();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        sessionTracker: mockAvoSessionTracker,
        avoInstallationId: installationId);

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    final diskEvents =
        sharedPreferences.getStringList(AvoBatcher.diskBatcherStorageCacheKey);

    expect(avoBatcher.events.length, 1);
    expect(avoBatcher.events[0].type, "event");
    expect(diskEvents?.length, 1);
    expect(diskEvents?[0], json.encode(avoBatcher.events[0].toJson()));
  });

  test('batch size and time can be changed', () {
    // Given
    AvoBatcher.batchSizeThreshold = 30;
    AvoBatcher.batchFlushSecondsThreshold = 30;
    expect(AvoBatcher.batchSizeThreshold, 30);
    expect(AvoBatcher.batchFlushSecondsThreshold, 30);

    // When
    AvoBatcher.batchSizeThreshold = 0;
    AvoBatcher.batchFlushSecondsThreshold = 0;

    // Then
    expect(AvoBatcher.batchSizeThreshold, 0);
    expect(AvoBatcher.batchFlushSecondsThreshold, 0);
  });
}
