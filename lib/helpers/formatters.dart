class Formatters {
  static String date(DateTime d){
    return d.toIso8601String().split('T').first;
  }
}
