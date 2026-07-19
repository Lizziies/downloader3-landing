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

AppAccent get accent {
    if (store.matchingModeEnabled && store.matchingModeBaseColorValue != null) {
      return generateMatchingAccent(Color(store.matchingModeBaseColorValue!));
    }
    return kAccents.firstWhere((a) => a.name == store.accent,
        orElse: () => kAccents[0]);
  }

  void setAccent(String name) {
    store.matchingModeEnabled = false;
    store.accent = name;
    notifyListeners();
  }

  // 🎨 Matching Mode: leitet aus einer frei gewählten Basisfarbe ein
  // passendes Akzent-Paar ab (siehe theme.dart generateMatchingAccent) und
  // macht es zum aktiven Akzent, ohne die vorherige Preset-Auswahl zu
  // verlieren (store.accent bleibt unverändert, damit reset() dahin
  // zurückkehren kann).
  void setMatchingAccent(Color base) {
    store.matchingModeBaseColorValue = base.value;
    store.matchingModeEnabled = true;
    notifyListeners();
  }

  void resetMatchingMode() {
    store.matchingModeEnabled = false;
    notifyListeners();
  }

  // 🔤 Schriftart & Größe (siehe theme.dart kFontOptions/resolveFontFamily).
  String get fontFamily => store.fontFamily;
  void setFontFamily(String key) {
    store.fontFamily = key;
    notifyListeners();
  }

  double get fontSizeScale => store.fontSizeScale;
  void setFontSizeScale(double v) {
    store.fontSizeScale = v;
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
