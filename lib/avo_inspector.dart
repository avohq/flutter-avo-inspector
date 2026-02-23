library avo_inspector;

import 'package:avo_inspector/avo_anonymous_id.dart';
import 'package:avo_inspector/avo_batcher.dart';
import 'package:avo_inspector/avo_network_calls_handler.dart';
import 'package:avo_inspector/avo_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AvoInspectorEnv { prod, dev, staging }

class AvoInspector {
  String apiKey;
  AvoInspectorEnv env;
  String appVersion;
  String appName;
  String? publicEncryptionKey;

  static bool shouldLog = false;

  late AvoBatcher _avoBatcher;

  static Future<AvoInspector> create(
      {required String apiKey,
      required AvoInspectorEnv env,
      required String appVersion,
      required String appName,
      String? publicEncryptionKey}) async {
    final sharedPrefs = await SharedPreferences.getInstance();

    final anonymousIdProvider = AvoAnonymousId();
    final anonymousId = await anonymousIdProvider.getAnonymousId();

    return AvoInspector._create(
        sharedPrefs: sharedPrefs,
        apiKey: apiKey,
        env: env,
        appVersion: appVersion,
        appName: appName,
        publicEncryptionKey: publicEncryptionKey,
        anonymousId: anonymousId);
  }

  AvoInspector._create(
      {required SharedPreferences sharedPrefs,
      required this.apiKey,
      required this.env,
      required this.appVersion,
      required this.appName,
      this.publicEncryptionKey,
      required String anonymousId}) {
    final networkHandler = AvoNetworkCallsHandler(
        apiKey: this.apiKey,
        envName: this.env.toString().split('.').last,
        appName: this.appName,
        appVersion: this.appVersion,
        libVersion: "1.0");

    if (env == AvoInspectorEnv.dev) {
      AvoBatcher.batchSizeThreshold = 1;
    } else {
      AvoBatcher.batchSizeThreshold = 30;
    }

    _avoBatcher = AvoBatcher(
        sharedPreferences: sharedPrefs,
        networkCallsHandler: networkHandler,
        avoAnonymousId: anonymousId);
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
