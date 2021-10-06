import 'package:flutter_test/flutter_test.dart';

import 'package:avo_inspector/avo_inspector.dart';

void main() {
  test('adds one to input values', () {
    final calculator = Calculator();
    expect(calculator.addOne(2), 3);
    expect(calculator.addOne(-7), -6);
    expect(calculator.addOne(0), 1);
  });

  test('int parameters are extracted as "int"', () {
    final result = extractType(1);

    expect(result, "int");
  });

  test('double parameters are extracted as "float"', () {
    final result = extractType(1.0);

    expect(result, "float");
  });

  test('string parameters are extracted as "string"', () {
    final result = extractType("hello world");

    expect(result, "string");
  });

  test('boolean parameters are extracted as "bool"', () {
    final result = extractType(true);

    expect(result, "bool");
  });

  test('list parameters are extracted as "list"', () {
    final result = extractType([1,2,3]);

    expect(result, "list");
  });

  test('set parameters are extracted as "list"', () {
    final result = extractType({"one", "two", "three"});

    expect(result, "list");
  });

  test('map parameters are extracted as "object"', () {
    final result = extractType({"one": 1, "two": 2, "three": 3});

    expect(result, "object");
  });

  test('Random object parameters are extracted as "unknown"', () {
    final result = extractType(Calculator());

    expect(result, "unknown");
  });
}
