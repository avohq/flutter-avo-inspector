import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' show Client;
import 'package:uuid/uuid.dart';

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
  });

  Map<String, dynamic> toJson() {
    return {
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
      'samplingRate': samplingRate
    };
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
        samplingRate = json['samplingRate'];
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
  }) : super(
            apiKey: apiKey,
            appName: appName,
            appVersion: appVersion,
            libVersion: libVersion,
            env: env,
            messageId: messageId,
            anonymousId: anonymousId,
            createdAt: createdAt,
            samplingRate: samplingRate);

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
  double samplingRate = 1.0;
  Client client = Client();

  bool _sending = false;

  Uri _trackingEndpoint = Uri.parse("https://api.avo.app/inspector/v1/track");

  AvoNetworkCallsHandler(
      {required this.apiKey,
      required this.envName,
      required this.appName,
      required this.appVersion,
      required this.libVersion});

  EventSchemaBody bodyForEventSchemaCall(
      {required String eventName,
      required List<Map<String, dynamic>> eventSchema,
      required String anonymousId}) {
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
        eventSchema: eventSchema);
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
