import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/index.dart';

/// Layanan khusus untuk operasi Supabase terkait user.
class UserService {
  final SupabaseClient _supabase;
  UserService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<UserProfile> createUser(
      {required String name, String role = 'user'}) async {
    final now = DateTime.now();
    try {
      final response = await _supabase
          .from('users')
          .insert({
            'nama': name,
            'role': role,
            'created_at': now.toIso8601String(),
          })
          .select()
          .single();

      return UserProfile(
        id: response['id'] as String,
        nama: response['nama'] as String,
        role: response['role'] as String,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } catch (_) {
      return UserProfile(
        id: const Uuid().v4(),
        nama: name,
        role: role,
        createdAt: now,
      );
    }
  }

  Future<UserProfile?> getUser(String id) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', id).single();

      return UserProfile(
        id: response['id'] as String,
        nama: response['nama'] as String? ?? '-',
        role: response['role'] as String? ?? 'user',
        createdAt: DateTime.parse(response['created_at'] as String? ??
            DateTime.now().toIso8601String()),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Menyimpan sesi login di SharedPreferences (ID & nama user).
class UserSessionManager {
  static const _keyUserId = 'session_user_id';
  static const _keyUserName = 'session_user_name';
  static const _keyAccounts = 'accountsV2'; // format: name::id

  Future<void> saveSession(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUserName, user.nama);
  }

  Future<void> saveSessionRaw(
      {required String id, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, id);
    await prefs.setString(_keyUserName, name);
  }

  Future<Map<String, String>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyAccounts) ?? [];
    final map = <String, String>{};
    for (final entry in raw) {
      final parts = entry.split('::');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  Future<void> saveAccounts(Map<String, String> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final list = accounts.entries.map((e) => '${e.key}::${e.value}').toList();
    await prefs.setStringList(_keyAccounts, list);
  }

  Future<(String?, String?)> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_keyUserId), prefs.getString(_keyUserName));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
  }
}

class AuthController extends ChangeNotifier {
  final _userService = UserService();
  final _session = UserSessionManager();
  Map<String, String> _accountIds = {}; // name -> userId
  String? _userId;
  String? _userName;
  bool _ready = false;
  bool _isAdmin = false;
  String? _adminKecamatan;

  String? get userId => _userId;
  String? get userName => _userName;
  List<String> get accounts => List.unmodifiable(_accountIds.keys);
  bool get isReady => _ready;
  bool get isLoggedIn => _userId != null;
  bool get isAdmin => _isAdmin;
  String? get adminKecamatan => _adminKecamatan;

  AuthController() {
    _load();
  }

  Future<void> _load() async {
    try {
      _accountIds = await _session.loadAccounts();
      final session = await _session.loadSession();
      _userId = session.$1;
      _userName = session.$2;
    } catch (e) {
      // Jika gagal baca prefs, tetap lanjut dengan data kosong agar UI tidak hang.
      _accountIds = {};
      _userId = null;
      _userName = null;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> _persistAccounts() async {
    try {
      await _session.saveAccounts(_accountIds);
    } catch (_) {}
  }

  Future<void> createAccount(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final user = await _userService.createUser(name: clean);
    _userId = user.id;
    _userName = user.nama;
    _accountIds[user.nama] = user.id;
    await _persistAccounts();
    await _session.saveSession(user);
    notifyListeners();
  }

  Future<void> loginWithExisting(String name) async {
    final id = _accountIds[name];
    if (id == null) return;
    _userId = id;
    _userName = name;
    await _session.saveSessionRaw(id: id, name: name);
    notifyListeners();
  }

  Future<bool> loginAsAdmin({
    required String password,
    required String kecamatan,
  }) async {
    const adminPassword = 'admin123';
    if (password.trim() != adminPassword) return false;
    _adminKecamatan = kecamatan;
    _isAdmin = true;
    _userName = 'Admin';
    _userId = 'admin';
    await _session.saveSessionRaw(id: _userId!, name: _userName!);
    notifyListeners();
    return true;
  }

  void logout() {
    _userName = null;
    _userId = null;
    _isAdmin = false;
    _adminKecamatan = null;
    _session.clearSession();
    notifyListeners();
  }
}
