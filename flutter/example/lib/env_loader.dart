import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvLoader {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env.development.local');
  }

  static String? get(String key) {
    return dotenv.env[key];
  }

  static String getOrEmpty(String key) {
    return dotenv.env[key] ?? '';
  }
}
