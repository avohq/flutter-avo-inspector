import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avo_inspector/avo_inspector.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('validation is only active in dev and staging', () async {
    final inspector = await AvoInspector.create(
      apiKey: 'testKey',
      env: AvoInspectorEnv.prod,
      appVersion: '1.0',
      appName: 'test',
    );

    // prod should not have an event validator
    expect(inspector.eventValidator, isNull);
  });

  test('validation is active in dev', () async {
    final mockClient = http_testing.MockClient((request) async {
      return http.Response(jsonEncode({}), 200);
    });

    final inspector = await AvoInspector.create(
      apiKey: 'testKey',
      env: AvoInspectorEnv.dev,
      appVersion: '1.0',
      appName: 'test',
      specFetchClient: mockClient,
    );

    expect(inspector.eventValidator, isNotNull);
  });

  test('validation is active in staging', () async {
    final mockClient = http_testing.MockClient((request) async {
      return http.Response(jsonEncode({}), 200);
    });

    final inspector = await AvoInspector.create(
      apiKey: 'testKey',
      env: AvoInspectorEnv.staging,
      appVersion: '1.0',
      appName: 'test',
      specFetchClient: mockClient,
    );

    expect(inspector.eventValidator, isNotNull);
  });
}
