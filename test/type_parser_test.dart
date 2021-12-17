import 'package:flutter_test/flutter_test.dart';

import 'package:avo_inspector/avo_inspector.dart';

void main() {
  test('int parameters are extracted as "int"', () {
    final result = extractTypeJson(1);

    expect(result, {
      "propertyType": "int",
    });
  });

  test('double parameters are extracted as "float"', () {
    final result = extractTypeJson(1.0);

    expect(result, {
      "propertyType": "float",
    });
  });

  test('string parameters are extracted as "string"', () {
    final result = extractTypeJson("hello world");

    expect(result, {
      "propertyType": "string",
    });
  });

  test('boolean parameters are extracted as "bool"', () {
    final result = extractTypeJson(true);

    expect(result, {
      "propertyType": "bool",
    });
  });

  test('map parameters are extracted as "object"', () {
    final result = extractTypeJson({"one": 1, "two": 2, "three": 3});

    expect(result, {
      "propertyType": "object",
    });
  });

  test('Random object parameters are extracted as "unknown"', () {
    final result = extractTypeJson(Calculator());

    expect(result, {
      "propertyType": "unknown",
    });
  });

  test('null object is extracted as null', () {
    final result = extractTypeJson(null);

    expect(result, {
      "propertyType": "null",
    });
  });

  test('empty list is extracted with subtypes', () {
    final result = extractTypeJson([]);

    expect(result, {"propertyType": "list", "children": []});
  });

  test('empty set is extracted with empty subtypes', () {
    final result = extractTypeJson(<String>{});

    expect(result, {"propertyType": "list", "children": []});
  });

  test('list with only null is extracted with subtypes', () {
    final result = extractTypeJson([null]);

    expect(result, {
      "propertyType": "list",
      "children": ["null"]
    });
  });

  test('set with only null is extracted with subtypes', () {
    final result = extractTypeJson({null});

    expect(result, {
      "propertyType": "list",
      "children": ["null"]
    });
  });

  test('list parameters are extracted with subtypes', () {
    final result = extractTypeJson([1, 2, 3, null]);

    expect(result, {
      "propertyType": "list",
      "children": ["int", "null"]
    });
  });

  test('set parameters are extracted with subtypes', () {
    final result = extractTypeJson({1, 2, 3, null});

    expect(result, {
      "propertyType": "list",
      "children": ["int", "null"]
    });
  });

  test('list parameters with mixed types are extracted as unknown', () {
    final result = extractTypeJson([1, 2, 3, "", null]);

    expect(result, {
      "propertyType": "list",
      "children": ["int", "string", "null"]
    });
  });

  test('set parameters with mixed types are extracted as unknown', () {
    final result = extractTypeJson({1, 2, 3, "", null});

    expect(result, {
      "propertyType": "list",
      "children": ["int", "string", "null"]
    });
  });
}
