import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' show Client;
import 'package:uuid/uuid.dart';

import 'package:avo_inspector/avo_encryption.dart';
import 'package:avo_inspector/avo_inspector.dart';

abstract class BaseBody {
  String type = "base";
  String apiKey;
  String appName;
  String appVersion;
  String libVersion;
  String env;
  final String libPlatform = "flutter";
  String messageId;
  String anonymousId;
  String createdAt;
  double samplingRate;
  String? publicEncryptionKey;

  BaseBody({
    required this.apiKey,
    required this.appName,
    required this.appVersion,
    required this.libVersion,
    required this.env,
    required this.messageId,
    required this.anonymousId,
    required this.createdAt,
    required this.samplingRate,
    this.publicEncryptionKey,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'apiKey': apiKey,
      'appName': appName,
      'appVersion': appVersion,
      'libVersion': libVersion,
      'env': env,
      'libPlatform': libPlatform,
      'messageId': messageId,
      'anonymousId': anonymousId,
      'createdAt': createdAt,
      'samplingRate': samplingRate,
    };
    // Include publicEncryptionKey only when non-null and non-empty
    if (publicEncryptionKey != null && publicEncryptionKey!.isNotEmpty) {
      map['publicEncryptionKey'] = publicEncryptionKey;
    }
    return map;
  }

  BaseBody.fromJson(Map<String, dynamic> json)
      : apiKey = json['apiKey'],
        appName = json['appName'],
        appVersion = json['appVersion'],
        libVersion = json['libVersion'],
        env = json['env'],
        messageId = json['messageId'],
        anonymousId = json['anonymousId'] ?? json['trackingId'] ?? '',
        createdAt = json['createdAt'],
        samplingRate = json['samplingRate'],
        publicEncryptionKey = json['publicEncryptionKey'];
}

class EventSchemaBody extends BaseBody {
  final String type = "event";

  final String eventName;
  final List<Map<String, dynamic>> eventSchema;

  EventSchemaBody({
    required apiKey,
    required appName,
    required appVersion,
    required libVersion,
    required env,
    required messageId,
    required anonymousId,
    required createdAt,
    required samplingRate,
    required this.eventName,
    required this.eventSchema,
    String? publicEncryptionKey,
  }) : super(
            apiKey: apiKey,
            appName: appName,
            appVersion: appVersion,
            libVersion: libVersion,
            env: env,
            messageId: messageId,
            anonymousId: anonymousId,
            createdAt: createdAt,
            samplingRate: samplingRate,
            publicEncryptionKey: publicEncryptionKey);

  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        'eventName': eventName,
        'eventProperties': eventSchema,
        'samplingRate': samplingRate
      });
  }

  EventSchemaBody.fromJson(Map<String, dynamic> json)
      : eventName = json["eventName"],
        eventSchema =
            (json["eventProperties"] as List).cast<Map<String, dynamic>>(),
        super.fromJson(json);
}

class AvoNetworkCallsHandler {
  String apiKey;
  String envName;
  String appName;
  String appVersion;
  String libVersion;
  String? publicEncryptionKey;
  double samplingRate = 1.0;
  Client client = Client();

  bool _sending = false;

  Uri _trackingEndpoint = Uri.parse("https://api.avo.app/inspector/v1/track");

  AvoNetworkCallsHandler(
      {required this.apiKey,
      required this.envName,
      required this.appName,
      required this.appVersion,
      required this.libVersion,
      this.publicEncryptionKey});

  /// Builds an [EventSchemaBody] for the given event, applying ECIES encryption
  /// to property values when:
  ///   - env is dev or staging
  ///   - publicEncryptionKey is non-null and non-empty
  ///
  /// For list-type properties, the property is omitted entirely (not encrypted,
  /// not sent unencrypted).
  ///
  /// On encryption failure the property is omitted and a warning is logged.
  EventSchemaBody bodyForEventSchemaCall(
      {required String eventName,
      required List<Map<String, dynamic>> eventSchema,
      required String anonymousId}) {
    final shouldEncrypt =
        AvoEncryption.shouldEncrypt(envName, publicEncryptionKey);

    final processedSchema = shouldEncrypt
        ? _applyEncryption(eventSchema)
        : eventSchema;

    return EventSchemaBody(
        apiKey: this.apiKey,
        appName: this.appName,
        appVersion: this.appVersion,
        libVersion: this.libVersion,
        env: this.envName,
        messageId: Uuid().v1(),
        anonymousId: anonymousId,
        createdAt: DateTime.now().toIso8601String() + "Z",
        eventName: eventName,
        samplingRate: samplingRate,
        eventSchema: processedSchema,
        publicEncryptionKey: publicEncryptionKey);
  }

  /// Processes an event schema for encryption.
  ///
  /// - List-type properties are omitted entirely.
  /// - For other properties with a propertyValue field, the value is encrypted.
  /// - On encryption failure the property is omitted (fail-closed).
  List<Map<String, dynamic>> _applyEncryption(
      List<Map<String, dynamic>> schema) {
    final result = <Map<String, dynamic>>[];

    for (final prop in schema) {
      final propertyType = prop['propertyType'] as String?;

      // List-type properties are omitted entirely (per acceptance criteria).
      if (propertyType == 'list') {
        continue;
      }

      // If the property has a propertyValue, try to encrypt it.
      if (prop.containsKey('propertyValue')) {
        final propertyValue = prop['propertyValue'];
        final plaintextJson = _toJsonString(propertyValue);

        if (plaintextJson != null) {
          final encrypted = AvoEncryption.encryptPropertyValue(
              plaintextJson, publicEncryptionKey);

          if (encrypted != null) {
            // Replace propertyValue with encryptedPropertyValue
            final encryptedProp = Map<String, dynamic>.from(prop);
            encryptedProp.remove('propertyValue');
            encryptedProp['encryptedPropertyValue'] = encrypted;
            result.add(encryptedProp);
          } else {
            // Encryption failed — omit property entirely (fail-closed).
            // Warning already logged by AvoEncryption.encrypt().
          }
        } else {
          // Cannot serialize value — omit property (fail-closed).
        }
      } else {
        // No propertyValue field — include as-is (type-only schema entry).
        result.add(prop);
      }
    }

    return result;
  }

  /// Converts a Dart value to its JSON string representation.
  ///
  /// Returns null if the value cannot be serialized.
  String? _toJsonString(dynamic value) {
    try {
      return json.encode(value);
    } catch (e) {
      return null;
    }
  }

  Future<void> callInspectorWith(
      {required List<BaseBody> events,
      void Function(String?)? onCompleted}) async {
    if (_sending) {
      onCompleted?.call(
          "Batch sending cancelled because another batch sending is in progress. Your events will be sent with next batch.");
      return;
    }

    if (Random().nextDouble() > samplingRate) {
      if (AvoInspector.shouldLog) {
        print("Avo Inspector: last event schema dropped due to sampling rate.");
      }
      return;
    }

    if (AvoInspector.shouldLog) {
      print("Avo Inspector: events $events");
    }

    final listOfEventMaps = events.map((e) => e.toJson()).toList();

    final body = json.encode(listOfEventMaps);

    _sending = true;
    await client
        .post(_trackingEndpoint,
            headers: {"Content-Type": "text/plain"}, body: body)
        .then((response) {
      if (response.statusCode == 200) {
        final body = response.body;
        samplingRate = (json.decode(body)["samplingRate"] + .0);
        _sending = false;
        onCompleted?.call(null);
      } else {
        onCompleted?.call("${response.body} ${response.statusCode}");
      }
    }).onError((error, stackTrace) {
      _sending = false;
      onCompleted?.call(error.toString());
    });
  }
}
