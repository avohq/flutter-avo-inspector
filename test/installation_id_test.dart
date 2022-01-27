import 'package:avo_inspector/avo_installation_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cacheKey equal to "AvoInspectorInstallationId"', () {
    expect(AvoInstallationId.installationIdKey, "AvoInspectorInstallationId");
  });

  test('Creates installation id if not present', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // When
    final String? futureInstallationId =
        AvoInstallationId().getInstallationId(prefs);

    // Then
    expect(futureInstallationId, isNot(null));
  });

  test('Reuses installation id if present', () async {
    // Given
    SharedPreferences.setMockInitialValues(
        {"AvoInspectorInstallationId": "existing-key"});
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // When
    final String? futureInstallationId =
        AvoInstallationId().getInstallationId(prefs);

    // Then
    expect(futureInstallationId, "existing-key");
  });
}
