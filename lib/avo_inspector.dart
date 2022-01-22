library avo_inspector;

import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:avo_inspector/avo_parser.dart';

enum AvoInspectorEnv { prod, dev, staging }

class AvoInspector {
  String apiKey;
  AvoInspectorEnv env;
  String appVersion;
  String appName;

  static bool shouldLog = false;

  AvoInspector(
      {required this.apiKey,
      required this.env,
      required this.appVersion,
      required this.appName});

  List<Map<String, dynamic>> trackSchemaFromEvent(
      {required String eventName,
      required Map<String, dynamic> eventProperties}) {
    if (shouldLog) {
      print("event name $eventName");
    }

    final parsedParams =
        extractSchemaFromEventParams(eventParams: eventProperties);

    if (shouldLog) {
      print("event params $parsedParams");
    }

    final networkHandler = AvoNetworkCallsHandler(
        apiKey: this.apiKey,
        envName: this.env.toString(),
        appName: this.appName,
        appVersion: this.appVersion,
        libVersion: "1.0");

    networkHandler.callInspectorWith(events: [
      SessionStartedBody(
          apiKey: this.apiKey,
          appName: this.appName,
          appVersion: this.appVersion,
          libVersion: networkHandler.libVersion,
          env: networkHandler.envName,
          messageId: Uuid().toString(),
          trackingId: "unique persistent id",
          createdAt: DateTime.now().toIso8601String(),
          sessionId: "unique id per session")
    ]);

    return parsedParams;
  }
}
