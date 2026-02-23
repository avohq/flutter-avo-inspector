import 'package:flutter_test/flutter_test.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_cache.dart';
import 'package:avo_inspector/event_spec/avo_event_spec_fetch_types.dart';

void main() {
  late EventSpecCache cache;

  setUp(() {
    cache = EventSpecCache();
  });

  group('buildKey', () {
    test('combines apiKey, streamId, and eventName with colons', () {
      expect(
        EventSpecCache.buildKey('api1', 'stream1', 'event1'),
        'api1:stream1:event1',
      );
    });
  });

  group('put and get', () {
    test('stores and retrieves a response', () {
      final response = EventSpecResponse(
        metadata: EventSpecMetadata(
          schemaId: 's1',
          branchId: 'b1',
          latestActionId: 'a1',
          sourceId: 'src1',
        ),
        propertyRules: [],
      );

      cache.put('key1', response, 1000);
      final result = cache.get('key1', 1000);

      expect(result.found, true);
      expect(result.response, response);
    });

    test('returns not found for missing key', () {
      final result = cache.get('missing', 1000);
      expect(result.found, false);
      expect(result.response, isNull);
    });

    test('caches null responses (for unknown events)', () {
      cache.put('key1', null, 1000);
      final result = cache.get('key1', 1000);

      expect(result.found, true);
      expect(result.response, isNull);
    });
  });

  group('TTL eviction', () {
    test('evicts entries older than 60 seconds', () {
      cache.put('key1', null, 1000);

      // Before TTL expires
      final before = cache.get('key1', 60999);
      expect(before.found, true);

      // After TTL expires (60001 ms later)
      final after = cache.get('key1', 61001);
      expect(after.found, false);
    });
  });

  group('per-entry eviction', () {
    test('evicts entry after 50 accesses', () {
      cache.put('key1', null, 1000);

      // Access 49 times - should still be found
      for (int i = 0; i < 49; i++) {
        final result = cache.get('key1', 1000);
        expect(result.found, true, reason: 'access $i should still be found');
      }

      // 50th access triggers eviction
      final result = cache.get('key1', 1000);
      expect(result.found, false);
    });
  });

  group('global sweep', () {
    test('runs every 50 operations and removes expired entries', () {
      // Insert an entry that will expire
      cache.put('expired', null, 0); // inserted at time 0

      // Fill up with operations to reach 50 (put was 1, need 49 more)
      for (int i = 0; i < 48; i++) {
        cache.put('filler_$i', null, 100000);
      }

      // At this point we have 49 operations. Next operation triggers sweep.
      // The sweep should remove 'expired' (it's way past TTL at time 100000)
      cache.get('trigger', 100000); // 50th operation

      // expired should be gone (swept)
      final result = cache.get('expired', 100000);
      expect(result.found, false);
    });
  });

  group('LRU eviction', () {
    test('evicts least recently used when exceeding 50 entries', () {
      // Fill cache to 50
      for (int i = 0; i < 50; i++) {
        cache.put('key_$i', null, 1000);
      }
      expect(cache.size, 50);

      // Add one more - should evict the least recently used (key_0)
      cache.put('key_50', null, 1000);
      expect(cache.size, 50);

      // key_0 should be evicted
      final result = cache.get('key_0', 1000);
      expect(result.found, false);

      // key_50 should be present
      final result2 = cache.get('key_50', 1000);
      expect(result2.found, true);
    });
  });

  group('branchId change', () {
    test('flushes cache when branchId changes', () {
      cache.put('key1', null, 1000);
      cache.checkBranchId('branch1');

      // Still present
      final before = cache.get('key1', 1000);
      expect(before.found, true);

      // Change branch
      cache.checkBranchId('branch2');

      // Should be flushed
      final after = cache.get('key1', 1000);
      expect(after.found, false);
    });

    test('does not flush when branchId is set for the first time', () {
      cache.put('key1', null, 1000);
      cache.checkBranchId('branch1');

      final result = cache.get('key1', 1000);
      expect(result.found, true);
    });

    test('does not flush when branchId is the same', () {
      cache.put('key1', null, 1000);
      cache.checkBranchId('branch1');
      cache.checkBranchId('branch1');

      final result = cache.get('key1', 1000);
      expect(result.found, true);
    });
  });

  group('flush', () {
    test('removes all entries', () {
      cache.put('key1', null, 1000);
      cache.put('key2', null, 1000);
      expect(cache.size, 2);

      cache.flush();
      expect(cache.size, 0);
    });
  });
}
