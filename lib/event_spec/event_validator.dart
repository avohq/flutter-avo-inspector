import 'package:avo_inspector/event_spec/avo_event_spec_fetch_types.dart';

/// Validates event property types against event spec rules using Dart RegExp.
///
/// Dart RegExp is linear-time (safe) - no additional regex safety library needed.
///
/// Bandwidth optimization for per-property results:
/// - Only include passedEventIds when its size is strictly less than failedEventIds size
/// - When sizes are equal, use failedEventIds (tie-breaker)
class EventValidator {
  /// Cache compiled patterns to avoid recompilation
  final Map<String, RegExp> _patternCache = {};

  /// Optional logging flag (set by caller, e.g. AvoInspector.shouldLog).
  bool shouldLog = false;

  /// Validate event properties against spec rules.
  ///
  /// Returns [ValidationResult] or null if spec has no rules.
  ValidationResult? validate(
    String streamId,
    Map<String, String> schema,
    EventSpecResponse specResponse,
  ) {
    if (specResponse.metadata == null || specResponse.propertyRules == null) {
      return null;
    }

    final List<String> passedEventIds = [];
    final List<String> failedEventIds = [];
    final Map<String, PropertyValidation> propertyValidations = {};

    for (final rule in specResponse.propertyRules!) {
      final propertyName = rule.propertyName;
      final typePattern = rule.typePattern;

      final actualTypeName = schema[propertyName] ?? 'null';
      final matches = matchesPattern(typePattern, actualTypeName);
      final ruleId = '$propertyName:$typePattern';

      if (matches) {
        passedEventIds.add(ruleId);
      } else {
        failedEventIds.add(ruleId);
      }

      // Bandwidth optimization per property
      final List<String> propPassed = [];
      final List<String> propFailed = [];
      if (matches) {
        propPassed.add(ruleId);
      } else {
        propFailed.add(ruleId);
      }

      propertyValidations[propertyName] =
          _buildBandwidthOptimizedValidation(propPassed, propFailed);
    }

    // Global bandwidth optimization
    List<String> optimizedPassed;
    List<String> optimizedFailed;
    if (passedEventIds.length < failedEventIds.length) {
      optimizedPassed = passedEventIds;
      optimizedFailed = [];
    } else {
      // Equal or failed is smaller: use failedEventIds
      optimizedPassed = [];
      optimizedFailed = failedEventIds;
    }

    return ValidationResult(
      streamId: streamId,
      metadata: specResponse.metadata!,
      passedEventIds: optimizedPassed,
      failedEventIds: optimizedFailed,
      propertyValidations: propertyValidations,
    );
  }

  /// Build bandwidth-optimized property validation.
  /// passedEventIds returned only when strictly smaller than failedEventIds.
  /// Equal-size arrays use failedEventIds (tie-breaker).
  PropertyValidation _buildBandwidthOptimizedValidation(
    List<String> passed,
    List<String> failed,
  ) {
    if (passed.length < failed.length) {
      return PropertyValidation(passedEventIds: passed, failedEventIds: null);
    } else {
      return PropertyValidation(passedEventIds: null, failedEventIds: failed);
    }
  }

  /// Match a type string against a regex pattern.
  bool matchesPattern(String pattern, String value) {
    try {
      RegExp compiled = _patternCache[pattern] ??= RegExp('^$pattern\$');
      _patternCache[pattern] = compiled;
      return compiled.hasMatch(value);
    } catch (e) {
      if (shouldLog) {
        print('AvoInspector: Invalid regex pattern: $pattern - $e');
      }
      return false;
    }
  }
}
