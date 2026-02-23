import 'package:avo_inspector/avo_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('create factory accepts optional publicEncryptionKey', () async {
    // When — no publicEncryptionKey provided
    final sut = await AvoInspector.create(
        apiKey: 'apiKey',
        env: AvoInspectorEnv.dev,
        appVersion: '1.0',
        appName: 'tests');

    // Then
    expect(sut.publicEncryptionKey, isNull);
  });

  test('create factory stores publicEncryptionKey when provided', () async {
    // When
    final sut = await AvoInspector.create(
        apiKey: 'apiKey',
        env: AvoInspectorEnv.dev,
        appVersion: '1.0',
        appName: 'tests',
        publicEncryptionKey: 'my-public-key');

    // Then
    expect(sut.publicEncryptionKey, 'my-public-key');
  });
}
