import 'package:flutter/material.dart';
import 'auth_store.dart';
import 'api_client.dart';
import 'strings.dart';
import 'theme.dart';

/// 🧠 Zentraler App-Zustand (Login, Sprache, Akzentfarbe, Owner-Modus).
/// Ersetzt das vorherige "store+accent+callback durch jeden Konstruktor
/// reichen"-Muster aus Phase 1 -- jetzt können z. B. die Einstellungen
/// die Akzentfarbe ändern und JEDER Screen aktualisiert sich sofort,
/// ohne dass die App neu gestartet werden muss.
class AppState extends ChangeNotifier {
  final AuthStore store;
  AppState(this.store);

  AppAccent get accent =>
      kAccents.firstWhere((a) => a.name == store.accent,
          orElse: () => kAccents[0]);

  void setAccent(String name) {
    store.accent = name;
    notifyListeners();
  }

  String get language => store.language;
  void toggleLanguage() {
    store.language = store.language == 'de' ? 'en' : 'de';
    notifyListeners();
  }

  AppStrings get s => AppStrings(store.language);
  String t(String key) => s.t(key);

  ApiClient get api => ApiClient(store.backendUrl);

  String? get currentEmail => store.currentEmail;
  bool get isPremium => store.isPremium;

  // 👑 Owner-Modus: nach einer erfolgreichen /api/verify-owner-Prüfung
  // wird das Owner-Passwort lokal auf DIESEM Gerät gemerkt (genau wie
  // am Desktop), damit nicht bei jeder Admin-Aktion neu gefragt werden
  // muss -- die eigentliche Prüfung/Berechtigung liegt ohnehin serverseitig.
  String? get ownerPassword => store.prefs.getString('owner_password');
  bool get isOwnerUnlocked => ownerPassword != null;
  Future<void> setOwnerPassword(String? pw) async {
    if (pw == null) {
      await store.prefs.remove('owner_password');
    } else {
      await store.prefs.setString('owner_password', pw);
    }
    notifyListeners();
  }

  Future<void> refreshPremiumStatus() async {
    final email = currentEmail;
    if (email == null) return;
    try {
      final status = await api.accountStatus(email);
      await store.setPremium(
        status['premium_until'] as String?,
        status['role'] as String?,
      );
      notifyListeners();
    } catch (_) {
      // Offline -> mit zuletzt bekanntem Stand weitermachen.
    }
  }

  Future<void> logout() async {
    await store.logout();
    await setOwnerPassword(null);
    notifyListeners();
  }
}
