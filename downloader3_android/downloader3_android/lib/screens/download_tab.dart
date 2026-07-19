import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../app_state.dart';
import '../native_downloader.dart';
import '../theme.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// ⬇️ Pendant zu page_download() in main.py -- echter Download-Motor
/// über DownloaderPlugin.kt / native_downloader.dart (yt-dlp+ffmpeg,
/// nativ ins Handy eingebettet über die youtubedl-android-Bibliothek).
///
/// Diese Version bringt die Plattform-/Format-/Auflösungs-Auswahl,
/// Playlist/Kanal-Download, den Mehrfach-Link-Warteschlangen-Modus
/// sowie Statistik-Zeile sind CSV-Export 1:1 nach dem Vorbild der
/// Desktop-Seite mit (siehe MOBILE_README.md). Bewusst NICHT mit
/// portiert in dieser Runde: Wallpaper-Modus, Untertitel, Ausschnitt/
/// Zeitplan-Download, Kanal-Abos und Cloud-Sync -- das sind größere,
/// eigenständige Baustellen für eine der nächsten Runden.
class DownloadTab extends StatefulWidget {
final AppState state;
const DownloadTab({super.key, required this.state});

@override
State<DownloadTab> createState() => _DownloadTabState();
}

/// 🎛️ Eine Zeile im Plattform-Dropdown -- Pendant zum
/// plat_label()/_plat_by_label-Muster in main.py.
class _PlatformOption {
final String key;
final String labelDe;
final String labelEn;
final bool premiumOnly;
const _PlatformOption(this.key, this.labelDe, this.labelEn, this.premiumOnly);
}

const List<_PlatformOption> _kPlatforms = [
_PlatformOption('ai', '🤖 KI-Modus (automatisch)', '🤖 AI mode (automatic)', true),
_PlatformOption('youtube', '▶ YouTube', '▶ YouTube', false),
_PlatformOption('tiktok', '🎵 TikTok', '🎵 TikTok', false),
_PlatformOption('instagram', '📷 Instagram', '📷 Instagram', false),
_PlatformOption('facebook', '📘 Facebook', '📘 Facebook', false),
_PlatformOption('browser', '🌐 Web-Browser (beliebiger Link)', '🌐 Web browser (any link)', true),
_PlatformOption('direct', '🔗 Direkt-Link', '🔗 Direct link', true),
];

/// 📐 Auflösungsliste -- 1:1 aus RES_LIST/RES_HEIGHT/RES_FREE_SET
/// (main.py, Zeilen ~126-139) übernommen.
const List<String> _kResList = ['480p', '720p', '1080p', '1440p', '4K'];
const Set<String> _kResFree = {'480p', '720p', '1080p'};
const Map<String, int> _kResHeight = {
'480p': 480,
'720p': 720,
'1080p': 1080,
'1440p': 1440,
'4K': 2160,
};

/// 🎞️ Format-Listen pro Plattform -- 1:1 aus PLATFORM_FORMATS
/// (main.py) übernommen, beschränkt auf die Endungen, die der
/// native yt-dlp/ffmpeg-Motor auf dem Handy tatsächlich erzeugen
/// kann (Bild-Endungen wie jpg/png/gif sind bewusst ausgeklammert --
/// die bräuchten einen eigenen Thumbnail-Extraktionspfad).
const Map<String, List<String>> _kPlatformFreeFormats = {
'youtube': ['mp4', 'mp3'],
'tiktok': ['mp4', 'mp3'],
'instagram': ['mp4', 'mp3'],
'facebook': ['mp4', 'mp3'],
};
const Map<String, List<String>> _kPlatformPremiumFormats = {
'youtube': ['wav', 'm4a', 'aac', 'flac', 'ogg', 'webm', 'mkv', 'mov'],
'tiktok': ['wav', 'mov', 'webm'],
'instagram': ['wav', 'm4a', 'webm', 'mov'],
'facebook': ['wav', 'webm', 'mov'],
};
const Set<String> _kAudioExts = {'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'};

class _DownloadTabState extends State<DownloadTab> {
final urlCtl = TextEditingController();
final playlistUrlCtl = TextEditingController();
final batchCtl = TextEditingController();
final historySearchCtl = TextEditingController();

String platform = 'youtube'; // interner Key, siehe _kPlatforms
String resolution = '720p'; // Anzeige-Wert aus _kResList, oder 'auto'
String format = 'mp4';
bool playlistMode = false;
bool batchMode = false;
bool downloadSubtitles = false;

bool initializing = true;
bool initFailed = false;
bool downloading = false;
double? progress;
String? statusLine;
String? error;
String? finishedDir;
StreamSubscription? _sub;
String? _activeProcessId;
// 🔗 Die URL, die GERADE aktiv heruntergeladen wird -- getrennt vom
// Eingabefeld gehalten, weil beim Warteschlangen-Modus das
// Eingabefeld gar nicht sichtbar/aktuell ist, der Verlaufseintrag
// aber trotzdem die richtige Einzel-URL bekommen muss.
String _currentUrl = '';

// 📋 Warteschlangen-Zustand (Pendant zu _queue/_queue_total/... am
// Desktop -- hier bewusst SEQUENZIELL statt parallel abgearbeitet,
// das ist auf einem Handy schonender für Akku/Netz/Speicher als der
// Multi-Thread-Ansatz der Desktop-App).
List<String> _queue = [];
int _queueTotal = 0;
int _queueDone = 0;
bool _queueActive = false;

AppState get st => widget.state;
bool get isDe => st.language == 'de';

@override
void initState() {
super.initState();
_init();
_sub = NativeDownloader.progressStream.listen(_onEvent);
}

@override
void dispose() {
_sub?.cancel();
playlistUrlCtl.dispose();
batchCtl.dispose();
historySearchCtl.dispose();
super.dispose();
}

Future<void> _init() async {
final ok = await NativeDownloader.init();
if (!mounted) return;
setState(() {
initializing = false;
initFailed = !ok;
});
}

void _onEvent(Map<String, dynamic> e) {
if (e['processId'] != _activeProcessId) return;
if (!mounted) return;
switch (e['event']) {
case 'progress':
// 📋 Genau wie am Desktop (_progress_hook) wird der Live-Balken
// während eines Warteschlangen-Laufs NICHT pro Einzeldatei
// aktualisiert -- nur der Sammel-Fortschritt done/total zählt,
// sonst flackert die Anzeige bei mehreren Downloads wild hin
// und her.
if (_queueActive) return;
setState(() {
final p = e['progress'];
progress = p is num ? p.toDouble() / 100 : null;
statusLine = e['line'] as String?;
});
break;
case 'done':
final file = (e['outputFile'] as String?) ?? (e['outputDir'] as String?);
final bytes = e['size'];
if (file != null) {
st.store.addHistoryEntry(
file: file,
url: _currentUrl,
platform: _detectPlatform(_currentUrl),
bytes: bytes is num ? bytes.toInt() : null,
);
}
if (!_queueActive) {
setState(() {
downloading = false;
progress = 1.0;
finishedDir = e['outputDir'] as String?;
});
}
break;
case 'error':
if (!_queueActive) {
setState(() {
downloading = false;
error = e['error'] as String?;
});
}
break;
}
}

/// 🔎 Grobe URL->Plattform-Erkennung -- Pendant zu PLATFORM_URL_RE am
/// Desktop, für Statistik-Zwecke und den Warteschlangen-Modus (der,
/// genau wie am Desktop, Plattformen automatisch aus der URL
/// erschließt statt eine feste Auswahl zu verlangen).
String _detectPlatform(String url) {
final u = url.toLowerCase();
if (u.contains('youtube.com') || u.contains('youtu.be')) return 'youtube';
if (u.contains('tiktok.com')) return 'tiktok';
if (u.contains('instagram.com')) return 'instagram';
if (u.contains('facebook.com') || u.contains('fb.watch')) return 'facebook';
return 'other';
}

void _useFavorite(String url) {
setState(() => urlCtl.text = url);
}

/// 🔒 Pendant zu show_premium_dialog() am Desktop -- schlichter, aber
/// klar erklärender Hinweis statt eines vollen Bezahl-Flows (der lebt
/// bereits im Premium-Tab).
Future<void> _showPremiumLockedDialog() async {
await showDialog(
context: context,
builder: (ctx) => AlertDialog(
backgroundColor: kCardDark,
title: Text('⭐ ${isDe ? "Premium-Feature" : "Premium feature"}',
style: TextStyle(color: st.accent.main)),
content: Text(
isDe
? 'Diese Option ist nur mit Premium verfügbar. Du findest den Freischalt-Bereich oben in der Navigation unter "Premium".'
: 'This option is only available with Premium. You can unlock it from the "Premium" tab in the navigation above.',
style: const TextStyle(color: Colors.white),
),
actions: [
TextButton(
onPressed: () => Navigator.of(ctx).pop(),
child: const Text('OK'),
),
],
),
);
}

String _platformLabel(_PlatformOption p) {
final base = isDe ? p.labelDe : p.labelEn;
final locked = p.premiumOnly && !st.isPremium;
return locked ? '$base 🔒' : base;
}

Future<void> _onPlatformChanged(String? key) async {
if (key == null) return;
final opt = _kPlatforms.firstWhere((p) => p.key == key,
orElse: () => _kPlatforms[1]);
if (opt.premiumOnly && !st.isPremium) {
await _showPremiumLockedDialog();
setState(() => platform = 'youtube');
return;
}
setState(() {
platform = key;
if (key == 'ai') {
// 🤖 KI-Modus wählt intern immer die beste Qualität -- die
// Auflösungs-Auswahl wird deaktiviert, genau wie am Desktop.
resolution = 'auto';
format = 'mp4';
} else {
if (resolution == 'auto') resolution = '720p';
final free = _kPlatformFreeFormats[key] ?? const ['mp4'];
format = free.first;
}
});
}

List<String> _formatOptionsFor(String key) {
if (key == 'ai' || key == 'browser' || key == 'direct') {
// 🤖/🌐/🔗 Auto-Format -- der native Motor erkennt Container/Codec
// selbst; eine feste Liste würde hier nur verwirren.
return ['auto'];
}
final free = _kPlatformFreeFormats[key] ?? const ['mp4'];
final premium = _kPlatformPremiumFormats[key] ?? const [];
return [...free, ...premium];
}

Future<void> _onFormatChanged(String? f) async {
if (f == null) return;
final free = _kPlatformFreeFormats[platform] ?? const ['mp4'];
if (!free.contains(f) && f != 'auto' && !st.isPremium) {
await _showPremiumLockedDialog();
return;
}
setState(() => format = f);
}

Future<void> _onResolutionChanged(String? r) async {
if (r == null) return;
if (!_kResFree.contains(r) && !st.isPremium) {
await _showPremiumLockedDialog();
return;
}
setState(() => resolution = r);
}

Future<void> _onPlaylistToggled(bool v) async {
if (v && !st.isPremium) {
await _showPremiumLockedDialog();
return;
}
setState(() {
playlistMode = v;
if (v) batchMode = false; // 🔀 gegenseitig ausschließend, wie am Desktop
});
}

// 📶 WiFi-Priorität/Mobilfunk-Vorab-Check (Pendant zu den neuen Einstellungen
// im Settings-Tab): blockiert den Downloadstart, wenn gerade nur mobile
// Daten verfügbar sind UND der Nutzer das in den Einstellungen deaktiviert
// hat. "wifiPriority" selbst wird bewusst NICHT hier ausgewertet -- ohne
// eigenes Netzwerk-Binding (siehe Kommentar in AuthStore) gibt es hier
// nichts Sinnvolles zu erzwingen, das Betriebssystem entscheidet ohnehin
// selbst, welche Schnittstelle genutzt wird.
Future<bool> _checkMobileDataAllowed() async {
final results = await Connectivity().checkConnectivity();
final isMobile = results.contains(ConnectivityResult.mobile);
if (isMobile && !st.store.mobileDataAllowed) {
if (!mounted) return false;
await showDialog(
context: context,
builder: (ctx) => AlertDialog(
backgroundColor: kCardDark,
title: Text('📶 ${isDe ? "Mobile Daten" : "Mobile data"}',
style: TextStyle(color: st.accent.main)),
content: Text(
st.t('download_blocked_mobile_data'),
style: const TextStyle(color: Colors.white),
),
actions: [
TextButton(
onPressed: () => Navigator.of(ctx).pop(),
child: const Text('OK'),
),
],
),
);
return false;
}
return true;
}

Future<void> _onBatchToggled(bool v) async {
if (v && !st.isPremium) {
await _showPremiumLockedDialog();
return;
}
setState(() {
batchMode = v;
if (v) playlistMode = false;
});
}

Future<void> _startDownload() async {
if (batchMode) {
await _startQueue();
return;
}
final url = playlistMode ? playlistUrlCtl.text.trim() : urlCtl.text.trim();
if (url.isEmpty) return;
if (!await _checkMobileDataAllowed()) return;
_currentUrl = url;
setState(() {
downloading = true;
progress = 0;
statusLine = null;
error = null;
finishedDir = null;
});
try {
final isAudio = _kAudioExts.contains(format);
final height = resolution == 'auto' ? null : _kResHeight[resolution];
final processId = await NativeDownloader.startDownload(
url: url,
isAudio: isAudio,
format: format,
height: height,
playlist: playlistMode,
downloadSubtitles: downloadSubtitles,
);
_activeProcessId = processId;
} catch (e) {
setState(() {
downloading = false;
error = e.toString();
});
}
}

/// 📋 Warteschlangen-Modus -- Pendant zu start_download()'s
/// Batch-Zweig + _process_queue()/_queue_worker() am Desktop, hier
/// bewusst sequenziell statt mit mehreren Worker-Threads (siehe
/// Kommentar oben bei den Feldern).
Future<void> _startQueue() async {
final urls = batchCtl.text
.split('\n')
.map((l) => l.trim())
.where((l) => l.isNotEmpty)
.toList();
if (urls.isEmpty) return;
if (!await _checkMobileDataAllowed()) return;
setState(() {
_queue = List.of(urls);
_queueTotal = urls.length;
_queueDone = 0;
_queueActive = true;
downloading = true;
progress = 0;
error = null;
finishedDir = null;
statusLine = isDe
? '📋 Warteschlange: $_queueDone/$_queueTotal'
: '📋 Queue: $_queueDone/$_queueTotal';
});
for (final url in _queue) {
_currentUrl = url;
try {
final autoPlatform = _detectPlatform(url);
final isAudio = _kAudioExts.contains(format);
final free = _kPlatformFreeFormats[autoPlatform] ?? const ['mp4'];
final safeFormat =
(isAudio || free.contains(format) || st.isPremium) ? format : 'mp4';
final processId = await NativeDownloader.startDownload(
url: url,
isAudio: isAudio,
format: safeFormat,
height: (_kResFree.contains(resolution) || st.isPremium)
? _kResHeight[resolution]
: _kResHeight['1080p'],
// 📋 Warteschlangen-Einträge sind am Desktop IMMER
// Einzel-Downloads, nie Playlists (siehe _download_one_sync).
playlist: false,
downloadSubtitles: downloadSubtitles,
);
_activeProcessId = processId;
await _waitForCompletion(processId);
} catch (_) {
// ⚠️ Ein Fehler bei einer URL darf die restliche Warteschlange
// nicht stoppen -- exakt wie am Desktop (Exceptions pro Item
// werden verschluckt).
}
if (!mounted) return;
setState(() {
_queueDone++;
progress = _queueTotal == 0 ? 0 : _queueDone / _queueTotal;
statusLine = isDe
? '📋 Warteschlange: $_queueDone/$_queueTotal'
: '📋 Queue: $_queueDone/$_queueTotal';
});
}
if (!mounted) return;
setState(() {
_queueActive = false;
downloading = false;
statusLine = isDe ? '✓ Warteschlange fertig!' : '✓ Queue finished!';
});
}

Future<void> _waitForCompletion(String? processId) async {
if (processId == null) return;
final completer = Completer<void>();
late final StreamSubscription sub;
sub = NativeDownloader.progressStream.listen((e) {
if (e['processId'] != processId) return;
if (e['event'] == 'done' || e['event'] == 'error') {
if (!completer.isCompleted) completer.complete();
}
});
try {
await completer.future.timeout(const Duration(minutes: 30));
} catch (_) {
// ⏱️ Sicherheitsnetz, falls ein Item ungewöhnlich lang hängt --
// die Warteschlange macht trotzdem mit dem nächsten Link weiter.
} finally {
await sub.cancel();
}
}

void _showFavoritesFromField() => _showFavoritesDialog();

Future<void> _showFavoritesDialog() async {
final nameCtl = TextEditingController();
final urlFieldCtl = TextEditingController(text: urlCtl.text.trim());
String? favError;

await showDialog(
context: context,
builder: (ctx) {
return StatefulBuilder(builder: (ctx, setDialogState) {
final favs = st.store.favorites;
return AlertDialog(
backgroundColor: kCardDark,
title: Text('⭐ ${st.t('favorites')}',
style: TextStyle(color: st.accent.main)),
content: SizedBox(
width: 360,
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
TextField(
controller: urlFieldCtl,
decoration:
InputDecoration(hintText: st.t('favorite_url_ph')),
),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: TextField(
controller: nameCtl,
decoration: InputDecoration(
hintText: st.t('favorite_name_ph')),
),
),
const SizedBox(width: 8),
ElevatedButton(
onPressed: () async {
final url = urlFieldCtl.text.trim();
if (url.isEmpty) {
setDialogState(
() => favError = st.t('favorite_url_missing'));
return;
}
final name = nameCtl.text.trim().isNotEmpty
? nameCtl.text.trim()
: (url.length > 40 ? url.substring(0, 40) : url);
await st.store.addFavorite(name, url);
nameCtl.clear();
setDialogState(() => favError = null);
},
child: Text(st.t('add_favorite')),
),
],
),
if (favError != null) ...[
const SizedBox(height: 4),
Text(favError!,
style: const TextStyle(
color: Color(0xFFF87171), fontSize: 11)),
],
const SizedBox(height: 10),
SizedBox(
height: 240,
child: favs.isEmpty
? Center(
child: Text(st.t('no_favorites'),
style: const TextStyle(color: kMuted)))
: ListView.builder(
itemCount: favs.length,
itemBuilder: (ctx, i) {
final f = favs[i];
return ListTile(
dense: true,
title: Text('🔗 ${f['name']}',
style:
const TextStyle(color: Colors.white),
overflow: TextOverflow.ellipsis),
onTap: () {
_useFavorite(f['url'] ?? '');
Navigator.of(ctx).pop();
},
trailing: IconButton(
icon: const Icon(Icons.close,
color: Color(0xFFF87171), size: 18),
onPressed: () async {
await st.store.removeFavorite(f['url'] ?? '');
setDialogState(() {});
},
),
);
},
),
),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.of(ctx).pop(),
child: const Text('OK'),
),
],
);
});
},
);
if (mounted) setState(() {});
}

/// 📄 CSV-Export -- Pendant zur export_csv-Funktion am Desktop
/// (gleiche Spalten: Datum, Datei, URL, Größe in Bytes).
Future<void> _exportCsv() async {
final rows = <String>['Date,File,URL,Size (bytes)'];
for (final h in st.store.history) {
final date = (h['date'] as String? ?? '').replaceAll('T', ' ');
final name = _historyName(h['file'] as String? ?? '');
final url = h['url'] as String? ?? '';
final size = (h['bytes'] is num) ? (h['bytes'] as num).toInt() : 0;
rows.add(
'${_csv(date)},${_csv(name)},${_csv(url)},$size',
);
}
final csvText = rows.join('\n');
try {
// 📱 file_selector's Speichern-Dialog wird auf Android NICHT unterstützt
// (nur Desktop/Web) -- deshalb wird die CSV, genau wie die Downloads
// selbst, direkt in den App-Ordner geschrieben (kein Dialog nötig).
final base = await getExternalStorageDirectory() ??
await getApplicationDocumentsDirectory();
final outDir = Directory('${base.path}/Downloads');
if (!await outDir.exists()) {
await outDir.create(recursive: true);
}
final fileName =
'downloader3_verlauf_${DateTime.now().millisecondsSinceEpoch}.csv';
final file = File('${outDir.path}/$fileName');
await file.writeAsString(csvText);
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(isDe
? '✓ CSV gespeichert: $fileName'
: '✓ CSV saved: $fileName'),
action: SnackBarAction(
label: isDe ? 'Öffnen' : 'Open',
onPressed: () => OpenFilex.open(file.path),
),
),
);
} catch (e) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('✗ $e')),
);
}
}

String _csv(String v) {
if (v.contains(',') || v.contains('"') || v.contains('\n')) {
return '"${v.replaceAll('"', '""')}"';
}
return v;
}

@override
Widget build(BuildContext context) {
return SingleChildScrollView(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Text(st.t('download_title'),
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: st.accent.main)),
const SizedBox(height: 14),
if (initializing)
const Padding(
padding: EdgeInsets.symmetric(vertical: 20),
child: Center(child: CircularProgressIndicator()),
)
else if (initFailed)
Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: kCardDark,
borderRadius: BorderRadius.circular(14),
),
child: Column(
children: [
const Text('⚠️', style: TextStyle(fontSize: 32)),
const SizedBox(height: 8),
Text(st.t('download_not_ready_title'),
style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.bold)),
const SizedBox(height: 6),
Text(st.t('download_not_ready_desc'),
textAlign: TextAlign.center,
style: const TextStyle(color: kMuted)),
],
),
)
else ...[
_buildDownloadCard(),
const SizedBox(height: 16),
if (st.store.history.isNotEmpty) ...[
_buildStatsRow(),
const SizedBox(height: 16),
],
const Divider(color: kCardDark2, height: 24),
_buildHistorySection(),
],
],
),
);
}

Widget _buildDownloadCard() {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: kCardDark,
borderRadius: BorderRadius.circular(16),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
if (!batchMode) ...[
Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Expanded(
child: TextField(
controller: playlistMode ? playlistUrlCtl : urlCtl,
decoration: InputDecoration(
hintText: playlistMode
? (isDe
? 'Link zur Playlist oder zum Kanal einfügen...'
: 'Paste the playlist or channel link here...')
: st.t('download_url_ph')),
),
),
const SizedBox(width: 6),
IconButton(
tooltip: st.t('favorites'),
icon: Icon(Icons.star_rounded, color: st.accent.main),
onPressed: _showFavoritesFromField,
),
],
),
] else ...[
Text(
isDe
? '📋 Mehrere Links (einer pro Zeile):'
: '📋 Multiple links (one per line):',
style: const TextStyle(color: kMuted, fontSize: 12),
),
const SizedBox(height: 6),
TextField(
controller: batchCtl,
maxLines: 6,
style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
decoration: const InputDecoration(
hintText: 'https://...\nhttps://...\nhttps://...',
),
),
],
const SizedBox(height: 10),
// 🎬🎵 Schnellwahl -- Pendant zu den drei Pill-Buttons am Desktop.
Wrap(
spacing: 8,
runSpacing: 8,
children: [
OutlinedButton(
onPressed: () => setState(() => format = 'mp4'),
child: Text('🎬 ${isDe ? "Video" : "Video"}'),
),
OutlinedButton(
onPressed: () => setState(() => format = 'mp3'),
child: Text('🎵 ${isDe ? "Musik" : "Music"}'),
),
OutlinedButton(
onPressed: _showFavoritesFromField,
child: Text('⭐ ${st.t('favorites')}'),
),
],
),
const SizedBox(height: 14),
// 📡 Plattform + Auflösung nebeneinander.
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: _buildDropdown(
label: isDe ? 'Plattform' : 'Platform',
value: platform,
items: _kPlatforms
.map((p) => DropdownMenuItem(
value: p.key, child: Text(_platformLabel(p))))
.toList(),
onChanged: _onPlatformChanged,
),
),
const SizedBox(width: 10),
Expanded(
child: _buildDropdown(
label: isDe ? 'Auflösung' : 'Resolution',
value: resolution == 'auto' ? null : resolution,
enabled: platform != 'ai',
items: _kResList
.map((r) => DropdownMenuItem(
value: r,
child: Text(_kResFree.contains(r) || st.isPremium
? r
: '$r 🔒'),
))
.toList(),
onChanged: _onResolutionChanged,
hintWhenDisabled:
isDe ? '🤖 automatisch' : '🤖 automatic',
),
),
],
),
const SizedBox(height: 10),
_buildDropdown(
label: isDe ? 'Format' : 'Format',
value: _formatOptionsFor(platform).contains(format)
? format
: _formatOptionsFor(platform).first,
enabled: platform != 'ai' && platform != 'browser' && platform != 'direct',
items: _formatOptionsFor(platform)
.map((f) => DropdownMenuItem(
value: f,
child: Text(
(_kPlatformFreeFormats[platform]?.contains(f) ?? true) ||
st.isPremium
? f.toUpperCase()
: '${f.toUpperCase()} 🔒'),
))
.toList(),
onChanged: _onFormatChanged,
hintWhenDisabled: isDe ? '🤖 automatisch' : '🤖 automatic',
),
if (platform == 'ai') ...[
const SizedBox(height: 8),
Text(
isDe
? '🤖 Die KI erkennt automatisch Plattform und beste Auflösung.'
: '🤖 AI mode automatically detects platform and best quality.',
style: const TextStyle(color: kMuted, fontSize: 11),
),
],
if (!st.isPremium) ...[
const SizedBox(height: 8),
Text(
isDe
? '🔒 Nur MP4 verfügbar — hol dir Premium für alle Formate!'
: '🔒 Only MP4 available — get Premium for all formats!',
style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
),
],
const SizedBox(height: 14),
// ⚡ Erweiterte Optionen.
Container(
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
border: Border.all(color: kCardDark2),
borderRadius: BorderRadius.circular(12),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('⚡ ${isDe ? "Erweiterte Optionen" : "Advanced options"}',
style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.w600)),
const SizedBox(height: 4),
CheckboxListTile(
contentPadding: EdgeInsets.zero,
dense: true,
value: batchMode,
onChanged: (v) => _onBatchToggled(v ?? false),
title: Text(
isDe
? '📋 Mehrere Links (einer pro Zeile) — Premium'
: '📋 Multiple links (one per line) — Premium',
style: const TextStyle(color: Colors.white, fontSize: 13),
),
controlAffinity: ListTileControlAffinity.leading,
),
CheckboxListTile(
contentPadding: EdgeInsets.zero,
dense: true,
value: playlistMode,
onChanged: (v) => _onPlaylistToggled(v ?? false),
title: Text(
isDe
? '📺 Ganze Playlist/Kanal laden (Premium)'
: '📺 Download whole playlist/channel (Premium)',
style: const TextStyle(color: Colors.white, fontSize: 13),
),
controlAffinity: ListTileControlAffinity.leading,
),
CheckboxListTile(
contentPadding: EdgeInsets.zero,
dense: true,
value: downloadSubtitles,
onChanged: (v) => setState(() => downloadSubtitles = v ?? false),
title: Text(
st.t('download_subtitles_label'),
style: const TextStyle(color: Colors.white, fontSize: 13),
),
controlAffinity: ListTileControlAffinity.leading,
),
],
),
),
const Divider(color: kCardDark2, height: 28),
Row(
children: [
Expanded(
child: ElevatedButton(
onPressed: downloading ? null : _startDownload,
child: Text(downloading
? '${((progress ?? 0) * 100).toStringAsFixed(0)}%'
: '⬇ ${st.t('nav_download')}'),
),
),
],
),
if (downloading) ...[
const SizedBox(height: 10),
LinearProgressIndicator(value: progress),
if (statusLine != null) ...[
const SizedBox(height: 6),
Text(statusLine!,
style: const TextStyle(color: kMuted, fontSize: 11),
maxLines: 2,
overflow: TextOverflow.ellipsis),
],
],
if (error != null) ...[
const SizedBox(height: 10),
Text('✗ $error', style: const TextStyle(color: Color(0xFFF87171))),
],
if (finishedDir != null) ...[
const SizedBox(height: 14),
Container(
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: kCardDark2,
borderRadius: BorderRadius.circular(12),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text('✓ Fertig! 🎉',
style: TextStyle(
color: Color(0xFF34D399),
fontWeight: FontWeight.bold)),
const SizedBox(height: 6),
Text(finishedDir!,
style: const TextStyle(color: kMuted, fontSize: 11)),
const SizedBox(height: 8),
OutlinedButton.icon(
onPressed: () => OpenFilex.open(finishedDir!),
icon: const Icon(Icons.folder_open),
label: const Text('📂'),
),
],
),
),
],
],
),
);
}

Widget _buildDropdown({
required String label,
required String? value,
required List<DropdownMenuItem<String>> items,
required ValueChanged<String?> onChanged,
bool enabled = true,
String? hintWhenDisabled,
}) {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
const SizedBox(height: 4),
Container(
padding: const EdgeInsets.symmetric(horizontal: 12),
decoration: BoxDecoration(
color: kCardDark2,
borderRadius: BorderRadius.circular(12),
),
child: !enabled
? Text(hintWhenDisabled ?? '—',
style: const TextStyle(color: kMuted))
: DropdownButtonHideUnderline(
child: DropdownButton<String>(
isExpanded: true,
value: value,
items: items,
onChanged: onChanged,
dropdownColor: kCardDark2,
style: const TextStyle(color: Colors.white, fontSize: 13),
),
),
),
],
);
}

/// 📊 Statistik-Zeile -- Pendant zur stats_row am Desktop (nur
/// sichtbar, sobald es mindestens einen Verlaufseintrag gibt).
Widget _buildStatsRow() {
final files = st.store.statsTotalFiles;
final bytes = st.store.statsTotalBytes;
final top = st.store.topPlatform;
final sizeText = bytes / (1024 * 1024 * 1024) >= 1
? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB'
: '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
final topText = top == null
? '—'
: top[0].toUpperCase() + top.substring(1);
return Row(
children: [
Expanded(
child: Text(
isDe
? '📊 $files Downloads insgesamt  ·  $sizeText  ·  Häufigste Quelle: $topText'
: '📊 $files total downloads  ·  $sizeText  ·  Most-used source: $topText',
style: const TextStyle(color: kMuted, fontSize: 11),
),
),
OutlinedButton(
onPressed: _exportCsv,
child: Text(
isDe ? '📄 CSV exportieren' : '📄 Export CSV',
style: const TextStyle(fontSize: 11),
),
),
],
);
}

// 🕓 Verlauf mit Such-/Filterfunktion -- Pendant zum History-Abschnitt
// unten in page_download() am Desktop (Sortierung neueste zuerst kommt
// schon aus AuthStore.history, wird hier also nicht nochmal gedreht).
Widget _buildHistorySection() {
final all = st.store.history;
final query = historySearchCtl.text.trim().toLowerCase();
final filtered = query.isEmpty
? all
: all.where((h) {
final name = _historyName(h['file'] as String? ?? '');
return name.toLowerCase().contains(query);
}).toList();

return Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Text('🕓 ${st.t('history')}',
style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
const SizedBox(height: 8),
if (all.isNotEmpty) ...[
TextField(
controller: historySearchCtl,
decoration: InputDecoration(hintText: st.t('history_search_ph')),
onChanged: (_) => setState(() {}),
),
const SizedBox(height: 8),
],
if (all.isEmpty)
Padding(
padding: const EdgeInsets.symmetric(vertical: 8),
child: Text(st.t('history_empty'),
style: const TextStyle(color: kMuted)),
)
else if (filtered.isEmpty)
Padding(
padding: const EdgeInsets.symmetric(vertical: 8),
child: Text(st.t('history_no_match'),
style: const TextStyle(color: kMuted)),
)
else
...filtered.take(30).map((h) {
final path = h['file'] as String? ?? '';
final name = _historyName(path);
final date = (h['date'] as String? ?? '').split('T').first;
return Container(
margin: const EdgeInsets.only(bottom: 6),
padding:
const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
decoration: BoxDecoration(
color: kCardDark,
border: Border.all(color: kCardDark2),
borderRadius: BorderRadius.circular(10),
),
child: Row(
children: [
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('✓ $name',
style: const TextStyle(
color: Colors.white, fontSize: 13),
overflow: TextOverflow.ellipsis),
if (date.isNotEmpty)
Text(date,
style:
const TextStyle(color: kMuted, fontSize: 10)),
],
),
),
if (path.isNotEmpty)
IconButton(
tooltip: st.t('open_folder'),
icon: Icon(Icons.folder_open,
color: st.accent.main, size: 20),
onPressed: () => OpenFilex.open(path),
),
],
),
);
}),
],
);
}

String _historyName(String path) {
if (path.isEmpty) return '';
final parts = path.replaceAll('\\', '/').split('/');
var name = parts.isNotEmpty ? parts.last : path;
if (name.length > 46) name = '${name.substring(0, 43)}...';
return name;
}
}
