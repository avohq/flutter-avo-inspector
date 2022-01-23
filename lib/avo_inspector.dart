library avo_inspector;

import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:avo_inspector/avo_parser.dart';
import 'package:avo_inspector/avo_session_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<List<Map<String, dynamic>>> trackSchemaFromEvent(
      {required String eventName,
      required Map<String, dynamic> eventProperties}) async {
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

    final sessionsTracker = AvoSessionTracker(
        networkCallsHandler: networkHandler,
        sharedPreferences: await SharedPreferences.getInstance());
     sessionsTracker
        .startOrProlongSession(DateTime.now().millisecondsSinceEpoch);

    return parsedParams;
  }
}
