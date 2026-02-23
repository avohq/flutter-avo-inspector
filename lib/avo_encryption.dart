import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

/// ECIES encryption implementation for the Flutter Avo Inspector SDK.
///
/// Algorithm: ECIES with P-256 + ECDH + SHA-256 KDF + AES-256-GCM
///
/// Wire format:
///   [0x00 version byte (1B)] [uncompressed ephemeral pubkey (65B)]
///   [IV (16B)] [auth tag (16B)] [ciphertext (variable)]
///
/// Base64 encodes the entire wire format output.
///
/// IMPORTANT: GCMBlockCipher in pointycastle returns ciphertext+authTag
/// concatenated. The LAST 16 bytes are the auth tag (not the first 16 bytes).
class AvoEncryption {
  /// Determines whether encryption should be applied.
  ///
  /// Returns true only when:
  /// - env is NOT "prod"
  /// - publicEncryptionKey is non-null and non-empty
  static bool shouldEncrypt(String envName, String? publicEncryptionKey) {
    if (envName == 'prod') {
      return false;
    }
    return publicEncryptionKey != null && publicEncryptionKey.isNotEmpty;
  }

  /// Encrypts a property value string using ECIES with the given hex-encoded
  /// EC public key.
  ///
  /// On failure, logs a warning and returns null (fail-closed: omit the value
  /// rather than sending it unencrypted).
  ///
  /// [plaintext] the plaintext to encrypt
  /// [publicKeyHex] hex-encoded uncompressed EC public key
  ///   (04 + X + Y, 130 hex chars = 65 bytes)
  ///
  /// Returns Base64-encoded ciphertext in Avo ECIES wire format, or null on failure.
  static String? encryptPropertyValue(String plaintext, String? publicKeyHex) {
    return encrypt(plaintext, publicKeyHex);
  }

  /// Core encrypt method. See [encryptPropertyValue] for documentation.
  static String? encrypt(String plaintext, String? publicKeyHex) {
    try {
      if (publicKeyHex == null || publicKeyHex.isEmpty) {
        return null;
      }

      // Decode hex public key to bytes
      final pubKeyBytes = _hexToBytes(publicKeyHex);
      if (pubKeyBytes.length != 65 || pubKeyBytes[0] != 0x04) {
        debugPrint('[Avo Inspector] Warning: invalid public key format for encryption');
        return null;
      }

      // Reconstruct EC public key from uncompressed point bytes
      final domainParams = ECDomainParameters('prime256v1');
      final xBytes = pubKeyBytes.sublist(1, 33);
      final yBytes = pubKeyBytes.sublist(33, 65);
      final x = _bytesToBigInt(xBytes);
      final y = _bytesToBigInt(yBytes);
      final point = domainParams.curve.createPoint(x, y);
      final recipientPublicKey = ECPublicKey(point, domainParams);

      // Generate ephemeral P-256 key pair
      final ephemeralKeyPair = _generateP256KeyPair();
      final ephemeralPrivateKey = ephemeralKeyPair.privateKey as ECPrivateKey;
      final ephemeralPublicKey = ephemeralKeyPair.publicKey as ECPublicKey;

      // ECDH: compute shared secret
      final ecdh = ECDHBasicAgreement();
      ecdh.init(ephemeralPrivateKey);
      final sharedSecretBigInt = ecdh.calculateAgreement(recipientPublicKey);
      final sharedSecretBytes = _bigIntToBytes32(sharedSecretBigInt);

      // KDF: SHA-256 of shared secret -> AES key
      final sha256 = SHA256Digest();
      final aesKeyBytes = sha256.process(sharedSecretBytes);

      // AES-256-GCM encrypt with 16-byte random IV
      final iv = _generateRandomBytes(16);
      final gcmParams = AEADParameters(
        KeyParameter(aesKeyBytes),
        128, // auth tag size in bits
        iv,
        Uint8List(0), // no AAD
      );

      final gcm = GCMBlockCipher(AESEngine());
      gcm.init(true, gcmParams); // true = encrypt

      final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
      // Allocate output buffer: ciphertext has same size as plaintext + 16 bytes auth tag
      // GCM with 128-bit tag appends 16 bytes of auth tag at the end
      final ciphertextWithTag = Uint8List(plaintextBytes.length + 16);
      var outputLen = gcm.processBytes(plaintextBytes, 0, plaintextBytes.length, ciphertextWithTag, 0);
      outputLen += gcm.doFinal(ciphertextWithTag, outputLen);

      // CRITICAL: GCMBlockCipher returns ciphertext+authTag concatenated.
      // Extract the LAST 16 bytes as the auth tag (not the first 16 bytes).
      final ciphertextLen = ciphertextWithTag.length - 16;
      final ciphertextOnly = ciphertextWithTag.sublist(0, ciphertextLen);
      final authTag = ciphertextWithTag.sublist(ciphertextLen); // last 16 bytes

      // Serialize ephemeral public key as uncompressed: 0x04 + X(32) + Y(32)
      final ephemeralPubBytes = _encodeUncompressedPoint(ephemeralPublicKey);

      // Assemble wire format:
      // [0x00 version (1B)] + [ephemeral pubkey (65B)] + [IV (16B)] + [auth tag (16B)] + [ciphertext]
      final output = Uint8List(1 + 65 + 16 + 16 + ciphertextLen);
      output[0] = 0x00; // version byte
      output.setRange(1, 66, ephemeralPubBytes);
      output.setRange(66, 82, iv);
      output.setRange(82, 98, authTag);
      output.setRange(98, 98 + ciphertextLen, ciphertextOnly);

      return base64Encode(output);
    } catch (e) {
      debugPrint('[Avo Inspector] Warning: encryption failed: $e');
      return null;
    }
  }

  // =========================================================================
  // Private helpers
  // =========================================================================

  /// Generates a P-256 EC key pair using a cryptographically secure random source.
  static AsymmetricKeyPair<PublicKey, PrivateKey> _generateP256KeyPair() {
    final domainParams = ECDomainParameters('prime256v1');
    final keyParams = ECKeyGeneratorParameters(domainParams);
    final secureRandom = _buildSecureRandom();

    final generator = ECKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, secureRandom));
    return generator.generateKeyPair();
  }

  /// Builds a seeded FortunaRandom PRNG using platform random bytes.
  static SecureRandom _buildSecureRandom() {
    final secureRandom = FortunaRandom();
    final seed = _getDartSecureRandomBytes(32);
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  /// Generates cryptographically random bytes using a FortunaRandom seeded
  /// from Dart's Random.secure().
  static Uint8List _generateRandomBytes(int length) {
    final seed = _getDartSecureRandomBytes(32);
    final rng = FortunaRandom();
    rng.seed(KeyParameter(seed));
    return rng.nextBytes(length);
  }

  /// Gets random bytes from Dart's Random.secure().
  static Uint8List _getDartSecureRandomBytes(int length) {
    final r = math.Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
  }

  /// Encodes an EC public key as an uncompressed point: 0x04 + X(32) + Y(32).
  static Uint8List _encodeUncompressedPoint(ECPublicKey publicKey) {
    final point = publicKey.Q!;
    final xBytes = _bigIntToBytes32(point.x!.toBigInteger()!);
    final yBytes = _bigIntToBytes32(point.y!.toBigInteger()!);
    final result = Uint8List(65);
    result[0] = 0x04;
    result.setRange(1, 33, xBytes);
    result.setRange(33, 65, yBytes);
    return result;
  }

  /// Converts a hex string to a byte array.
  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw ArgumentError('Hex string must have even length');
    }
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Converts a BigInt to an unsigned 32-byte array (big-endian, zero-padded).
  static Uint8List _bigIntToBytes32(BigInt value) {
    final hex = value.toRadixString(16).padLeft(64, '0');
    final result = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// Converts a byte array to a BigInt (big-endian unsigned).
  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}
