import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api.dart';

class Report {
  final String title, description, category, photo, author, date; // photo = base64
  final String address; // адрес, введённый вручную (может быть пустым)
  final String id; // идентификатор документа в Firestore (нужен для удаления)
  final double? lat, lng; // координаты (могут отсутствовать, если указан адрес)
  Report({
    required this.title,
    required this.description,
    required this.category,
    required this.photo,
    required this.author,
    required this.date,
    this.address = '',
    this.id = '',
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category,
        'photo': photo,
        'author': author,
        'date': date,
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        category: j['category'] ?? '',
        photo: j['photo'] ?? '',
        author: j['author'] ?? '',
        date: j['date'] ?? '',
        address: j['address'] ?? '',
        id: j['id'] ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

/// Слой данных: Firebase Authentication, чтение из Cloud Firestore,
/// создание и удаление обращений через сервер на Python (api.dart).
class Store {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // ---- Пользователи и сессия ----
  static String? get email => _auth.currentUser?.email;
  static String get userName => _auth.currentUser?.displayName ?? '';

  static String _msg(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Пользователь с таким email уже существует';
      case 'weak-password':
        return 'Слишком простой пароль';
      case 'invalid-email':
        return 'Некорректный email';
      case 'network-request-failed':
        return 'Нет подключения к интернету';
      default:
        return 'Неверный email или пароль';
    }
  }

  /// Возвращает текст ошибки или null при успехе.
  static Future<String?> register(String name, String email, String pass) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(email: email, password: pass);
      await c.user!.updateDisplayName(name);
      try {
        await _db.collection('users').doc(c.user!.uid).set({'name': name, 'email': email});
      } catch (_) {
        // профиль в Firestore дублирует данные аккаунта: если база не создана
        // или закрыта правилами, регистрация всё равно должна завершиться
      }
      await _auth.signOut(); // после регистрации пользователь входит заново
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (_) {
      return 'Не удалось выполнить регистрацию. Проверьте подключение к интернету';
    }
  }

  static Future<String?> login(String email, String pass) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: pass);
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (_) {
      return 'Не удалось выполнить вход. Проверьте подключение к интернету';
    }
  }

  static Future<void> logout() => _auth.signOut();

  // ---- Обращения (коллекция reports) ----
  static List<Report> _parse(QuerySnapshot<Map<String, dynamic>> s) {
    final docs = s.docs.toList()
      ..sort((a, b) => ((b.data()['ts'] as num?) ?? 0).compareTo((a.data()['ts'] as num?) ?? 0));
    return docs.map((d) => Report.fromJson({...d.data(), 'id': d.id})).toList();
  }

  static Stream<List<Report>> allReports() =>
      _db.collection('reports').snapshots().map(_parse);

  static Stream<List<Report>> myReports() => _db
      .collection('reports')
      .where('author', isEqualTo: email)
      .snapshots()
      .map(_parse);

  /// Создание обращения выполняет сервер: он проверяет данные и токен,
  /// сам подставляет автора и время.
  static Future<void> addReport(Report r) => Api.createReport(r.toJson());

  /// Удаление своего обращения (сервер проверяет авторство).
  static Future<void> deleteReport(String id) => Api.deleteReport(id);
}
