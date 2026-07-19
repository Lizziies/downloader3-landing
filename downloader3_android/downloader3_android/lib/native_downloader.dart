import 'package:flutter/services.dart';

/// 🎬 Dart-seitige Brücke zu DownloaderPlugin.kt (nativer yt-dlp-Motor,
/// siehe dort für den technischen Hintergrund). Kapselt den
/// MethodChannel (Befehle: init/getInfo/startDownload/cancel) und den
/// EventChannel (laufende Fortschritts-Updates während eines Downloads).
class NativeDownloader {
static const _methodChannel =
MethodChannel('com.downloader3.app/downloader');
static const _eventChannel =
EventChannel('com.downloader3.app/downloader_progress');

static Stream<Map<String, dynamic>>? _progressStream;

/// Muss einmal aufgerufen werden, bevor irgendetwas anderes hier
/// benutzt wird (lädt/initialisiert yt-dlp+ffmpeg nativ, kann beim
/// allerersten Start ein paar Sekunden dauern).
static Future<bool> init() async {
try {
final ok = await _methodChannel.invokeMethod<bool>('init');
return ok ?? false;
} on PlatformException {
return false;
}
}

/// Rein informativ (Titel/Dauer/Thumbnail) -- darf fehlschlagen, ohne
/// dass das den eigentlichen Download verhindert.
static Future<Map<String, dynamic>?> getInfo(String url) async {
try {
final r = await _methodChannel
.invokeMethod<Map>('getInfo', {'url': url});
return r?.cast<String, dynamic>();
} on PlatformException {
return null;
}
}

/// Startet einen Download.
///
/// - `isAudio`: true -> Tonspur extrahieren statt Video.
/// - `format`: Zielendung, z. B. "mp3"/"wav"/"m4a"/"aac"/"flac"/"ogg"
///   (Audio) oder "mp4"/"webm"/"mkv"/"mov" (Video). Leer/"auto" fällt
///   nativ auf mp4 bzw. mp3 zurück (siehe DownloaderPlugin.kt).
/// - `height`: maximale Video-Höhe in Pixeln (480/720/1080/1440/2160),
///   oder null für "beste verfügbare" Qualität.
/// - `playlist`: true -> ganze Playlist/Kanal statt nur des einen Links.
///
/// Gibt die processId zurück, sobald der native Aufruf zurückkehrt
/// (NACH Abschluss des Downloads, da execute() blockierend ist --
/// Fortschritt währenddessen kommt über [progressStream]).
static Future<String?> startDownload({
required String url,
bool isAudio = false,
String format = 'mp4',
int? height,
bool playlist = false,
bool downloadSubtitles = false,
}) async {
try {
return await _methodChannel.invokeMethod<String>('startDownload', {
'url': url,
'isAudio': isAudio,
'format': format,
if (height != null) 'height': height,
'playlist': playlist,
'downloadSubtitles': downloadSubtitles,
});
} on PlatformException catch (e) {
throw DownloaderException(e.message ?? 'download failed');
}
}

static Future<void> cancel(String processId) async {
try {
await _methodChannel.invokeMethod('cancel', {'processId': processId});
} on PlatformException {
// best-effort
}
}

/// Events: {processId, event: 'started'|'progress'|'done'|'error', ...}
static Stream<Map<String, dynamic>> get progressStream {
_progressStream ??= _eventChannel
.receiveBroadcastStream()
.map((e) => (e as Map).cast<String, dynamic>());
return _progressStream!;
}
}

class DownloaderException implements Exception {
final String message;
DownloaderException(this.message);
@override
String toString() => message;
}
