import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:avo_inspector/event_spec/avo_event_spec_fetcher.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_fetch_types.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_cache.dart';

void main() {
  group('AvoEventSpecFetcher', () {
    test('fetches and parses a valid spec response', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.queryParameters['apiKey'], 'testKey');
        expect(request.url.queryParameters['streamId'], 'stream1');
        expect(request.url.queryParameters['eventName'], 'testEvent');

        return http.Response(
          jsonEncode({
            'metadata': {
              'schemaId': 's1',
              'branchId': 'b1',
              'latestActionId': 'a1',
              'sourceId': 'src1',
            },
            'propertyRules': [
              {'propertyName': 'name', 'typePattern': 'string'},
            ],
          }),
          200,
        );
      });

      final fetcher = AvoEventSpecFetcher(client: mockClient);

      final result = await fetcher.fetchSpec(
        apiKey: 'testKey',
        streamId: 'stream1',
        eventName: 'testEvent',
      );

      expect(result, isNotNull);
      expect(result!.metadata, isNotNull);
      expect(result.metadata!.schemaId, 's1');
      expect(result.metadata!.branchId, 'b1');
      expect(result.propertyRules, isNotNull);
      expect(result.propertyRules!.length, 1);
      expect(result.propertyRules!.first.propertyName, 'name');
    });

    test('returns null on HTTP error', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final fetcher = AvoEventSpecFetcher(client: mockClient);

      final result = await fetcher.fetchSpec(
        apiKey: 'testKey',
        streamId: 'stream1',
        eventName: 'testEvent',
      );

      expect(result, isNull);
    });

    test('returns null on network error', () async {
      final mockClient = http_testing.MockClient((request) async {
        throw Exception('Network error');
      });

      final fetcher = AvoEventSpecFetcher(client: mockClient);

      final result = await fetcher.fetchSpec(
        apiKey: 'testKey',
        streamId: 'stream1',
        eventName: 'testEvent',
      );

      expect(result, isNull);
    });

    test('parses response with null metadata', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(jsonEncode({}), 200);
      });

      final fetcher = AvoEventSpecFetcher(client: mockClient);

      final result = await fetcher.fetchSpec(
        apiKey: 'testKey',
        streamId: 'stream1',
        eventName: 'testEvent',
      );

      expect(result, isNotNull);
      expect(result!.metadata, isNull);
      expect(result.propertyRules, isNull);
    });

    group('in-flight de-duplication', () {
      test('only makes one HTTP request for concurrent same-key fetches',
          () async {
        int requestCount = 0;

        final mockClient = http_testing.MockClient((request) async {
          requestCount++;
          // Simulate some network delay
          await Future.delayed(Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'metadata': {
                'schemaId': 's1',
                'branchId': 'b1',
                'latestActionId': 'a1',
                'sourceId': 'src1',
              },
              'propertyRules': [],
            }),
            200,
          );
        });

        final fetcher = AvoEventSpecFetcher(client: mockClient);

        // Launch multiple concurrent requests for the same key
        final futures = List.generate(
          5,
          (_) => fetcher.fetchSpec(
            apiKey: 'testKey',
            streamId: 'stream1',
            eventName: 'testEvent',
          ),
        );

        final results = await Future.wait(futures);

        // Only 1 HTTP request should have been made
        expect(requestCount, 1);

        // All should get the same result
        for (final result in results) {
          expect(result, isNotNull);
          expect(result!.metadata!.schemaId, 's1');
        }
      });

      test('all queued callbacks resolved with null on fetch failure',
          () async {
        final mockClient = http_testing.MockClient((request) async {
          await Future.delayed(Duration(milliseconds: 50));
          throw Exception('Network error');
        });

        final fetcher = AvoEventSpecFetcher(client: mockClient);

        final futures = List.generate(
          3,
          (_) => fetcher.fetchSpec(
            apiKey: 'testKey',
            streamId: 'stream1',
            eventName: 'testEvent',
          ),
        );

        final results = await Future.wait(futures);

        for (final result in results) {
          expect(result, isNull);
        }
      });
    });

    test('isInFlight returns true during request', () async {
      final mockClient = http_testing.MockClient((request) async {
        await Future.delayed(Duration(milliseconds: 100));
        return http.Response(jsonEncode({}), 200);
      });

      final fetcher = AvoEventSpecFetcher(client: mockClient);
      final key = EventSpecCache.buildKey('testKey', 'stream1', 'testEvent');

      // Start a request but don't await it yet
      final future = fetcher.fetchSpec(
        apiKey: 'testKey',
        streamId: 'stream1',
        eventName: 'testEvent',
      );

      // Allow microtasks to run so the fetch begins
      await Future.delayed(Duration(milliseconds: 10));

      expect(fetcher.isInFlight(key), true);

      await future;

      expect(fetcher.isInFlight(key), false);
    });
  });
}
