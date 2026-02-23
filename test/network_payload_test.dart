import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  test('bodyForEventSchemaCall is properly built', () {
    // Given
    AvoNetworkCallsHandler networkCallsHandler = AvoNetworkCallsHandler(
        apiKey: "apiKey",
        envName: "dev",
        appName: "tests",
        appVersion: "1.0",
        libVersion: "0.1");

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

    // When
    EventSchemaBody eventSchemaBody =
        networkCallsHandler.bodyForEventSchemaCall(
            eventName: "testEvent",
            eventSchema: eventSchema,
            anonymousId: "anonymousId");

    // Then
    expect(eventSchemaBody.type, "event");
    expect(eventSchemaBody.eventSchema, eventSchema);
    expect(eventSchemaBody.apiKey, "apiKey");
    expect(eventSchemaBody.appName, "tests");
    expect(eventSchemaBody.appVersion, "1.0");
    expect(eventSchemaBody.libVersion, "0.1");
    expect(eventSchemaBody.env, "dev");
    expect(isUuid(eventSchemaBody.messageId), true);
    expect(eventSchemaBody.anonymousId, "anonymousId");
    expect(eventSchemaBody.samplingRate, 1.0);
    expect(eventSchemaBody.createdAt.length, 27);
    expect(eventSchemaBody.createdAt.split(":")[0],
        DateTime.now().toIso8601String().split(":")[0]);
  });

  test('BaseBody.fromJson deserializes anonymousId', () {
    // Given
    final json = {
      'type': 'event',
      'apiKey': 'key',
      'appName': 'app',
      'appVersion': '1.0',
      'libVersion': '0.1',
      'env': 'dev',
      'messageId': 'msg-id',
      'anonymousId': 'anon-123',
      'createdAt': '2024-01-01T00:00:00Z',
      'samplingRate': 1.0,
      'eventName': 'test',
      'eventProperties': <Map<String, dynamic>>[{}],
    };

    // When
    final body = EventSchemaBody.fromJson(json);

    // Then
    expect(body.anonymousId, 'anon-123');
  });

  test('BaseBody.fromJson falls back to trackingId for backwards compatibility',
      () {
    // Given - old format with trackingId instead of anonymousId
    final json = {
      'type': 'event',
      'apiKey': 'key',
      'appName': 'app',
      'appVersion': '1.0',
      'libVersion': '0.1',
      'env': 'dev',
      'messageId': 'msg-id',
      'trackingId': 'old-tracking-id',
      'createdAt': '2024-01-01T00:00:00Z',
      'samplingRate': 1.0,
      'eventName': 'test',
      'eventProperties': <Map<String, dynamic>>[{}],
    };

    // When
    final body = EventSchemaBody.fromJson(json);

    // Then
    expect(body.anonymousId, 'old-tracking-id');
  });
}
