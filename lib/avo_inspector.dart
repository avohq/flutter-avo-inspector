library avo_inspector;

/// A Calculator.
class Calculator {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;
}

String extractType(Object? eventParam) {
  if (eventParam == null) {
    return "null";
  }

  final type = eventParam.runtimeType.toString().toLowerCase();

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
