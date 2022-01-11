library avo_inspector;

import 'package:avo_inspector/avo_parser.dart';

enum AvoInspectorEnv { prod, dev, staging }

class AvoInspector {
  String apiKey;
  AvoInspectorEnv env;
  String appVersion;
  String appName;

  bool _shouldLog = false;

  AvoInspector(
      {required this.apiKey,
      required this.env,
      required this.appVersion,
      required this.appName});

  List<Map<String, dynamic>> trackSchemaFromEvent(
      String eventName, Map<String, dynamic> eventProperties) {
    if (_shouldLog) {
      print("event name $eventName");
    }

    final parsedParams =
        extractSchemaFromEventParams(eventParams: eventProperties);

    if (_shouldLog) {
      print("event params $parsedParams");
    }

    return parsedParams;
  }

  set shouldLog(bool val) {
    _shouldLog = val;
  }
}
