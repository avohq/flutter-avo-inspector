import 'dart:convert';
import 'dart:typed_data';

import 'package:avo_inspector/avo_encryption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  // =========================================================================
  // shouldEncrypt() truth table
  // =========================================================================
  group('shouldEncrypt truth table', () {
    test('dev + valid key => true', () {
      expect(AvoEncryption.shouldEncrypt('dev', 'abc123'), isTrue);
    });

    test('staging + valid key => true', () {
      expect(AvoEncryption.shouldEncrypt('staging', 'abc123'), isTrue);
    });

    test('prod + valid key => false', () {
      expect(AvoEncryption.shouldEncrypt('prod', 'abc123'), isFalse);
    });

    test('dev + null key => false', () {
      expect(AvoEncryption.shouldEncrypt('dev', null), isFalse);
    });

    test('dev + empty key => false', () {
      expect(AvoEncryption.shouldEncrypt('dev', ''), isFalse);
    });

    test('staging + null key => false', () {
      expect(AvoEncryption.shouldEncrypt('staging', null), isFalse);
    });

    test('staging + empty key => false', () {
      expect(AvoEncryption.shouldEncrypt('staging', ''), isFalse);
    });

    test('prod + null key => false', () {
      expect(AvoEncryption.shouldEncrypt('prod', null), isFalse);
    });
  });

  // =========================================================================
  // Wire format structural tests
  // =========================================================================
  group('encrypt wire format', () {
    late AsymmetricKeyPair<PublicKey, PrivateKey> keyPair;
    late String publicKeyHex;

    setUp(() {
      keyPair = _generateP256KeyPair();
      publicKeyHex = _ecPublicKeyToHex(keyPair.publicKey as ECPublicKey);
    });

    test('output is non-null for valid key', () {
      final result = AvoEncryption.encrypt('"hello"', publicKeyHex);
      expect(result, isNotNull);
    });

    test('output decodes to at least 99 bytes', () {
      final result = AvoEncryption.encrypt('"hello"', publicKeyHex);
      expect(result, isNotNull);
      final decoded = base64Decode(result!);
      expect(decoded.length, greaterThanOrEqualTo(99));
    });

    test('first byte is 0x00 (version byte)', () {
      final result = AvoEncryption.encrypt('"hello"', publicKeyHex);
      expect(result, isNotNull);
      final decoded = base64Decode(result!);
      expect(decoded[0], equals(0x00));
    });

    test('second byte is 0x04 (uncompressed EC point marker)', () {
      final result = AvoEncryption.encrypt('"hello"', publicKeyHex);
      expect(result, isNotNull);
      final decoded = base64Decode(result!);
      expect(decoded[1], equals(0x04));
    });

    test('different calls produce different output (random IV)', () {
      final result1 = AvoEncryption.encrypt('"hello"', publicKeyHex);
      final result2 = AvoEncryption.encrypt('"hello"', publicKeyHex);
      expect(result1, isNotNull);
      expect(result2, isNotNull);
      expect(result1, isNot(equals(result2)));
    });

    test('returns null for null key', () {
      final result = AvoEncryption.encrypt('"hello"', null);
      expect(result, isNull);
    });

    test('returns null for empty key', () {
      final result = AvoEncryption.encrypt('"hello"', '');
      expect(result, isNull);
    });

    test('returns null for invalid key (not 65 bytes)', () {
      final result = AvoEncryption.encrypt('"hello"', 'deadbeef');
      expect(result, isNull);
    });
  });

  // =========================================================================
  // Encryption round-trip test (encrypt then decrypt in Dart)
  // =========================================================================
  group('encrypt/decrypt round-trip', () {
    late AsymmetricKeyPair<PublicKey, PrivateKey> keyPair;
    late String publicKeyHex;

    setUp(() {
      keyPair = _generateP256KeyPair();
      publicKeyHex = _ecPublicKeyToHex(keyPair.publicKey as ECPublicKey);
    });

    test('round-trip decryption returns original plaintext', () {
      const plaintext = '"hello world"';
      final encrypted = AvoEncryption.encrypt(plaintext, publicKeyHex);
      expect(encrypted, isNotNull);

      final decrypted = _dartDecrypt(encrypted!, keyPair.privateKey as ECPrivateKey);
      expect(decrypted, equals(plaintext));
    });

    test('round-trip with numeric value', () {
      const plaintext = '42';
      final encrypted = AvoEncryption.encrypt(plaintext, publicKeyHex);
      expect(encrypted, isNotNull);
      final decrypted = _dartDecrypt(encrypted!, keyPair.privateKey as ECPrivateKey);
      expect(decrypted, equals(plaintext));
    });

    test('round-trip with boolean value', () {
      const plaintext = 'true';
      final encrypted = AvoEncryption.encrypt(plaintext, publicKeyHex);
      expect(encrypted, isNotNull);
      final decrypted = _dartDecrypt(encrypted!, keyPair.privateKey as ECPrivateKey);
      expect(decrypted, equals(plaintext));
    });

    test('round-trip with float value', () {
      const plaintext = '3.14';
      final encrypted = AvoEncryption.encrypt(plaintext, publicKeyHex);
      expect(encrypted, isNotNull);
      final decrypted = _dartDecrypt(encrypted!, keyPair.privateKey as ECPrivateKey);
      expect(decrypted, equals(plaintext));
    });

    test('round-trip with test string value', () {
      const plaintext = '"test string value"';
      final encrypted = AvoEncryption.encrypt(plaintext, publicKeyHex);
      expect(encrypted, isNotNull);
      final decrypted = _dartDecrypt(encrypted!, keyPair.privateKey as ECPrivateKey);
      expect(decrypted, equals(plaintext));
    });
  });

  // =========================================================================
  // Wire format layout verification
  // =========================================================================
  group('wire format layout', () {
    test('layout: version(1) + ephemeral pubkey(65) + IV(16) + authTag(16) + ciphertext', () {
      final keyPair = _generateP256KeyPair();
      final publicKeyHex = _ecPublicKeyToHex(keyPair.publicKey as ECPublicKey);

      // Encrypt a 1-byte plaintext (UTF-8 of "x" = 1 byte)
      final encrypted = AvoEncryption.encrypt('x', publicKeyHex);
      expect(encrypted, isNotNull);

      final decoded = base64Decode(encrypted!);
      // 1 + 65 + 16 + 16 + at least 1 = 99 min
      expect(decoded.length, greaterThanOrEqualTo(99));

      // Verify version byte
      expect(decoded[0], equals(0x00));

      // Verify ephemeral pubkey starts with 0x04
      expect(decoded[1], equals(0x04));

      // Ephemeral pubkey has 65 bytes: index 1..65
      // IV at index 66..81
      // AuthTag at index 82..97
      // Ciphertext at index 98+
      expect(decoded.length, greaterThanOrEqualTo(99));
    });
  });
}

// =========================================================================
// Test helpers
// =========================================================================

/// Generate a P-256 EC key pair using pointycastle.
AsymmetricKeyPair<PublicKey, PrivateKey> _generateP256KeyPair() {
  final domainParams = ECDomainParameters('prime256v1');
  final keyParams = ECKeyGeneratorParameters(domainParams);
  final secureRandom = FortunaRandom();

  // Seed the PRNG
  final seed = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    seed[i] = i + 1;
  }
  secureRandom.seed(KeyParameter(seed));

  final generator = ECKeyGenerator();
  generator.init(ParametersWithRandom(keyParams, secureRandom));
  return generator.generateKeyPair();
}

/// Convert ECPublicKey to hex-encoded uncompressed point (04 + X + Y).
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

/// Convert a BigInt to an unsigned 32-byte array (big-endian, zero-padded).
Uint8List _bigIntToBytes32(BigInt value) {
  final hex = value.toRadixString(16).padLeft(64, '0');
  final result = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

/// Decrypt an Avo ECIES wire format ciphertext using Dart/pointycastle.
/// This mirrors the Java EncryptionInteropTestUtil.decrypt() logic.
String _dartDecrypt(String base64Encrypted, ECPrivateKey privateKey) {
  final data = base64Decode(base64Encrypted);

  if (data.length < 99) {
    throw ArgumentError('Encrypted data too short: ${data.length}');
  }
  if (data[0] != 0x00) {
    throw ArgumentError('Unsupported version byte: 0x${data[0].toRadixString(16)}');
  }

  // Extract ephemeral public key bytes [1..65]
  final ephemeralPubKeyBytes = data.sublist(1, 66);
  // Extract IV [66..81]
  final iv = data.sublist(66, 82);
  // Extract auth tag [82..97]
  final authTag = data.sublist(82, 98);
  // Extract ciphertext [98..N]
  final ciphertext = data.sublist(98);

  // Reconstruct ephemeral public key
  final domainParams = ECDomainParameters('prime256v1');
  final xBytes = ephemeralPubKeyBytes.sublist(1, 33);
  final yBytes = ephemeralPubKeyBytes.sublist(33, 65);
  final x = _bytesToBigInt(xBytes);
  final y = _bytesToBigInt(yBytes);
  final point = domainParams.curve.createPoint(x, y);
  final ephemeralPubKey = ECPublicKey(point, domainParams);

  // ECDH: shared secret
  final ecdh = ECDHBasicAgreement();
  ecdh.init(privateKey);
  final sharedSecret = ecdh.calculateAgreement(ephemeralPubKey);
  final sharedSecretBytes = _bigIntToBytes32(sharedSecret);

  // KDF: SHA-256(sharedSecret)
  final sha256 = SHA256Digest();
  final aesKeyBytes = sha256.process(sharedSecretBytes);

  // AES-256-GCM decrypt
  // Reassemble ciphertext + authTag for GCM
  final ciphertextWithTag = Uint8List(ciphertext.length + 16);
  ciphertextWithTag.setRange(0, ciphertext.length, ciphertext);
  ciphertextWithTag.setRange(ciphertext.length, ciphertext.length + 16, authTag);

  final gcmParams = AEADParameters(
    KeyParameter(aesKeyBytes),
    128, // auth tag bits
    iv,
    Uint8List(0), // no AAD
  );

  final gcm = GCMBlockCipher(AESEngine());
  gcm.init(false, gcmParams); // false = decrypt

  // Allocate output buffer: plaintext is ciphertextWithTag minus 16 bytes auth tag
  final plainBytes = Uint8List(ciphertextWithTag.length - 16);
  var outputLen = gcm.processBytes(ciphertextWithTag, 0, ciphertextWithTag.length, plainBytes, 0);
  outputLen += gcm.doFinal(plainBytes, outputLen);
  return utf8.decode(plainBytes.sublist(0, outputLen));
}

BigInt _bytesToBigInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}
