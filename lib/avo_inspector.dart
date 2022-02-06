library avo_inspector;

import 'package:avo_inspector/avo_batcher.dart';
import 'package:avo_inspector/avo_installation_id.dart';
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

  final AvoInstallationId avoInstallationId = AvoInstallationId();

  late AvoBatcher _avoBatcher;

  static Future<AvoInspector> create(
      {required String apiKey,
      required AvoInspectorEnv env,
      required String appVersion,
      required String appName}) async {
    final sharedPrefs = await SharedPreferences.getInstance();

    return AvoInspector._create(
        sharedPrefs: sharedPrefs,
        apiKey: apiKey,
        env: env,
        appVersion: appVersion,
        appName: appName);
  }

  AvoInspector._create(
      {required SharedPreferences sharedPrefs,
      required this.apiKey,
      required this.env,
      required this.appVersion,
      required this.appName}) {
    final networkHandler = AvoNetworkCallsHandler(
        apiKey: this.apiKey,
        envName: this.env.toString().split('.').last,
        appName: this.appName,
        appVersion: this.appVersion,
        libVersion: "1.0");

    final sessionTracker = AvoSessionTracker(sharedPreferences: sharedPrefs);

    if (env == AvoInspectorEnv.dev) {
      AvoBatcher.batchSizeThreshold = 1;
    } else {
      AvoBatcher.batchSizeThreshold = 30;
    }

    _avoBatcher = AvoBatcher(
        sessionTracker: sessionTracker,
        sharedPreferences: sharedPrefs,
        networkCallsHandler: networkHandler,
        avoInstallationId: avoInstallationId.getInstallationId(sharedPrefs));
  }

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

    _avoBatcher.handleTrackSchema(
        eventName: eventName, eventSchema: parsedParams);

    return parsedParams;
  }
}
