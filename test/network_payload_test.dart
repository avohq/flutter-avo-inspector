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
}
