import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// 📦 Lokaler Speicher auf dem Gerät (SharedPreferences) — Pendant zur
/// JSON-Datei der Desktop-App (Store-Klasse in main.py). Das eigentliche
/// Konto (E-Mail+Passwort+Premium) lebt server-seitig im gemeinsamen
/// premium-backend, hier wird nur der lokale Zustand für DIESES Gerät
/// gehalten (eingeloggt bleiben, Sprache, Akzentfarbe, Verifizierungs-
/// Code-Zwischenspeicher).
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

// 🌍 Standardmäßig Englisch für alle -- ausdrücklicher Nutzerwunsch,
// unabhängig vom Geräte-Locale. In den Einstellungen jederzeit auf
// Deutsch umschaltbar, wird dann dauerhaft gespeichert.
String get language => prefs.getString(_kLang) ?? 'en';
set language(String v) => prefs.setString(_kLang, v);

String get accent => prefs.getString(_kAccent) ?? 'Pink';
set accent(String v) => prefs.setString(_kAccent, v);

// 🌍 Standard zeigt auf denselben Server, den auch die Desktop-App
// per Voreinstellung nutzt (premium-backend auf Render) — kann in den
// Einstellungen später überschrieben werden, genau wie am Desktop.
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

// --- ⭐ Favoriten (Pendant zu store.data["favorites"] am Desktop) -----
static const _kFavorites = 'favorites';

List<Map<String, String>> get favorites {
final raw = prefs.getString(_kFavorites);
if (raw == null || raw.isEmpty) return [];
try {
final list = jsonDecode(raw) as List;
return list
.map((e) => (e as Map).map(
(k, v) => MapEntry(k.toString(), v.toString())))
.toList();
} catch (_) {
return [];
}
}

Future<void> _saveFavorites(List<Map<String, String>> favs) async {
await prefs.setString(_kFavorites, jsonEncode(favs));
}

/// Fügt einen Favoriten hinzu (überspringt, falls die URL schon
/// gespeichert ist -- exakt wie am Desktop).
Future<void> addFavorite(String name, String url) async {
final favs = favorites;
if (favs.any((f) => f['url'] == url)) return;
favs.add({'name': name, 'url': url});
await _saveFavorites(favs);
}

Future<void> removeFavorite(String url) async {
final favs = favorites..removeWhere((f) => f['url'] == url);
await _saveFavorites(favs);
}

// --- 🕓 Verlauf (Pendant zu store.data["history"] am Desktop) ---------
static const _kHistory = 'history';

/// Neueste zuerst (schon in Anzeige-Reihenfolge, anders als am
/// Desktop, wo erst beim Rendern umgedreht wird).
List<Map<String, dynamic>> get history {
final raw = prefs.getString(_kHistory);
if (raw == null || raw.isEmpty) return [];
try {
final list = jsonDecode(raw) as List;
return list
.map((e) => (e as Map).cast<String, dynamic>())
.toList()
.reversed
.toList();
} catch (_) {
return [];
}
}

/// Merkt sich einen abgeschlossenen Download -- genau wie
/// Store.add_history() am Desktop, auf die letzten 200 Einträge
/// gekappt. `platform`/`bytes` sind optional (bestehende Aufrufer
/// müssen nicht angepasst werden), fließen aber -- falls angegeben --
/// zusätzlich in die lifetime-Statistik ein (siehe unten), die anders
/// als die Verlaufsliste NICHT gekappt wird (Pendant zu
/// store.data["stats"] am Desktop).
Future<void> addHistoryEntry(
{required String file,
String? url,
String? platform,
int? bytes}) async {
final raw = prefs.getString(_kHistory);
List list = [];
if (raw != null && raw.isNotEmpty) {
try {
list = jsonDecode(raw) as List;
} catch (_) {
list = [];
}
}
list.add({
'file': file,
'url': url ?? '',
'date': DateTime.now().toIso8601String(),
'platform': platform ?? 'other',
'bytes': bytes ?? 0,
});
if (list.length > 200) {
list = list.sublist(list.length - 200);
}
await prefs.setString(_kHistory, jsonEncode(list));
await _bumpStats(platform ?? 'other', bytes ?? 0);
}

// --- 📊 Lifetime-Statistik (Pendant zu store.data["stats"] am Desktop,
// NICHT auf 200 Einträge gekappt wie der Verlauf oben). -----------------
static const _kStatsFiles = 'stats_total_files';
static const _kStatsBytes = 'stats_total_bytes';
static const _kStatsPlatforms = 'stats_platforms';

int get statsTotalFiles => prefs.getInt(_kStatsFiles) ?? 0;
int get statsTotalBytes => prefs.getInt(_kStatsBytes) ?? 0;

Map<String, int> get statsPlatforms {
final raw = prefs.getString(_kStatsPlatforms);
if (raw == null || raw.isEmpty) return {};
try {
final m = jsonDecode(raw) as Map;
return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
} catch (_) {
return {};
}
}

/// Häufigste Download-Quelle, oder null falls noch keine Daten da sind
/// (Pendant zu max(platforms, key=platforms.get) am Desktop).
String? get topPlatform {
final p = statsPlatforms;
if (p.isEmpty) return null;
var best = p.keys.first;
for (final k in p.keys) {
if (p[k]! > p[best]!) best = k;
}
return best;
}

Future<void> _bumpStats(String platform, int bytes) async {
await prefs.setInt(_kStatsFiles, statsTotalFiles + 1);
await prefs.setInt(_kStatsBytes, statsTotalBytes + bytes);
final p = statsPlatforms;
p[platform] = (p[platform] ?? 0) + 1;
await prefs.setString(_kStatsPlatforms, jsonEncode(p));
}

// --- Verifizierungs-Code (lokal pro Gerät, wie am Desktop) ------------
String _vKeyHash(String email) => 'vcode_hash_$email';
String _vKeyExp(String email) => 'vcode_exp_$email';

/// Erzeugt einen neuen 6-stelligen Code, speichert dessen Hash lokal
/// (15 Minuten gültig) und gibt den Klartext-Code zum Versand zurück.
String startVerification(String email) {
final code = (100000 + Random.secure().nextInt(900000)).toString();
final hash = sha256.convert(utf8.encode('vcode::$code')).toString();
final expires = DateTime.now().add(const Duration(minutes: 15));
prefs.setString(_vKeyHash(email), hash);
prefs.setString(_vKeyExp(email), expires.toIso8601String());
return code;
}

/// Gibt 'ok' / 'expired' / 'wrong' zurück — analog zu
/// Store.check_verification() am Desktop.
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
