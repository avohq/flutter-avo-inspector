import 'package:avo_inspector/avo_batcher.dart';
import 'package:avo_inspector/avo_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Dev should set batch size to 1 by default', () async {
    AvoInspector sut = await AvoInspector.create(
        apiKey: "apiKey",
        env: AvoInspectorEnv.dev,
        appVersion: "1.9",
        appName: "tests");

    expect(AvoBatcher.batchSizeThreshold, 1);
  });

  test('Prod should set batch size to 30 by default', () async {
    AvoInspector sut = await AvoInspector.create(
        apiKey: "apiKey",
        env: AvoInspectorEnv.prod,
        appVersion: "1.9",
        appName: "tests");

    expect(AvoBatcher.batchSizeThreshold, 30);
  });

  test('constructor parameters are saved', () async {
    AvoInspector sut = await AvoInspector.create(
        apiKey: "apiKey",
        env: AvoInspectorEnv.dev,
        appVersion: "1.9",
        appName: "tests");

    expect(sut.apiKey, "apiKey");
    expect(sut.env, AvoInspectorEnv.dev);
    expect(sut.appVersion, "1.9");
    expect(sut.appName, "tests");
  });

  test('trackSchemaFromEvent returns the params schema', () async {
    AvoInspector sut = await AvoInspector.create(
        apiKey: "apiKey",
        env: AvoInspectorEnv.dev,
        appVersion: "1.9",
        appName: "tests");

    // When
    final result = await sut.trackSchemaFromEvent(
        eventName: "Event 0",
        eventProperties: {"param0": "value0", "param1": "value1"});

    // Then
    expect(result.length, 2);
    expect(result[0]["propertyName"], "param0");
    expect(result[1]["propertyName"], "param1");
    expect(result[0]["propertyType"], "string");
    expect(result[1]["propertyType"], "string");
  });

  test('trackSchemaFromEvent prints when the logs are enabled', () async {
    AvoInspector sut = await AvoInspector.create(
        apiKey: "apiKey",
        env: AvoInspectorEnv.dev,
        appVersion: "1.9",
        appName: "tests");

    AvoInspector.shouldLog = true;
    sut = await AvoInspector.create(
        apiKey: "apiKey",
        env: AvoInspectorEnv.dev,
        appVersion: "1.9",
        appName: "tests");

    sut.trackSchemaFromEvent(
        eventName: "Event 0",
        eventProperties: {"param0": "value0", "param1": "value1"});
  });
}
