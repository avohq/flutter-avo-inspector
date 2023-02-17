bool isUuid(String stringToTest) {
  return stringToTest.split("-").length == 5 && stringToTest.length == 36;
}
