import 'dart:convert';

import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class VeryMockClient extends Mock implements Client {}

void main() {
  AvoNetworkCallsHandler networkCallsHandler = AvoNetworkCallsHandler(
      apiKey: "apiKey",
      envName: "dev",
      appName: "tests",
      appVersion: "1.0",
      libVersion: "0.1");

  test('Default sampling rate is 1', () {
    AvoNetworkCallsHandler networkCallsHandler = AvoNetworkCallsHandler(
        apiKey: "apiKey",
        envName: "dev",
        appName: "tests",
        appVersion: "1.0",
        libVersion: "0.1");

    expect(networkCallsHandler.samplingRate, equals(1.0));
  });

  test('Request is not made when sampling is 0', () {
    // Given
    networkCallsHandler.samplingRate = 0;

    networkCallsHandler.client = VeryMockClient();

    // When
    networkCallsHandler.callInspectorWith(events: []);

    // Then
    verifyNever(() => networkCallsHandler.client
        .post(any(), headers: any(named: "headers"), body: any(named: "body")));
    verifyNoMoreInteractions(networkCallsHandler.client);
  });

  test('Request is made when sampling is 1 and returned sampling rate is applied', () async {
    // Given
    networkCallsHandler.samplingRate = 1.0;

    bool isCalled = false;

    networkCallsHandler.client = MockClient((request) async {
      final mapJson = {'samplingRate': 0};
      isCalled = true;
      return Response(json.encode(mapJson), 200);
    });

    // When
    await networkCallsHandler.callInspectorWith(events: []);

    // Then
    expect(networkCallsHandler.samplingRate, equals(0.0));
    expect(isCalled, equals(true));
  });
}