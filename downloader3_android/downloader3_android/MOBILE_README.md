# 💜 Downloader<3 — Android-App

## Ehrlicher Stand: was hier drin ist, und was noch fehlt

**Fertig (echt an den Server angebunden, nicht nur Optik):**
- Registrieren / Login (server-seitig, gegen dasselbe `premium-backend`
  wie die Windows-App — ein Konto funktioniert auf beiden Geräten)
- E-Mail-Bestätigung per 6-stelligem Code, inkl. dem "Spam-Ordner
  prüfen"-Hinweis von v1.9.65
- Passwort vergessen
- Premium-Status anzeigen + Code einlösen
- **Datei senden** per E-Mail (bis 6 MB direkter Anhang, wie
  `SMALL_ATTACH_LIMIT` am Server — der gofile.io-Upload-Weg für größere
  Dateien fehlt hier noch, siehe unten)
- **Helfer-Ehrentafel**: öffentliche Liste + eigenen Anzeigenamen
  setzen/entfernen (nur für Helfer-Konten, serverseitig geprüft)
- **KI-Studio**: Text-, Bild- und Video-Generierung über den
  gemeinsamen Gemini-Schlüssel des Servers
- **Admin-Bereich** (nur für deine beiden Owner-E-Mails sichtbar,
  zusätzlich per Owner-Passwort geschützt): Premium schenken/entziehen,
  Konten löschen, zum Helfer befördern/zurückstufen, Geschenk-Codes
  erstellen, alle Konten auflisten
- **Einstellungen**: Sprache, Akzentfarbe (live, ohne Neustart), Update
  manuell prüfen, Kontaktformular zum Entwickler
- Sprache (DE/EN) + Akzentfarbe (dieselbe Palette wie am Desktop)
- Automatischer Update-Check gegen GitHub Releases (wie am Desktop)
- Dunkles Design, gleiche Marken-Optik (💜, Pink-Akzent, dunkler
  Hintergrund)

**NEU in dieser Runde — der echte Download-Motor ist jetzt drin:**
Der Download-Tab lädt jetzt tatsächlich Video/Audio herunter, über
dieselbe `yt-dlp`-Engine wie die Windows-App — eingebettet fürs Handy
über die gepflegte Open-Source-Bibliothek **youtubedl-android**
(`io.github.junkfood02.youtubedl-android`, Version 0.18.1, direkt von
Maven Central, kein Umweg über JitPack nötig). Die Verdrahtung:
- `android/app/src/main/kotlin/.../DownloaderPlugin.kt` — natives
  Kotlin, spricht direkt mit der Bibliothek (Initialisierung, Video-
  Titel abfragen, Download starten/abbrechen, Fortschritt melden)
- `lib/native_downloader.dart` — Dart-Brücke zu diesem nativen Code
  (Flutter `MethodChannel` + `EventChannel`)
- `lib/screens/download_tab.dart` — die eigentliche Oberfläche: Link
  einfügen, Video/Audio wählen, bei Video eine Qualität (Beste/1080p/
  720p/480p), Fortschrittsbalken live während des Downloads, danach
  Ordner öffnen

**Wichtiger Unterschied zum Rest der App — bitte unbedingt lesen:**
Alle anderen Features (Login, Datei senden, Helfer, KI-Studio, Admin)
sind reine REST-Aufrufe gegen einen Server, dessen API-Antworten ich
direkt in `app.py` nachlesen konnte — dafür brauchte es kein Rätselraten.
Der Download-Motor ist anders: er läuft nativ AUF DEM HANDY (kein
Server dazwischen), und ich konnte den Code mangels Android-Gerät/
-Emulator in dieser Cloud-Umgebung **nicht selbst kompilieren oder
testen**. Um das Risiko möglichst klein zu halten, habe ich für JEDE
verwendete Methode/jeden Klassennamen (`YoutubeDL.getInstance().init()`,
`.getInfo()`, `.execute()`, `.destroyProcessById()`, `.updateYoutubeDL()`,
das Format der Fortschritts-Rückmeldung, die Paketnamen der Imports)
gezielt in der offiziellen Bibliotheks-Dokumentation und in echten
Beispiel-Dateien der Bibliothek nachgeschaut, bevor ich sie benutzt habe
— nicht geraten. Trotzdem: das ist der bei Weitem am wenigsten
abgesicherte Teil der ganzen App, weil ihn niemand vor dir tatsächlich
ausgeführt hat. **Der erste echte Test auf einem Handy ist deshalb
besonders wichtig** — falls beim Bauen (siehe unten) oder beim ersten
Download-Versuch ein Fehler auftaucht, schick mir am besten die genaue
Meldung (Logcat-Ausgabe, falls möglich, sonst einfach was am Bildschirm
steht), dann kann ich gezielt nachbessern statt erneut zu raten — exakt
so, wie es beim file.io/gofile.io-Fall gelaufen ist.

Nicht dabei (bewusst für eine spätere Runde zurückgestellt): Speichern
in den öffentlichen "Downloads"-Ordner des Handys (aktuell landet alles
im App-eigenen Speicherbereich — immer erreichbar, ohne Berechtigungs-
Dialog, aber ein bisschen versteckter im Dateimanager), Playlist-
Unterstützung, und eine Liste "zuletzt heruntergeladen" innerhalb der
App.

## ⚠️ Wichtige technische Einschränkung, die du kennen solltest

Ich konnte die App in dieser Cloud-Umgebung **nicht selbst zu einer
fertigen .apk kompilieren** — das Flutter-SDK und die Android-Build-
Tools brauchen Zugriff auf Google-Server, die von hier aus aus
Sicherheitsgründen nicht erreichbar sind (dieselbe Einschränkung wie
neulich beim file.io/gofile.io-Test, nur diesmal für ganz andere
Server). Ich kann also den kompletten, echten Code liefern — aber
NICHT selbst "auf Knopfdruck" die fertige APK-Datei bauen und testen.

**Deshalb ist eine GitHub Action mit dabei** (`.github/workflows/build-apk.yml`):
die baut die APK automatisch in der Cloud (GitHub hat den nötigen
Internetzugriff) und hängt sie ans GitHub-Release an — dasselbe Repo
(`Lizziies/downloader3-landing`), das schon jetzt die .zip-Updates für
die Windows-App hostet. Die App selbst prüft dann automatisch gegen
genau dieses Release, ob eine neue Version da ist (siehe
`lib/update_checker.dart`) — exakt der gleiche Mechanismus wie
`check_for_updates()` in main.py am Desktop.

**Das heißt konkret für dich:**
1. Diesen Ordner in dasselbe (oder ein neues) GitHub-Repo pushen.
2. Einen Tag wie `android-v1.0.0` pushen (`git tag android-v1.0.0 && git push --tags`).
3. GitHub baut automatisch die APK und hängt sie ans Release — den
   Download-Link davon kannst du dann auf deiner Webseite verlinken.
4. Bei jedem weiteren Feature-Update: neuen Tag pushen (z. B.
   `android-v1.0.1`) — jede installierte App erkennt das automatisch
   und bietet das Update an, "weltweit", wie gewünscht.

Falls du selbst lieber lokal testen willst (Android Studio + Flutter
SDK installiert): `flutter run` im Projektordner reicht für den
Emulator/ein angeschlossenes Handy.

## Zum Download-Motor: was beim ersten Bauen zu beachten ist

`android/app/build.gradle` lädt beim ersten `flutter build apk` (bzw.
in der GitHub Action) automatisch die `youtubedl-android`-Bibliothek
inkl. FFmpeg von Maven Central herunter — kein manueller Schritt nötig,
das passiert einfach beim normalen Build. Die native Bibliothek bringt
Binärdateien für alle vier gängigen Prozessor-Architekturen mit
(`armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`), die APK wird dadurch
etwas größer als in Phase 1 (grob geschätzt 30–60 MB zusätzlich,
je nach ausgelieferten Architekturen).

## Play Store vs. eigene Webseite

Wie besprochen: **nur als APK von deiner Webseite**, nicht über den
Play Store — Video-Download-Apps verstoßen gegen Googles
Play-Richtlinien und würden dort abgelehnt/entfernt. Die
`applicationId` (`com.downloader3.app`) und die Signatur (siehe unten)
bleiben deshalb bewusst so eingerichtet, dass Nutzer die APK direkt
installieren können (einmalig "Installation aus unbekannten Quellen"
erlauben).

## Signatur (für später wichtig)

Aktuell signiert Gradle die APK automatisch mit dem Debug-Schlüssel,
falls kein eigener Keystore hinterlegt ist (reicht für erste Tests).
**Für den ersten "echten" Release** unbedingt einen eigenen Keystore
erzeugen und als GitHub-Secrets hinterlegen (`DL3_KEYSTORE_BASE64`,
`DL3_KEYSTORE_PASSWORD`, `DL3_KEY_ALIAS`, `DL3_KEY_PASSWORD`) — sonst
kann ein späteres Update mit anderem Debug-Key nicht sauber "über" die
alte App installiert werden (Android verlangt für Updates dieselbe
Signatur wie beim ersten Install).

```
keytool -genkey -v -keystore dl3-release.keystore -alias downloader3 \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 dl3-release.keystore > keystore_base64.txt
```
Den Inhalt von `keystore_base64.txt` dann als Secret
`DL3_KEYSTORE_BASE64` im GitHub-Repo hinterlegen.
