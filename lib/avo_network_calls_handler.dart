import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:avo_inspector/avo_inspector.dart';
import 'package:uuid/uuid.dart';

abstract class BaseBody {
  String type = "base";
  String apiKey;
  String appName;
  String appVersion;
  String libVersion;
  String env;
  final String libPlatform = "flutter";
  String messageId;
  String trackingId;
  String createdAt;
  String sessionId;

  BaseBody({
    required this.apiKey,
    required this.appName,
    required this.appVersion,
    required this.libVersion,
    required this.env,
    required this.messageId,
    required this.trackingId,
    required this.createdAt,
    required this.sessionId,
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
      'trackingId': trackingId,
      'createdAt': createdAt,
      'sessionId': sessionId
    };
  }
}

class SessionStartedBody extends BaseBody {
  final String type = "sessionStarted";

  SessionStartedBody({
    required apiKey,
    required appName,
    required appVersion,
    required libVersion,
    required env,
    required messageId,
    required trackingId,
    required createdAt,
    required sessionId,
  }) : super(
            apiKey: apiKey,
            appName: appName,
            appVersion: appVersion,
            libVersion: libVersion,
            env: env,
            messageId: messageId,
            trackingId: trackingId,
            createdAt: createdAt,
            sessionId: sessionId);
}

class AvoNetworkCallsHandler {
  String apiKey;
  String envName;
  String appName;
  String appVersion;
  String libVersion;

  Uri _trackingEndpoint = Uri.parse("https://api.avo.app/inspector/v1/track");

  AvoNetworkCallsHandler(
      {required this.apiKey,
      required this.envName,
      required this.appName,
      required this.appVersion,
      required this.libVersion});

  SessionStartedBody bodyForSessionStaretedCall({required String sessionId, required String installationId}) {
    return SessionStartedBody(
        apiKey: this.apiKey,
        appName: this.appName,
        appVersion: this.appVersion,
        libVersion: this.libVersion,
        env: this.envName,
        messageId: Uuid().v1(),
        trackingId: installationId,
        createdAt: DateTime.now().toIso8601String(),
        sessionId: sessionId);
  }

  void callInspectorWith(
      {required List<BaseBody> events, Function(String?)? onCompleted}) {
    if (AvoInspector.shouldLog) {
      print("Avo Inspector: events $events");

      events.forEach((event) {
        if (event.type == "sessionStarted") {
          print("Avo Inspector: sending session started event.");
        }
      });
    }

    final listOfEventMaps = events.map((e) => e.toJson()).toList();

    final body = json.encode(listOfEventMaps);

    http
        .post(_trackingEndpoint,
            headers: {"Content-Type": "text/plain"}, body: body)
        .then((response) {
      print(response.body);
      onCompleted?.call(null);
    }).onError((error, stackTrace) {
      onCompleted?.call(error.toString());
    });
  }
}
