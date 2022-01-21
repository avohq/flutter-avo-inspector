import 'package:avo_inspector/avo_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AvoInspector sut;

  setUp(() {
    sut = AvoInspector(apiKey: "apiKey", env: AvoInspectorEnv.dev, appVersion: "1.9", appName: "tests");
  });

  test('constructor parameters are saved', () {
    expect(sut.apiKey, "apiKey");
    expect(sut.env, AvoInspectorEnv.dev);
    expect(sut.appVersion, "1.9");
    expect(sut.appName, "tests");
  });

  test('trackSchemaFromEvent returns the params schema', () {
    final result = sut.trackSchemaFromEvent(eventName: "Event 0", eventProperties: {"param0" : "value0", "param1" : "value1"});

    expect(result.length, 2);
    expect(result[0]["propertyName"], "param0");
    expect(result[1]["propertyName"], "param1");
    expect(result[0]["propertyType"], "string");
    expect(result[1]["propertyType"], "string");
  });

  test('trackSchemaFromEvent prints when the logs are enabled', () {
    AvoInspector.shouldLog = true;
    sut.trackSchemaFromEvent(eventName: "Event 0", eventProperties: {"param0" : "value0", "param1" : "value1"});
  });
}
