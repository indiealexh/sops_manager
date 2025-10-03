import 'dart:io';

class FilePath {
  static String join(String a, String b) {
    if (a.endsWith(Platform.pathSeparator)) return a + b;
    return a + Platform.pathSeparator + b;
  }
}
