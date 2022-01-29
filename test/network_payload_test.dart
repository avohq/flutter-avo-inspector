import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  test('bodyForSessionStaretedCall is properly built', () {
    // Given
    AvoNetworkCallsHandler networkCallsHandler = AvoNetworkCallsHandler(
        apiKey: "apiKey",
        envName: "dev",
        appName: "tests",
        appVersion: "1.0",
        libVersion: "0.1");

    // When
    SessionStartedBody sessionStartedBody =
        networkCallsHandler.bodyForSessionStaretedCall(
            sessionId: "sessionId", installationId: "installationId");

    // Then
    expect(sessionStartedBody.type, "sessionStarted");
    expect(sessionStartedBody.apiKey, "apiKey");
    expect(sessionStartedBody.appName, "tests");
    expect(sessionStartedBody.appVersion, "1.0");
    expect(sessionStartedBody.libVersion, "0.1");
    expect(sessionStartedBody.env, "dev");
    expect(sessionStartedBody.env, "dev");
    expect(isUuid(sessionStartedBody.messageId), true);
    expect(sessionStartedBody.trackingId, "installationId");
    expect(sessionStartedBody.sessionId, "sessionId");
    expect(sessionStartedBody.createdAt.length, 26);
    expect(sessionStartedBody.createdAt.split(":")[0],
        DateTime.now().toIso8601String().split(":")[0]);
  });

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
            sessionId: "sessionId",
            installationId: "installationId");

    // Then
    expect(eventSchemaBody.type, "event");
    expect(eventSchemaBody.eventSchema, eventSchema);
    expect(eventSchemaBody.apiKey, "apiKey");
    expect(eventSchemaBody.appName, "tests");
    expect(eventSchemaBody.appVersion, "1.0");
    expect(eventSchemaBody.libVersion, "0.1");
    expect(eventSchemaBody.env, "dev");
    expect(eventSchemaBody.env, "dev");
    expect(isUuid(eventSchemaBody.messageId), true);
    expect(eventSchemaBody.trackingId, "installationId");
    expect(eventSchemaBody.sessionId, "sessionId");
    expect(eventSchemaBody.createdAt.length, 26);
    expect(eventSchemaBody.createdAt.split(":")[0],
        DateTime.now().toIso8601String().split(":")[0]);
  });
}
