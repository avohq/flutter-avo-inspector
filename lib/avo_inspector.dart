library avo_inspector;

import 'dart:convert';

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

String runtimeTypeToAvoType(String? type) {
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

String extractType(Object? eventParam) {
  final type = eventParam?.runtimeType.toString().toLowerCase();

  return runtimeTypeToAvoType(type);
}

Map<String, dynamic> extractTypeJson(Object? eventParam) {
  final type = extractType(eventParam);

  if (type == "list") {
    final runtimeType = eventParam.runtimeType.toString().toLowerCase();

    var subtype = runtimeType.substring(
        runtimeType.indexOf("<") + 1, runtimeType.indexOf(">"));

    final isOptional = subtype.contains("?");

    if (isOptional) {
      subtype = subtype.substring(0, subtype.length - 1);
    }

    var children = <String>{};
    if (subtype == "dynamic" || subtype == "object") {
      (eventParam as Iterable).forEach((element) {
        children.add(extractType(element));
      });
    } else {
      children.add(subtype);
    }

    if (isOptional) {
      children.add("null");
    }

    Map<String, dynamic> result = {"propertyType": type, "children": children};

    return result;
  } else {
    return {
      "propertyType": type,
    };
  }
}
