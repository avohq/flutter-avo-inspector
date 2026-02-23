import 'dart:convert';

import 'package:avo_inspector/avo_batcher.dart';
import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAvoNetworkCallsHandler extends Mock
    implements AvoNetworkCallsHandler {}

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

  final eventSchemaBody = EventSchemaBody(
      apiKey: 'test-api-key',
      appName: 'test-app-name',
      appVersion: 'test-app-version',
      libVersion: 'test-lib-version',
      env: 'test-env',
      messageId: 'test-message-id',
      anonymousId: 'test-anonymous-id',
      createdAt: 'test-created-at',
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
            anonymousId: "test-anonymous-id"))
        .thenAnswer((_) => eventSchemaBody);
    return mockAvoNetworkCallsHandler;
  }

  test('diskBatcherStorageCacheKey is AvoInspectorEvents', () {
    expect(AvoBatcher.diskBatcherStorageCacheKey, 'AvoInspectorEvents');
  });

  test('flush attempt timestamp is set to now on creation', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();

    // When
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: MockAvoNetworkCallsHandler(),
        avoAnonymousId: "test-anonymous-id");

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
        jsonEncode(eventSchemaBody.toJson()),
        jsonEncode(eventSchemaBody.toJson())
      ]
    });
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    AvoBatcher.batchSizeThreshold = 3;
    final MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        MockAvoNetworkCallsHandler();

    // When
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        avoAnonymousId: "test-anonymous-id");

    // Then
    expect(avoBatcher.events.length, 2);
    expect(avoBatcher.events[0].type, "event");
    expect(avoBatcher.events[1].type, "event");
    verifyNever(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: 'events'), onCompleted: any(named: 'onCompleted')));
  });

  test('batch sending is triggered by size', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    AvoBatcher.batchSizeThreshold = 1;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        avoAnonymousId: "test-anonymous-id");

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    verify(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: 'events'), onCompleted: any(named: 'onCompleted')));
  });

  test('batch sending is not triggered by time or size if both under threshold',
      () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    AvoBatcher.batchSizeThreshold = 2;
    AvoBatcher.batchFlushSecondsThreshold = 2;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        avoAnonymousId: "test-anonymous-id");

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
    AvoBatcher.batchSizeThreshold = 3;
    AvoBatcher.batchFlushSecondsThreshold = 0;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        avoAnonymousId: "test-anonymous-id");

    // When
    avoBatcher.handleTrackSchema(
        eventName: "test-event", eventSchema: eventSchema);

    // Then
    verify(() => mockAvoNetworkCallsHandler.callInspectorWith(
        events: any(named: 'events'), onCompleted: any(named: 'onCompleted')));
  });

  test('handle track schema saves events to disk', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final SharedPreferences sharedPreferences =
        await SharedPreferences.getInstance();
    AvoBatcher.batchSizeThreshold = 2;
    AvoBatcher.batchFlushSecondsThreshold = 2;
    MockAvoNetworkCallsHandler mockAvoNetworkCallsHandler =
        createMockNetworkCallsHandler();
    AvoBatcher avoBatcher = AvoBatcher(
        sharedPreferences: sharedPreferences,
        networkCallsHandler: mockAvoNetworkCallsHandler,
        avoAnonymousId: "test-anonymous-id");

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
