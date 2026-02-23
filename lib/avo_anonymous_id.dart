import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Minimal interface for the SharedPreferences operations used by [AvoAnonymousId].
/// Exposed so tests can inject fakes without depending on the concrete class.
abstract class AvoPrefsStorage {
  String? getString(String key);
  Future<bool> setString(String key, String value);
}

/// Default implementation that delegates to the real [SharedPreferences].
class _RealPrefsStorage implements AvoPrefsStorage {
  final SharedPreferences _prefs;
  _RealPrefsStorage(this._prefs);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
}

/// Manages a persistent anonymous UUID stored under [storageKey] in
/// SharedPreferences.
///
/// The first call to [getAnonymousId] reads from storage (or generates a new
/// UUID). Concurrent callers before the first read completes all receive the
/// same value via an in-flight [Completer].
class AvoAnonymousId {
  static const storageKey = 'AvoInspectorAnonymousId';

  /// Optional override for obtaining the storage instance.
  /// Exposed for testing.
  final Future<AvoPrefsStorage> Function()? _storageFactory;

  AvoAnonymousId({Future<AvoPrefsStorage> Function()? storageFactory})
      : _storageFactory = storageFactory;

  String? _cachedId;
  Completer<String>? _inflightCompleter;

  Future<AvoPrefsStorage> _getStorage() async {
    if (_storageFactory != null) {
      return _storageFactory!();
    }
    final prefs = await SharedPreferences.getInstance();
    return _RealPrefsStorage(prefs);
  }

  /// Returns the anonymous ID, reading from SharedPreferences on first call.
  /// Concurrent calls before the first call completes all receive the same UUID.
  Future<String> getAnonymousId() async {
    // Return cached value immediately if already resolved.
    if (_cachedId != null) {
      return _cachedId!;
    }

    // If there is already an in-flight resolution, piggyback on it.
    if (_inflightCompleter != null) {
      return _inflightCompleter!.future;
    }

    // We are the first caller — create the Completer so concurrent callers wait.
    final completer = Completer<String>();
    _inflightCompleter = completer;

    try {
      final storage = await _getStorage();

      final stored = storage.getString(storageKey);
      if (stored != null) {
        _cachedId = stored;
        completer.complete(stored);
        return stored;
      }

      // Generate a new UUID and persist it.
      final newId = const Uuid().v4();
      _cachedId = newId;

      try {
        await storage.setString(storageKey, newId);
      } catch (e) {
        debugPrint(
            '[Avo Inspector] Warning: failed to persist anonymous ID: $e');
      }

      completer.complete(newId);
      return newId;
    } catch (e) {
      debugPrint('[Avo Inspector] Warning: failed to read anonymous ID: $e');
      const fallback = 'unknown';
      _cachedId = fallback;
      completer.complete(fallback);
      return fallback;
    } finally {
      _inflightCompleter = null;
    }
  }
}
