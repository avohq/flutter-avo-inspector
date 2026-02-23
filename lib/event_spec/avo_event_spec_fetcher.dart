import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:avo_inspector/event_spec/avo_event_spec_fetch_types.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_cache.dart';

/// HTTP GET fetcher for event specs with in-flight de-duplication.
///
/// If a request for a given key is already in-flight, additional requests
/// for the same key will queue and share the single HTTP response.
///
/// On success: all queued completers are resolved with the parsed result.
/// On failure: all queued completers are resolved with null.
class AvoEventSpecFetcher {
  static const String _specEndpoint =
      'https://api.avo.app/inspector/v1/spec';

  final http.Client _client;

  /// Optional logging flag (set by caller).
  bool shouldLog = false;

  /// In-flight deduplication map: key -> list of pending completers
  final Map<String, List<Completer<EventSpecResponse?>>> _inFlightRequests =
      {};

  AvoEventSpecFetcher({required http.Client client}) : _client = client;

  /// Fetch event spec with in-flight de-duplication.
  ///
  /// Returns the parsed [EventSpecResponse] or null on failure.
  Future<EventSpecResponse?> fetchSpec({
    required String apiKey,
    required String streamId,
    required String eventName,
  }) {
    final key = EventSpecCache.buildKey(apiKey, streamId, eventName);
    final completer = Completer<EventSpecResponse?>();

    if (_inFlightRequests.containsKey(key)) {
      // Already in-flight, queue completer
      _inFlightRequests[key]!.add(completer);
      return completer.future;
    }

    // New request
    _inFlightRequests[key] = [completer];

    _doFetch(apiKey: apiKey, streamId: streamId, eventName: eventName, key: key);

    return completer.future;
  }

  /// Check if a request for the given key is currently in-flight.
  bool isInFlight(String key) {
    return _inFlightRequests.containsKey(key);
  }

  Future<void> _doFetch({
    required String apiKey,
    required String streamId,
    required String eventName,
    required String key,
  }) async {
    EventSpecResponse? result;
    try {
      final uri = Uri.parse(_specEndpoint).replace(queryParameters: {
        'apiKey': apiKey,
        'streamId': streamId,
        'eventName': eventName,
      });

      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        result = parseResponse(response.body);
      } else {
        if (shouldLog) {
          print(
              'AvoInspector: Spec fetch failed with code ${response.statusCode}');
        }
        result = null;
      }
    } catch (e) {
      if (shouldLog) {
        print('AvoInspector: Failed to fetch event spec: $e');
      }
      result = null;
    } finally {
      // Resolve all pending completers
      final completers = _inFlightRequests.remove(key);
      if (completers != null) {
        for (final c in completers) {
          c.complete(result);
        }
      }
    }
  }

  /// Parse the JSON response body into an EventSpecResponse.
  static EventSpecResponse? parseResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      EventSpecMetadata? metadata;
      if (json.containsKey('metadata') && json['metadata'] != null) {
        metadata = EventSpecMetadata.fromJson(
            json['metadata'] as Map<String, dynamic>);
      }

      List<PropertyRule>? rules;
      if (json.containsKey('propertyRules') && json['propertyRules'] != null) {
        final rulesJson = json['propertyRules'] as List<dynamic>;
        rules = rulesJson
            .map((r) => PropertyRule.fromJson(r as Map<String, dynamic>))
            .toList();
      }

      return EventSpecResponse(metadata: metadata, propertyRules: rules);
    } catch (e) {
      return null;
    }
  }
}
