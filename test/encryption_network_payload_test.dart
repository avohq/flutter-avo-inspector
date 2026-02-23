// Tests for encryption integration in AvoNetworkCallsHandler payload building.
import 'dart:convert';
import 'dart:typed_data';

import 'package:avo_inspector/avo_encryption.dart';
import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  // =========================================================================
  // shouldEncrypt helper tests (already in avo_encryption_test.dart but
  // repeated here for network-layer context)
  // =========================================================================

  group('encryptPropertyValue', () {
    late AsymmetricKeyPair<PublicKey, PrivateKey> keyPair;
    late String publicKeyHex;

    setUp(() {
      keyPair = _generateP256KeyPair();
      publicKeyHex = _ecPublicKeyToHex(keyPair.publicKey as ECPublicKey);
    });

    test('encrypts a string value', () {
      final result = AvoEncryption.encryptPropertyValue('"hello"', publicKeyHex);
      expect(result, isNotNull);
    });

    test('encrypted value decodes to valid wire format', () {
      final result = AvoEncryption.encryptPropertyValue('"hello"', publicKeyHex);
      expect(result, isNotNull);
      final decoded = base64Decode(result!);
      expect(decoded.length, greaterThanOrEqualTo(99));
      expect(decoded[0], equals(0x00));
      expect(decoded[1], equals(0x04));
    });

    test('returns null on failure (invalid key)', () {
      final result = AvoEncryption.encryptPropertyValue('"hello"', 'invalid_key');
      expect(result, isNull);
    });
  });

  // =========================================================================
  // Prod env negative test: no encryption in prod
  // =========================================================================
  group('prod env - no encryption', () {
    test('shouldEncrypt returns false for prod env with key', () {
      expect(AvoEncryption.shouldEncrypt('prod', 'somevalidhexkey'), isFalse);
    });

    test('payload in prod env has no encryptedPropertyValue fields', () {
      final keyPair = _generateP256KeyPair();
      final publicKeyHex = _ecPublicKeyToHex(keyPair.publicKey as ECPublicKey);

      final handler = AvoNetworkCallsHandler(
        apiKey: 'test-api-key',
        envName: 'prod',
        appName: 'TestApp',
        appVersion: '1.0',
        libVersion: '1.0',
        publicEncryptionKey: publicKeyHex,
      );

      final schema = [
        {'propertyName': 'testProp', 'propertyType': 'string'},
      ];

      final body = handler.bodyForEventSchemaCall(
        eventName: 'testEvent',
        eventSchema: schema,
        anonymousId: 'anon-123',
      );

      final json = body.toJson();
      final eventProperties = json['eventProperties'] as List;
      for (final prop in eventProperties) {
        final propMap = prop as Map<String, dynamic>;
        expect(propMap.containsKey('encryptedPropertyValue'), isFalse,
            reason: 'Prod env should not encrypt properties');
      }
    });
  });

  // =========================================================================
  // Dev env with key: encryption applied
  // =========================================================================
  group('dev env with encryption key', () {
    late AsymmetricKeyPair<PublicKey, PrivateKey> keyPair;
    late String publicKeyHex;

    setUp(() {
      keyPair = _generateP256KeyPair();
      publicKeyHex = _ecPublicKeyToHex(keyPair.publicKey as ECPublicKey);
    });

    test('string property value is encrypted in dev env', () {
      final handler = AvoNetworkCallsHandler(
        apiKey: 'test-api-key',
        envName: 'dev',
        appName: 'TestApp',
        appVersion: '1.0',
        libVersion: '1.0',
        publicEncryptionKey: publicKeyHex,
      );

      // Schema with a known property value (note: propertyValue is the actual
      // value for encryption; the schema format uses propertyType for the type)
      // Based on the story requirements: encrypt the *value* part of the property
      final schema = [
        {'propertyName': 'userId', 'propertyType': 'string', 'propertyValue': 'alice@example.com'},
      ];

      final body = handler.bodyForEventSchemaCall(
        eventName: 'testEvent',
        eventSchema: schema,
        anonymousId: 'anon-123',
      );

      final json = body.toJson();
      final eventProperties = json['eventProperties'] as List;

      // At least one property should have encryptedPropertyValue
      bool found = false;
      for (final prop in eventProperties) {
        final propMap = prop as Map<String, dynamic>;
        if (propMap.containsKey('encryptedPropertyValue')) {
          found = true;
          final encrypted = propMap['encryptedPropertyValue'] as String;
          final decoded = base64Decode(encrypted);
          expect(decoded.length, greaterThanOrEqualTo(99));
          expect(decoded[0], equals(0x00));
        }
      }
      expect(found, isTrue, reason: 'Expected at least one encrypted property');
    });

    test('list-type properties are omitted entirely in dev env with key', () {
      final handler = AvoNetworkCallsHandler(
        apiKey: 'test-api-key',
        envName: 'dev',
        appName: 'TestApp',
        appVersion: '1.0',
        libVersion: '1.0',
        publicEncryptionKey: publicKeyHex,
      );

      final schema = [
        {'propertyName': 'tags', 'propertyType': 'list', 'propertyValue': ['a', 'b']},
        {'propertyName': 'name', 'propertyType': 'string', 'propertyValue': 'test'},
      ];

      final body = handler.bodyForEventSchemaCall(
        eventName: 'testEvent',
        eventSchema: schema,
        anonymousId: 'anon-123',
      );

      final json = body.toJson();
      final eventProperties = json['eventProperties'] as List;

      // 'tags' (list type) should be omitted
      final names = eventProperties.map((p) => (p as Map)['propertyName']).toList();
      expect(names, isNot(contains('tags')),
          reason: 'List-type properties should be omitted entirely');
    });

    test('publicEncryptionKey included in base body when non-null and non-empty', () {
      final handler = AvoNetworkCallsHandler(
        apiKey: 'test-api-key',
        envName: 'dev',
        appName: 'TestApp',
        appVersion: '1.0',
        libVersion: '1.0',
        publicEncryptionKey: publicKeyHex,
      );

      final body = handler.bodyForEventSchemaCall(
        eventName: 'testEvent',
        eventSchema: [],
        anonymousId: 'anon-123',
      );

      final json = body.toJson();
      expect(json.containsKey('publicEncryptionKey'), isTrue,
          reason: 'publicEncryptionKey should be in base body when set');
      expect(json['publicEncryptionKey'], equals(publicKeyHex));
    });

    test('publicEncryptionKey not included when null', () {
      final handler = AvoNetworkCallsHandler(
        apiKey: 'test-api-key',
        envName: 'dev',
        appName: 'TestApp',
        appVersion: '1.0',
        libVersion: '1.0',
        publicEncryptionKey: null,
      );

      final body = handler.bodyForEventSchemaCall(
        eventName: 'testEvent',
        eventSchema: [],
        anonymousId: 'anon-123',
      );

      final json = body.toJson();
      expect(json.containsKey('publicEncryptionKey'), isFalse,
          reason: 'publicEncryptionKey should not be in base body when null');
    });

    test('publicEncryptionKey not included when empty', () {
      final handler = AvoNetworkCallsHandler(
        apiKey: 'test-api-key',
        envName: 'dev',
        appName: 'TestApp',
        appVersion: '1.0',
        libVersion: '1.0',
        publicEncryptionKey: '',
      );

      final body = handler.bodyForEventSchemaCall(
        eventName: 'testEvent',
        eventSchema: [],
        anonymousId: 'anon-123',
      );

      final json = body.toJson();
      expect(json.containsKey('publicEncryptionKey'), isFalse,
          reason: 'publicEncryptionKey should not be in base body when empty');
    });
  });

  // =========================================================================
  // Dev env without key: no encryption
  // =========================================================================
  group('dev env without encryption key', () {
    test('no encryptedPropertyValue without key', () {
      final handler = AvoNetworkCallsHandler(
        apiKey: 'test-api-key',
        envName: 'dev',
        appName: 'TestApp',
        appVersion: '1.0',
        libVersion: '1.0',
        publicEncryptionKey: null,
      );

      final schema = [
        {'propertyName': 'userId', 'propertyType': 'string', 'propertyValue': 'alice'},
      ];

      final body = handler.bodyForEventSchemaCall(
        eventName: 'testEvent',
        eventSchema: schema,
        anonymousId: 'anon-123',
      );

      final json = body.toJson();
      final eventProperties = json['eventProperties'] as List;
      for (final prop in eventProperties) {
        final propMap = prop as Map<String, dynamic>;
        expect(propMap.containsKey('encryptedPropertyValue'), isFalse);
      }
    });
  });
}

// =========================================================================
// Test helpers (duplicated from avo_encryption_test.dart for isolation)
// =========================================================================

AsymmetricKeyPair<PublicKey, PrivateKey> _generateP256KeyPair() {
  final domainParams = ECDomainParameters('prime256v1');
  final keyParams = ECKeyGeneratorParameters(domainParams);
  final secureRandom = FortunaRandom();

  final seed = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    seed[i] = i + 1;
  }
  secureRandom.seed(KeyParameter(seed));

  final generator = ECKeyGenerator();
  generator.init(ParametersWithRandom(keyParams, secureRandom));
  return generator.generateKeyPair();
}

String _ecPublicKeyToHex(ECPublicKey publicKey) {
  final point = publicKey.Q!;
  final xBytes = _bigIntToBytes32(point.x!.toBigInteger()!);
  final yBytes = _bigIntToBytes32(point.y!.toBigInteger()!);
  final buffer = Uint8List(65);
  buffer[0] = 0x04;
  buffer.setRange(1, 33, xBytes);
  buffer.setRange(33, 65, yBytes);
  return buffer.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List _bigIntToBytes32(BigInt value) {
  final hex = value.toRadixString(16).padLeft(64, '0');
  final result = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
