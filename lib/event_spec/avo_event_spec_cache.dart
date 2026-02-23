import 'package:avo_inspector/event_spec/avo_event_spec_fetch_types.dart';

/// Represents a cache lookup result.
class CacheLookupResult {
  final bool found;
  final EventSpecResponse? response;

  CacheLookupResult({required this.found, this.response});
}

class _CacheEntry {
  final EventSpecResponse? response;
  final int insertedAtMs;
  int accessCount;

  _CacheEntry({required this.response, required this.insertedAtMs})
      : accessCount = 0;
}

/// LRU cache with TTL for event spec responses.
///
/// Key format: apiKey:streamId:eventName
/// TTL: 60 seconds per entry
/// Max entries: 50 (LRU eviction when over)
/// Per-entry eviction: after 50 accesses
/// Global sweep: every 50 operations
/// Stores null responses (prevent re-fetch for unknown events)
/// Flushes all entries when branchId changes
class EventSpecCache {
  static const int maxEntries = 50;
  static const int ttlMs = 60000;
  static const int perEntryAccessLimit = 50;
  static const int globalSweepInterval = 50;

  int _globalEventCount = 0;
  String? _currentBranchId;

  // Using a LinkedHashMap-like structure with access-order for LRU.
  // Dart's LinkedHashMap maintains insertion order. We simulate LRU
  // by removing and re-inserting on access.
  final Map<String, _CacheEntry> _cache = {};

  /// Build a cache key from components.
  static String buildKey(String apiKey, String streamId, String eventName) {
    return '$apiKey:$streamId:$eventName';
  }

  /// Get a cached entry. Returns a CacheLookupResult indicating whether the
  /// key was found. A found result with null response means the event is known
  /// to be unknown (null was cached).
  CacheLookupResult get(String key, int nowMs) {
    _incrementGlobalCount(nowMs);

    final entry = _cache[key];
    if (entry == null) {
      return CacheLookupResult(found: false);
    }

    // TTL check
    if (nowMs - entry.insertedAtMs > ttlMs) {
      _cache.remove(key);
      return CacheLookupResult(found: false);
    }

    // Per-entry access limit check
    entry.accessCount++;
    if (entry.accessCount >= perEntryAccessLimit) {
      _cache.remove(key);
      return CacheLookupResult(found: false);
    }

    // Move to end for LRU (remove and re-insert)
    _cache.remove(key);
    _cache[key] = entry;

    return CacheLookupResult(found: true, response: entry.response);
  }

  /// Put an entry into the cache. Response may be null (for unknown events).
  void put(String key, EventSpecResponse? response, int nowMs) {
    _incrementGlobalCount(nowMs);

    _cache[key] = _CacheEntry(response: response, insertedAtMs: nowMs);

    // LRU eviction if over capacity
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Check and update branchId. If branchId changes, flush the cache.
  void checkBranchId(String? branchId) {
    if (_currentBranchId != null &&
        branchId != null &&
        _currentBranchId != branchId) {
      _cache.clear();
    }
    _currentBranchId = branchId;
  }

  /// Flush all entries from the cache.
  void flush() {
    _cache.clear();
  }

  /// Returns the number of entries in the cache.
  int get size => _cache.length;

  /// Returns the current global event count (for testing).
  int get globalEventCount => _globalEventCount;

  void _incrementGlobalCount(int nowMs) {
    _globalEventCount++;
    if (_globalEventCount % globalSweepInterval == 0) {
      _sweep(nowMs);
    }
  }

  /// Remove entries older than TTL or with too many accesses.
  void _sweep(int nowMs) {
    _cache.removeWhere((key, entry) {
      return (nowMs - entry.insertedAtMs > ttlMs) ||
          (entry.accessCount >= perEntryAccessLimit);
    });
  }
}
