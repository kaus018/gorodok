import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'storage.dart';

final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

// ====================== РЕГИСТРАЦИЯ ======================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final err = await Store.register(_name.text.trim(), _email.text.trim(), _pass.text);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Регистрация прошла успешно')));
    Navigator.pop(context); // назад к авторизации
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Регистрация')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: ListView(children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Введите email';
                  if (!_emailRe.hasMatch(v.trim())) return 'Некорректный email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите пароль';
                  if (v.length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass2,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Повторите пароль', border: OutlineInputBorder()),
                validator: (v) => v != _pass.text ? 'Пароли не совпадают' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _submit, child: const Text('Зарегистрироваться')),
            ]),
          ),
        ),
      );
}

// ====================== АВТОРИЗАЦИЯ ======================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final err = await Store.login(_email.text.trim(), _pass.text);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: ListView(children: [
                const SizedBox(height: 40),
                Icon(Icons.location_city, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                const Center(
                    child: Text('ГородОК', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Введите пароль' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _submit, child: const Text('Войти')),
                TextButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Нет аккаунта? Зарегистрироваться'),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ====================== ОСНОВНАЯ НАВИГАЦИЯ ======================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onNew: () => setState(() => _i = 1)),
      NewReportScreen(onSaved: () => setState(() => _i = 2)),
      const MyReportsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: pages[_i], // страницы пересоздаются, данные всегда актуальны
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.add_a_photo), label: 'Сообщить'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Мои'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

// ====================== ГЛАВНАЯ ======================
class HomeScreen extends StatelessWidget {
  final VoidCallback onNew;
  const HomeScreen({super.key, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ГородОК')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onNew,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Сообщить о проблеме'),
      ),
      body: StreamBuilder<List<Report>>(
        stream: Store.allReports(),
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final reports = s.data!;
          return reports.isEmpty
              ? const Center(child: Text('Пока нет обращений. Станьте первым!'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: reports.length,
                  itemBuilder: (_, i) => ReportCard(reports[i]),
                );
        },
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final Report r;
  final VoidCallback? onDelete; // кнопка удаления только для своих обращений
  const ReportCard(this.r, {super.key, this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.photo.isNotEmpty)
            Image.memory(base64Decode(r.photo), height: 180, width: double.infinity, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(r.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Удалить',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ]),
              const SizedBox(height: 4),
              Chip(label: Text(r.category)),
              if (r.description.isNotEmpty) Text(r.description),
              const SizedBox(height: 6),
              if (r.address.isNotEmpty)
                Text('📍 ${r.address}', style: Theme.of(context).textTheme.bodyMedium),
              if (r.lat != null && r.lng != null)
                Text('${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall),
              Text(r.date, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
      );
}

// ====================== НОВОЕ ОБРАЩЕНИЕ (основной раздел) ======================
class NewReportScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const NewReportScreen({super.key, required this.onSaved});
  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  static const _cats = ['Яма на дороге', 'Освещение', 'Мусор', 'Благоустройство', 'Другое'];
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _address = TextEditingController();
  String _cat = _cats.first;
  String? _photo;
  Position? _pos;
  bool _busy = false;
  bool _saving = false;

  /// Выбор источника фото: камера или галерея.
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Сделать фото'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 40);
      if (x != null) setState(() => _photo = x.path);
    } catch (_) {
      // например, на симуляторе нет камеры или отказано в доступе
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось получить фото. Попробуйте выбрать из галереи')));
    }
  }

  Future<void> _locate() async {
    setState(() => _busy = true);
    Position? p;
    String? error;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'Служба геолокации выключена. Включите её в настройках';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          error = 'Нет разрешения на геолокацию';
        } else if (perm == LocationPermission.deniedForever) {
          error = 'Доступ к геолокации запрещён. Разрешите его в настройках приложения';
        } else {
          // таймаут нужен, чтобы кнопка не «зависала», если координаты не приходят
          p = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 10));
        }
      }
    } catch (_) {
      error = 'Не удалось получить координаты. На симуляторе задайте точку: '
          'Features → Location → Custom Location';
    }
    if (!mounted) return;
    setState(() {
      _pos = p;
      _busy = false;
    });
    if (p == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error ?? 'Не удалось определить местоположение')));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_photo == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Добавьте фото')));
      return;
    }
    // место можно указать координатами, адресом или и тем и другим
    if (_pos == null && _address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Укажите место: определите геолокацию или введите адрес')));
      return;
    }
    if (_saving) return; // защита от повторного нажатия
    setState(() => _saving = true);
    final d = DateTime.now();
    try {
      await Store.addReport(Report(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        category: _cat,
        photo: base64Encode(await File(_photo!).readAsBytes()),
        author: Store.email!,
        date: '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
        address: _address.text.trim(),
        lat: _pos?.latitude,
        lng: _pos?.longitude,
      ));
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is ApiException
              ? e.message
              : 'Не удалось отправить обращение. Проверьте интернет и запуск сервера')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Новое обращение')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Заголовок', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите заголовок' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _cat,
              decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder()),
              items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _cat = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            if (_photo != null) Image.file(File(_photo!), height: 180, fit: BoxFit.cover),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.add_a_photo),
              label: Text(_photo == null ? 'Добавить фото' : 'Изменить фото'),
            ),
            const SizedBox(height: 8),
            const Text('Место проблемы', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _locate,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: Text(_pos == null
                  ? 'Определить геолокацию'
                  : '${_pos!.latitude.toStringAsFixed(5)}, ${_pos!.longitude.toStringAsFixed(5)}'),
            ),
            const SizedBox(height: 4),
            const Center(child: Text('или')),
            const SizedBox(height: 4),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Адрес (улица, дом)',
                hintText: 'Например: пр. Мангилик Ел, 10',
                prefixIcon: Icon(Icons.edit_location_alt),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Отправка...' : 'Отправить'),
            ),
          ]),
        ),
      );
}

// ====================== МОИ ОБРАЩЕНИЯ ======================
Future<void> _confirmDelete(BuildContext context, Report r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удалить обращение?'),
      content: Text(r.title),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await Store.deleteReport(r.id);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : 'Не удалось удалить обращение')));
  }
}

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои обращения')),
      body: StreamBuilder<List<Report>>(
        stream: Store.myReports(),
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final list = s.data!;
          return list.isEmpty
              ? const Center(child: Text('У вас пока нет обращений'))
              : ListView(
                  children: list
                      .map((r) => ReportCard(r, onDelete: () => _confirmDelete(context, r)))
                      .toList());
        },
      ),
    );
  }
}

// ====================== ПРОФИЛЬ + ВЫХОД ======================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Профиль')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 48)),
            const SizedBox(height: 12),
            Text(Store.userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(Store.email ?? ''),
            const SizedBox(height: 8),
            StreamBuilder<List<Report>>(
              stream: Store.myReports(),
              builder: (_, s) => Text('Обращений: ${s.data?.length ?? 0}'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
                onPressed: () async {
                  await Store.logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                },
              ),
            ),
          ]),
        ),
      );
}