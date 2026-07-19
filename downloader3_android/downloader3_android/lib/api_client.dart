import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// 🌍 Spricht mit genau demselben premium-backend (Flask, siehe
/// premium-backend/app.py), das auch die Windows-App nutzt — dasselbe
/// Konto funktioniert also auf beiden Plattformen. Endpunkte + Feld-
/// namen 1:1 aus app.py übernommen (nicht geraten — dort nachgelesen),
/// damit hier nicht dieselbe Art Fehler passiert wie beim gofile.io-
/// Umbau (falscher Endpunkt geraten -> HTTP 404).
class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);

  Uri _u(String path, [Map<String, String>? query]) =>
      Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '') + path)
          .replace(queryParameters: query);

  /// Identisch zu Store.hash_pw() in main.py — GLEICHES Salt, GLEICHER
  /// Hash-Algorithmus, damit ein auf dem Desktop registriertes Konto
  /// sich auch hier mit demselben Passwort einloggen kann (und
  /// umgekehrt).
  static String hashPassword(String pw) {
    final bytes = utf8.encode('coolgrab::$pw');
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, dynamic>> register(String email, String pw) async {
    final r = await http.post(
      _u('/api/account-register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password_hash': hashPassword(pw),
      }),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<Map<String, dynamic>> login(String email, String pw) async {
    final r = await http.post(
      _u('/api/account-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password_hash': hashPassword(pw),
      }),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<Map<String, dynamic>> accountStatus(String email) async {
    final r = await http
        .get(_u('/api/account-status', {'email': email}))
        .timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  Future<Map<String, dynamic>> redeemCode(String code, String email) async {
    final r = await http
        .get(_u('/api/redeem', {'code': code, 'email': email}))
        .timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  /// Verschickt den Bestätigungs-/Reset-Code per E-Mail — der eigentliche
  /// SMTP-Versand passiert komplett serverseitig, die App kennt keine
  /// Zugangsdaten.
  Future<Map<String, dynamic>> sendCode(
    String toEmail,
    String code, {
    String? subject,
    String? body,
  }) async {
    final r = await http.post(
      _u('/api/send-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'to': toEmail,
        'code': code,
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      }),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  // --- 📤 Datei senden ----------------------------------------------------
  Future<Map<String, dynamic>> sendFile({
    required String fromEmail,
    required String to,
    required String message,
    required String filename,
    required String contentB64,
  }) async {
    final r = await http.post(
      _u('/api/send-file'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from_email': fromEmail,
        'to': to,
        'message': message,
        'filename': filename,
        'content_b64': contentB64,
      }),
    ).timeout(const Duration(seconds: 60));
    return _decode(r);
  }

  // --- ✉️ Kontakt zum Entwickler -------------------------------------------
  Future<Map<String, dynamic>> contactOwner(
      String email, String message, String context) async {
    final r = await http.post(
      _u('/api/contact-owner'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'message': message, 'context': context}),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  // --- Music-Link-Aufloesung (Spotify/Apple Music/Amazon Music) --------
  Future<Map<String, dynamic>> musicLookup(String url) async {
    final r = await http.post(
      _u('/api/music-lookup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    ).timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  // --- 🤝 Helfer-Ehrentafel ------------------------------------------------
  Future<Map<String, dynamic>> helpersPublic() async {
    final r = await http.get(_u('/api/helpers-public'))
        .timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  Future<Map<String, dynamic>> helperSetPublic(
      String email, String publicName, bool optIn) async {
    final r = await http.post(
      _u('/api/helper-set-public'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'public_name': publicName,
        'opt_in': optIn,
      }),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<Map<String, dynamic>> helperCreateCode(String email,
      {int days = 5}) async {
    final r = await http.post(
      _u('/api/helper-create-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'days': days}),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  // --- 🎨 KI-Studio ---------------------------------------------------------
  Future<Map<String, dynamic>> aiText(String prompt, String email) async {
    final r = await http.post(
      _u('/api/ai-text'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt, 'email': email}),
    ).timeout(const Duration(seconds: 65));
    return _decode(r);
  }

  Future<Map<String, dynamic>> aiImage(String prompt, String email) async {
    final r = await http.post(
      _u('/api/ai-image'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt, 'email': email}),
    ).timeout(const Duration(seconds: 95));
    return _decode(r);
  }

  Future<Map<String, dynamic>> aiVideoStart(String prompt, String email) async {
    final r = await http.post(
      _u('/api/ai-video'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt, 'email': email}),
    ).timeout(const Duration(seconds: 65));
    return _decode(r);
  }

  Future<Map<String, dynamic>> aiVideoStatus(String operation) async {
    final r = await http
        .get(_u('/api/ai-video-status', {'operation': operation}))
        .timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  /// Gibt bei Erfolg die rohen MP4-Bytes zurück, sonst null.
  Future<List<int>?> aiVideoDownload(String operation) async {
    final r = await http
        .get(_u('/api/ai-video-download', {'operation': operation}))
        .timeout(const Duration(seconds: 130));
    if (r.statusCode == 200 &&
        (r.headers['content-type'] ?? '').contains('video')) {
      return r.bodyBytes;
    }
    return null;
  }

  // --- 👑 Admin (Owner-only, geschützt durch owner_password) --------------
  Future<Map<String, dynamic>> verifyOwner(String email, String password) async {
    final r = await http.post(
      _u('/api/verify-owner'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<Map<String, dynamic>> adminGrantPremium(
      String ownerPw, String email, int? days) async {
    final r = await http.post(
      _u('/api/admin-grant-premium'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'owner_password': ownerPw, 'email': email, 'days': days}),
    ).timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  Future<Map<String, dynamic>> adminListAccounts(String ownerPw) async {
    final r = await http.post(
      _u('/api/admin-list-accounts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'owner_password': ownerPw}),
    ).timeout(const Duration(seconds: 30));
    return _decode(r);
  }

  Future<Map<String, dynamic>> adminRevokePremium(
      String ownerPw, String email) async {
    final r = await http.post(
      _u('/api/admin-revoke-premium'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'owner_password': ownerPw, 'email': email}),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<Map<String, dynamic>> adminDeleteAccount(
      String ownerPw, String email) async {
    final r = await http.post(
      _u('/api/admin-delete-account'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'owner_password': ownerPw, 'email': email}),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<Map<String, dynamic>> adminSetHelper(
      String ownerPw, String email, bool promote) async {
    final r = await http.post(
      _u('/api/admin-set-helper'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'owner_password': ownerPw, 'email': email, 'promote': promote}),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Future<Map<String, dynamic>> adminCreateCode(String ownerPw, int? days) async {
    final r = await http.post(
      _u('/api/admin-create-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'owner_password': ownerPw, 'days': days}),
    ).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final data = jsonDecode(r.body);
      if (data is Map<String, dynamic>) return data;
      return {'ok': false, 'error': 'unexpected_response'};
    } catch (_) {
      return {'ok': false, 'error': 'http_${r.statusCode}'};
    }
  }
}
