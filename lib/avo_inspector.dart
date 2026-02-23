library avo_inspector;

import 'package:avo_inspector/avo_anonymous_id.dart';
import 'package:avo_inspector/avo_batcher.dart';
import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:avo_inspector/avo_parser.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_cache.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_fetcher.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_fetch_types.dart';
import 'package:avo_inspector/event_spec/event_validator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AvoInspectorEnv { prod, dev, staging }

class AvoInspector {
  String apiKey;
  AvoInspectorEnv env;
  String appVersion;
  String appName;
  String? publicEncryptionKey;

  static bool shouldLog = false;

  late AvoBatcher _avoBatcher;

  /// Event validation components (only active in dev/staging).
  EventValidator? eventValidator;
  AvoEventSpecFetcher? _specFetcher;
  EventSpecCache? _specCache;

  static Future<AvoInspector> create(
      {required String apiKey,
      required AvoInspectorEnv env,
      required String appVersion,
      required String appName,
      String? publicEncryptionKey,
      http.Client? specFetchClient}) async {
    final sharedPrefs = await SharedPreferences.getInstance();

    final anonymousIdProvider = AvoAnonymousId();
    final anonymousId = await anonymousIdProvider.getAnonymousId();

    return AvoInspector._create(
        sharedPrefs: sharedPrefs,
        apiKey: apiKey,
        env: env,
        appVersion: appVersion,
        appName: appName,
        publicEncryptionKey: publicEncryptionKey,
        anonymousId: anonymousId,
        specFetchClient: specFetchClient);
  }

  AvoInspector._create(
      {required SharedPreferences sharedPrefs,
      required this.apiKey,
      required this.env,
      required this.appVersion,
      required this.appName,
      this.publicEncryptionKey,
      required String anonymousId,
      http.Client? specFetchClient}) {
    final networkHandler = AvoNetworkCallsHandler(
        apiKey: this.apiKey,
        envName: this.env.toString().split('.').last,
        appName: this.appName,
        appVersion: this.appVersion,
        libVersion: "1.0",
        publicEncryptionKey: this.publicEncryptionKey);

    if (env == AvoInspectorEnv.dev) {
      AvoBatcher.batchSizeThreshold = 1;
    } else {
      AvoBatcher.batchSizeThreshold = 30;
    }

    _avoBatcher = AvoBatcher(
        sharedPreferences: sharedPrefs,
        networkCallsHandler: networkHandler,
        avoAnonymousId: anonymousId);

    // Initialize event validation for dev and staging only
    if (env == AvoInspectorEnv.dev || env == AvoInspectorEnv.staging) {
      final client = specFetchClient ?? http.Client();
      _specFetcher = AvoEventSpecFetcher(client: client);
      _specCache = EventSpecCache();
      eventValidator = EventValidator();
    }
  }

  Future<List<Map<String, dynamic>>> trackSchemaFromEvent(
      {required String eventName,
      required Map<String, dynamic> eventProperties}) async {
    if (shouldLog) {
      print("event name $eventName");
    }

    final parsedParams =
        extractSchemaFromEventParams(eventParams: eventProperties);

    if (shouldLog) {
      print("event params $parsedParams");
    }

    _avoBatcher.handleTrackSchema(
        eventName: eventName, eventSchema: parsedParams);

    // Run event spec validation if active (dev/staging only)
    if (eventValidator != null &&
        _specFetcher != null &&
        _specCache != null) {
      _validateEvent(eventName, parsedParams);
    }

    return parsedParams;
  }

  /// Validate an event against its spec (fire-and-forget).
  Future<ValidationResult?> _validateEvent(
      String eventName, List<Map<String, dynamic>> parsedParams) async {
    try {
      final streamId = apiKey; // Use apiKey as streamId
      final cacheKey =
          EventSpecCache.buildKey(apiKey, streamId, eventName);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Check cache first
      final cached = _specCache!.get(cacheKey, nowMs);
      EventSpecResponse? specResponse;

      if (cached.found) {
        specResponse = cached.response;
      } else {
        // Fetch from API
        specResponse = await _specFetcher!.fetchSpec(
          apiKey: apiKey,
          streamId: streamId,
          eventName: eventName,
        );

        // Cache the result (including null for unknown events)
        _specCache!.put(cacheKey, specResponse,
            DateTime.now().millisecondsSinceEpoch);

        // Check branchId for cache invalidation
        if (specResponse?.metadata?.branchId != null) {
          _specCache!.checkBranchId(specResponse!.metadata!.branchId);
        }
      }

      if (specResponse == null) {
        return null;
      }

      // Build schema map: propertyName -> type string
      final schema = <String, String>{};
      for (final param in parsedParams) {
        final name = param['propertyName'] as String?;
        final type = param['propertyType'] as String?;
        if (name != null && type != null) {
          schema[name] = type;
        }
      }

      final result = eventValidator!.validate(streamId, schema, specResponse);

      if (shouldLog && result != null) {
        print(
            'AvoInspector: Validation result for $eventName - '
            'passed: ${result.passedEventIds.length}, '
            'failed: ${result.failedEventIds.length}');
      }

      return result;
    } catch (e) {
      if (shouldLog) {
        print('AvoInspector: Event validation error: $e');
      }
      return null;
    }
  }
}
