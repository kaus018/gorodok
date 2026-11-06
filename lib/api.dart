import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Адрес сервера на Python. Для телефона или другого компьютера задайте
/// при запуске: flutter run --dart-define=API_URL=http://192.168.0.10:8000
const _envUrl = String.fromEnvironment('API_URL');

String get apiBase {
  if (_envUrl.isNotEmpty) return _envUrl;
  // Эмулятор Android видит компьютер по адресу 10.0.2.2, симулятор iOS - по 127.0.0.1
  return Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Клиент серверной части на Python (FastAPI).
/// К каждому запросу добавляется токен Firebase Authentication.
class Api {
  static const _timeout = Duration(seconds: 30);

  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw ApiException('Требуется вход в систему');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  /// Достаёт текст ошибки из ответа сервера (поле detail).
  static String _detail(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes))['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty) {
        return d
            .map((e) => '${e['msg']}'.replaceFirst('Value error, ', ''))
            .join('; ');
      }
    } catch (_) {}
    return 'Ошибка сервера (${r.statusCode})';
  }

  static Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Сервер недоступен. Проверьте, что он запущен');
    } catch (_) {
      throw ApiException('Не удалось связаться с сервером');
    }
  }

  /// Создаёт обращение, возвращает его идентификатор.
  static Future<String> createReport(Map<String, dynamic> body) => _call(() async {
        final r = await http
            .post(Uri.parse('$apiBase/reports'),
                headers: await _headers(), body: jsonEncode(body))
            .timeout(_timeout);
        if (r.statusCode != 201) throw ApiException(_detail(r));
        return jsonDecode(r.body)['id'] as String;
      });

  /// Удаляет своё обращение.
  static Future<void> deleteReport(String id) => _call(() async {
        final r = await http
            .delete(Uri.parse('$apiBase/reports/$id'), headers: await _headers())
            .timeout(_timeout);
        if (r.statusCode != 200) throw ApiException(_detail(r));
      });

  /// Количество обращений по категориям.
  static Future<Map<String, int>> stats() => _call(() async {
        final r = await http
            .get(Uri.parse('$apiBase/stats'), headers: await _headers())
            .timeout(_timeout);
        if (r.statusCode != 200) throw ApiException(_detail(r));
        final m = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        return m.map((k, v) => MapEntry(k, (v as num).toInt()));
      });
}
