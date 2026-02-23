import 'package:flutter_test/flutter_test.dart';
import 'package:avo_inspector/event_spec/event_validator.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_fetch_types.dart';

void main() {
  late EventValidator validator;

  setUp(() {
    validator = EventValidator();
  });

  group('matchesPattern', () {
    test('matches exact type', () {
      expect(validator.matchesPattern('string', 'string'), true);
    });

    test('does not match different type', () {
      expect(validator.matchesPattern('string', 'int'), false);
    });

    test('matches regex pattern', () {
      expect(validator.matchesPattern('string|int', 'string'), true);
      expect(validator.matchesPattern('string|int', 'int'), true);
      expect(validator.matchesPattern('string|int', 'bool'), false);
    });

    test('handles wildcard pattern', () {
      expect(validator.matchesPattern('.*', 'anything'), true);
    });

    test('returns false for invalid regex', () {
      expect(validator.matchesPattern('[invalid', 'test'), false);
    });
  });

  group('validate', () {
    final metadata = EventSpecMetadata(
      schemaId: 's1',
      branchId: 'b1',
      latestActionId: 'a1',
      sourceId: 'src1',
    );

    test('returns null when metadata is null', () {
      final spec = EventSpecResponse(metadata: null, propertyRules: []);
      final result = validator.validate('stream1', {}, spec);
      expect(result, isNull);
    });

    test('returns null when propertyRules is null', () {
      final spec = EventSpecResponse(metadata: metadata, propertyRules: null);
      final result = validator.validate('stream1', {}, spec);
      expect(result, isNull);
    });

    test('validates matching properties', () {
      final spec = EventSpecResponse(
        metadata: metadata,
        propertyRules: [
          PropertyRule(propertyName: 'name', typePattern: 'string'),
          PropertyRule(propertyName: 'age', typePattern: 'int'),
        ],
      );

      final schema = {'name': 'string', 'age': 'int'};
      final result = validator.validate('stream1', schema, spec);

      expect(result, isNotNull);
      expect(result!.streamId, 'stream1');
      expect(result.metadata, metadata);
      // All passed - passedEventIds is empty (bandwidth: failedEventIds used when equal or smaller)
      // 2 passed, 0 failed -> passed is larger, use failedEventIds
      expect(result.failedEventIds, isEmpty);
    });

    test('validates failing properties', () {
      final spec = EventSpecResponse(
        metadata: metadata,
        propertyRules: [
          PropertyRule(propertyName: 'name', typePattern: 'string'),
          PropertyRule(propertyName: 'age', typePattern: 'int'),
        ],
      );

      final schema = {'name': 'string', 'age': 'string'}; // age is wrong
      final result = validator.validate('stream1', schema, spec);

      expect(result, isNotNull);
      // 1 passed, 1 failed -> equal sizes, use failedEventIds
      expect(result!.failedEventIds, isNotEmpty);
      expect(result.passedEventIds, isEmpty);
    });

    test('treats missing properties as null type', () {
      final spec = EventSpecResponse(
        metadata: metadata,
        propertyRules: [
          PropertyRule(propertyName: 'missing', typePattern: 'string'),
        ],
      );

      final schema = <String, String>{};
      final result = validator.validate('stream1', schema, spec);

      expect(result, isNotNull);
      // 'null' does not match 'string'
      expect(result!.failedEventIds, isNotEmpty);
    });

    test('bandwidth optimization: passedEventIds only when strictly smaller', () {
      final spec = EventSpecResponse(
        metadata: metadata,
        propertyRules: [
          PropertyRule(propertyName: 'a', typePattern: 'string'),
          PropertyRule(propertyName: 'b', typePattern: 'int'),
          PropertyRule(propertyName: 'c', typePattern: 'bool'),
        ],
      );

      // Only 'a' passes, 'b' and 'c' fail
      // 1 passed < 2 failed -> use passedEventIds
      final schema = {'a': 'string', 'b': 'string', 'c': 'string'};
      final result = validator.validate('stream1', schema, spec);

      expect(result, isNotNull);
      expect(result!.passedEventIds, isNotEmpty);
      expect(result.failedEventIds, isEmpty);
    });

    test('per-property bandwidth optimization', () {
      final spec = EventSpecResponse(
        metadata: metadata,
        propertyRules: [
          PropertyRule(propertyName: 'name', typePattern: 'string'),
        ],
      );

      // Property matches
      final schema = {'name': 'string'};
      final result = validator.validate('stream1', schema, spec);

      expect(result, isNotNull);
      final propValidation = result!.propertyValidations['name'];
      expect(propValidation, isNotNull);
      // 1 passed, 0 failed -> passed is not strictly smaller, use failedEventIds
      // Actually: 1 passed vs 0 failed -> passed > failed, use failedEventIds
      expect(propValidation!.failedEventIds, isNotNull);
      expect(propValidation.failedEventIds, isEmpty);
      expect(propValidation.passedEventIds, isNull);
    });
  });
}
