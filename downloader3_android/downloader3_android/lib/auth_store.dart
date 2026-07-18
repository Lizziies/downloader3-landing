import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthStore {
  static const _kEmail = 'current_email';
  static const _kLang = 'language';
  static const _kAccent = 'accent';
  static const _kBackend = 'backend_url';
  static const _kPremiumUntil = 'premium_until';
  static const _kPremiumRole = 'premium_role';

  final SharedPreferences prefs;
  AuthStore(this.prefs);

  static Future<AuthStore> load() async =>
      AuthStore(await SharedPreferences.getInstance());

  String get language => prefs.getString(_kLang) ?? 'en';
  set language(String v) => prefs.setString(_kLang, v);

  String get accent => prefs.getString(_kAccent) ?? 'Pink';
  set accent(String v) => prefs.setString(_kAccent, v);

  String get backendUrl =>
      prefs.getString(_kBackend) ?? 'https://downloader3-backend.onrender.com';
  set backendUrl(String v) => prefs.setString(_kBackend, v);

  String? get currentEmail => prefs.getString(_kEmail);
  Future<void> setCurrentEmail(String? email) async {
    if (email == null) {
      await prefs.remove(_kEmail);
    } else {
      await prefs.setString(_kEmail, email);
    }
  }

  String? get premiumUntil => prefs.getString(_kPremiumUntil);
  String? get premiumRole => prefs.getString(_kPremiumRole);
  bool get isPremium {
    final until = premiumUntil;
    if (until == null || until.isEmpty) return false;
    if (until == 'forever') return true;
    final d = DateTime.tryParse(until);
    if (d == null) return false;
    return d.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  }

  Future<void> setPremium(String? until, String? role) async {
    if (until == null) {
      await prefs.remove(_kPremiumUntil);
    } else {
      await prefs.setString(_kPremiumUntil, until);
    }
    if (role == null) {
      await prefs.remove(_kPremiumRole);
    } else {
      await prefs.setString(_kPremiumRole, role);
    }
  }

  Future<void> logout() async {
    await setCurrentEmail(null);
    await prefs.remove(_kPremiumUntil);
    await prefs.remove(_kPremiumRole);
  }

  String _vKeyHash(String email) => 'vcode_hash_$email';
  String _vKeyExp(String email) => 'vcode_exp_$email';

  String startVerification(String email) {
    final code = (100000 + Random.secure().nextInt(900000)).toString();
    final hash = sha256.convert(utf8.encode('vcode::$code')).toString();
    final expires = DateTime.now().add(const Duration(minutes: 15));
    prefs.setString(_vKeyHash(email), hash);
    prefs.setString(_vKeyExp(email), expires.toIso8601String());
    return code;
  }

  String checkVerification(String email, String code) {
    final hash = prefs.getString(_vKeyHash(email));
    final expIso = prefs.getString(_vKeyExp(email));
    if (hash == null || expIso == null) return 'wrong';
    final exp = DateTime.tryParse(expIso);
    if (exp == null || DateTime.now().isAfter(exp)) return 'expired';
    final candidate = sha256.convert(utf8.encode('vcode::$code')).toString();
    return candidate == hash ? 'ok' : 'wrong';
  }
}
