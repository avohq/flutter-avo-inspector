/// Types for event spec fetch responses used in event validation.

/// Metadata about an event spec, returned from the spec endpoint.
class EventSpecMetadata {
  final String schemaId;
  final String branchId;
  final String latestActionId;
  final String sourceId;

  EventSpecMetadata({
    required this.schemaId,
    required this.branchId,
    required this.latestActionId,
    required this.sourceId,
  });

  factory EventSpecMetadata.fromJson(Map<String, dynamic> json) {
    return EventSpecMetadata(
      schemaId: json['schemaId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      latestActionId: json['latestActionId'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
    );
  }
}

/// A single property rule within an event spec.
/// The typePattern is a regex that the property type must match.
class PropertyRule {
  final String propertyName;
  final String typePattern;

  PropertyRule({
    required this.propertyName,
    required this.typePattern,
  });

  factory PropertyRule.fromJson(Map<String, dynamic> json) {
    return PropertyRule(
      propertyName: json['propertyName'] as String,
      typePattern: json['typePattern'] as String,
    );
  }
}

/// Full event spec response from the API.
/// A null propertyRules (with non-null metadata) means the event is unknown.
class EventSpecResponse {
  final EventSpecMetadata? metadata;
  final List<PropertyRule>? propertyRules;

  EventSpecResponse({
    this.metadata,
    this.propertyRules,
  });
}

/// Result of validating an event against its spec.
class ValidationResult {
  final String streamId;
  final EventSpecMetadata metadata;
  final List<String> passedEventIds;
  final List<String> failedEventIds;
  final Map<String, PropertyValidation> propertyValidations;

  ValidationResult({
    required this.streamId,
    required this.metadata,
    required this.passedEventIds,
    required this.failedEventIds,
    required this.propertyValidations,
  });
}

/// Per-property validation results with bandwidth optimization.
/// Only passedEventIds OR failedEventIds is populated:
/// - passedEventIds only when strictly smaller than failedEventIds
/// - failedEventIds when equal or smaller (tie-breaker: use failedEventIds)
class PropertyValidation {
  final List<String>? passedEventIds;
  final List<String>? failedEventIds;

  PropertyValidation({
    this.passedEventIds,
    this.failedEventIds,
  });
}
