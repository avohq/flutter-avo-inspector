import 'package:avo_inspector/avo_anonymous_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_utils.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('storageKey equals "AvoInspectorAnonymousId"', () {
    expect(AvoAnonymousId.storageKey, 'AvoInspectorAnonymousId');
  });

  test('generates a UUID on first call when storage is empty', () async {
    // Given
    SharedPreferences.setMockInitialValues({});

    // When
    final id = await AvoAnonymousId().getAnonymousId();

    // Then
    expect(id, isNotNull);
    expect(isUuid(id), true);
  });

  test('returns same UUID on subsequent calls (in-memory cache)', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final sut = AvoAnonymousId();

    // When
    final id1 = await sut.getAnonymousId();
    final id2 = await sut.getAnonymousId();

    // Then
    expect(id1, id2);
  });

  test('reuses stored UUID from SharedPreferences', () async {
    // Given
    SharedPreferences.setMockInitialValues(
        {AvoAnonymousId.storageKey: 'stored-anonymous-id'});

    // When
    final id = await AvoAnonymousId().getAnonymousId();

    // Then
    expect(id, 'stored-anonymous-id');
  });

  test('persists newly generated UUID to SharedPreferences', () async {
    // Given
    SharedPreferences.setMockInitialValues({});

    // When
    final id = await AvoAnonymousId().getAnonymousId();
    final prefs = await SharedPreferences.getInstance();

    // Then
    expect(prefs.getString(AvoAnonymousId.storageKey), id);
  });

  test('concurrent calls before cache populated all return same UUID', () async {
    // Given
    SharedPreferences.setMockInitialValues({});
    final sut = AvoAnonymousId();

    // When — fire multiple concurrent calls before any completes
    final results = await Future.wait([
      sut.getAnonymousId(),
      sut.getAnonymousId(),
      sut.getAnonymousId(),
    ]);

    // Then — all must be identical
    expect(results[0], results[1]);
    expect(results[1], results[2]);
    expect(isUuid(results[0]), true);
  });

  test('storage read failure returns "unknown" and prints warning', () async {
    // Given — storage factory that always throws (simulates read failure)
    final sut = AvoAnonymousId(
      storageFactory: () => Future.error(Exception('simulated read failure')),
    );

    // When
    final id = await sut.getAnonymousId();

    // Then
    expect(id, 'unknown');
  });

  test('storage write failure still returns in-memory UUID and prints warning',
      () async {
    // Given — storage reads return null (empty), writes throw
    final sut = AvoAnonymousId(
      storageFactory: () async => _ThrowOnWriteStorage(),
    );

    // When
    final id = await sut.getAnonymousId();

    // Then — returns a valid UUID despite the write failure
    expect(id, isNotNull);
    expect(isUuid(id), true);
  });
}

/// Fake [AvoPrefsStorage] that returns null on reads and throws on writes.
class _ThrowOnWriteStorage implements AvoPrefsStorage {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) async {
    throw Exception('simulated write failure');
  }
}
