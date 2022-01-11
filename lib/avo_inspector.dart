library avo_inspector;

import 'package:flutter/material.dart';

class Calculator {
  int addOne(int value) => value + 1;
}

/* String _runtimeTypeToAvoType(String? type) {
  if (type == null) {
    return "null";
  }

  if (type.contains("list") || type.contains(("set"))) {
    return "list";
  } else if (type.contains("map")) {
    return "object";
  } else if (["double", "float"].contains(type)) {
    return "float";
  } else if (["string", "int", "bool"].contains(type)) {
    return type;
  }

  return "unknown";
}

String _extractType(Object? eventParam) {
  final type = eventParam?.runtimeType.toString().toLowerCase();

  return _runtimeTypeToAvoType(type);
} */


