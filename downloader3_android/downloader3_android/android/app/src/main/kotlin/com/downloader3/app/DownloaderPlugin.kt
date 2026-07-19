package com.downloader3.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.mapper.VideoInfo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/**
 * 🎬 KERN-FEATURE: echter Download-Motor fürs Handy -- Brücke zwischen
 * Flutter (Dart) und der nativen youtubedl-android-Bibliothek (bündelt
 * denselben yt-dlp, den auch die Windows-App per Python-Prozess nutzt,
 * siehe MOBILE_README.md für den Hintergrund zur Bibliothekswahl).
 *
 * WICHTIG: init()/getInfo()/execute() der Bibliothek sind blockierende
 * Aufrufe (kein eigenes Threading eingebaut) -- deshalb läuft hier
 * JEDE Operation in einem eigenen Hintergrund-Thread, und alle
 * Rückmeldungen an Flutter werden über einen Handler zurück auf den
 * Main-Thread geholt (MethodChannel/EventChannel-Aufrufe MÜSSEN vom
 * Main-Thread kommen, sonst crasht die App sofort).
 */
class DownloaderPlugin(private val context: Context) : FlutterPlugin,
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.downloader3.app/downloader"
        const val EVENT_CHANNEL = "com.downloader3.app/downloader_progress"
        private const val TAG = "DownloaderPlugin"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var initialized = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initEngine(result)
            "getInfo" -> getInfo(call.argument("url") ?: "", result)
            "startDownload" -> startDownload(call, result)
            "cancel" -> cancelDownload(call.argument("processId") ?: "", result)
            else -> result.notImplemented()
        }
    }

    // --- 🚀 Initialisierung ---------------------------------------------
    private fun initEngine(result: MethodChannel.Result) {
        Thread {
            try {
                // 🐛 Vorsichtsmaßnahme (kann hier nicht gegen ein echtes
                // Gerät getestet werden, siehe MOBILE_README.md): init()
                // mehrfach aufzurufen (z. B. bei App-Neustart) ist laut
                // Bibliotheks-Doku unproblematisch -- sie merkt sich intern,
                // ob sie schon initialisiert ist.
                YoutubeDL.getInstance().init(context)
                FFmpeg.getInstance().init(context)
                initialized = true
                // 🔄 yt-dlp muss regelmäßig aktualisiert werden, weil
                // Plattformen (YouTube, TikTok, ...) ihre Seiten laufend
                // ändern -- sonst brechen Downloads nach einiger Zeit
                // unabhängig vom Rest der App wieder ab. Bewusst NACH dem
                // erfolgreichen init() und NICHT blockierend für den
                // "bereit"-Rückruf, damit ein langsames/fehlendes Netz
                // beim allerersten Start nicht die ganze App aufhält.
                try {
                    // ⚠️ Signatur + verschachteltes Enum GEGEN das offizielle
                    // Beispiel der Bibliothek geprüft (nicht geraten, siehe
                    // MOBILE_README.md): updateYoutubeDL(context, channel)
                    // braucht BEIDE Argumente, "channel" ist ein
                    // verschachteltes Enum in YoutubeDL selbst.
                    YoutubeDL.getInstance()
                        .updateYoutubeDL(context, YoutubeDL.UpdateChannel._STABLE)
                } catch (e: Exception) {
                    Log.w(TAG, "yt-dlp update failed (non-fatal)", e)
                }
                mainHandler.post { result.success(true) }
            } catch (e: YoutubeDLException) {
                Log.e(TAG, "init failed", e)
                mainHandler.post { result.error("INIT_FAILED", e.message, null) }
            } catch (e: Exception) {
                Log.e(TAG, "init failed", e)
                mainHandler.post { result.error("INIT_FAILED", e.message, null) }
            }
        }.start()
    }

    // --- ℹ️ Video-Infos (Titel, Dauer) -- rein informativ, Fehler hier
    // dürfen NIE den eigentlichen Download verhindern. -------------------
    private fun getInfo(url: String, result: MethodChannel.Result) {
        if (!initialized) {
            result.error("NOT_INITIALIZED", "call init first", null)
            return
        }
        Thread {
            try {
                val info: VideoInfo = YoutubeDL.getInstance().getInfo(url)
                // ⚠️ Bewusst NUR .title verwendet -- das ist der einzige
                // VideoInfo-Feldname, der sich anhand echter, verifizierter
                // Nutzungsbeispiele der Bibliothek bestätigen ließ (siehe
                // MOBILE_README.md). Weitere Felder (Dauer, Thumbnail-URL
                // o. Ä.) lassen sich ergänzen, sobald das gegen ein echtes
                // Gerät geprüft wurde -- lieber hier auf Nummer sicher
                // gehen, als einen Kompilierfehler wegen eines geratenen
                // Feldnamens zu riskieren.
                val map = HashMap<String, Any>()
                map["title"] = info.title ?: ""
                mainHandler.post { result.success(map) }
            } catch (e: Exception) {
                Log.w(TAG, "getInfo failed (non-fatal)", e)
                mainHandler.post { result.error("INFO_FAILED", e.message, null) }
            }
        }.start()
    }

    // --- ⬇️ Der eigentliche Download -------------------------------------
    private fun startDownload(call: MethodCall, result: MethodChannel.Result) {
        if (!initialized) {
            result.error("NOT_INITIALIZED", "call init first", null)
            return
        }
        val url = call.argument<String>("url") ?: run {
            result.error("BAD_ARGS", "missing url", null); return
        }
        // 🎯 Erweiterte Optionen (Pendant zu Plattform/Format/Auflösung am
        // Desktop, siehe download_tab.dart für die UI-Seite): isAudio ->
        // Tonspur extrahieren statt Video; format -> Zielendung (mp3/wav/
        // m4a/aac/flac/ogg für Audio, mp4/webm/mkv/mov für Video), "auto"
        // oder leer fällt auf mp4 bzw. mp3 zurück; height -> maximale
        // Video-Höhe in Pixeln (720, 1080, ...) oder null/0 für "beste
        // verfügbare" Qualität; playlist -> ganze Playlist/Kanal statt nur
        // des einen verlinkten Videos.
        val isAudio = call.argument<Boolean>("isAudio") ?: false
        val formatArg = call.argument<String>("format") ?: ""
        val format = if (formatArg.isNotBlank()) formatArg else (if (isAudio) "mp3" else "mp4")
        val height = call.argument<Int>("height")
        val playlist = call.argument<Boolean>("playlist") ?: false
        // 📝 Untertitel automatisch mitladen (SRT/VTT, inkl. automatisch
        // generierter Untertitel) -- Pendant zur "Untertitel"-Option, die es
        // am Desktop noch nicht gibt.
        val downloadSubtitles = call.argument<Boolean>("downloadSubtitles") ?: false
        // ✂️ Clip-Trim (Pendant zu Task K): nur gesetzt, wenn BEIDE Werte
        // vorhanden sind -- yt-dlp's --download-sections mit "*start-end".
        val clipStart = call.argument<String>("clipStart")
        val clipEnd = call.argument<String>("clipEnd")
        // 🖼️ Wallpaper-Modus (Pendant zu Task M): lädt zusätzlich das beste
        // verfügbare Thumbnail-Bild als JPG herunter.
        val wallpaperMode = call.argument<Boolean>("wallpaperMode") ?: false
        val processId = UUID.randomUUID().toString()

        val outDir = File(context.getExternalFilesDir(null), "Downloads")
        if (!outDir.exists()) outDir.mkdirs()

        val request = YoutubeDLRequest(url)
        // 📁 Titel-basierter Dateiname, auf 150 Zeichen gekappt -- manche
        // Videotitel sind sehr lang und würden sonst an Dateisystem-
        // Grenzen (z. B. 255 Byte unter Android/exFAT) scheitern. Bei
        // Playlist/Kanal-Downloads kommt zusätzlich der Index dazu, damit
        // nicht jede Folge dieselbe Datei überschreibt (Pendant zum
        // playlist_index-Suffix in _download_media() am Desktop).
        val nameTemplate = if (playlist) {
            "%(title).150s_%(playlist_index)s.%(ext)s"
        } else {
            "%(title).150s.%(ext)s"
        }
        request.addOption("-o", outDir.absolutePath + "/" + nameTemplate)
        request.addOption("--no-mtime")
        request.addOption(if (playlist) "--yes-playlist" else "--no-playlist")
        // 🐛 BUGFIX: ohne diese Optionen kann ein einzelner hängender
        // Netzwerk-Request (z. B. YouTube reagiert langsam/gar nicht auf
        // die Info-Extraktion) den gesamten Download für viele Minuten
        // einfrieren, bevor irgendein Fehler zurückkommt -- das war exakt
        // das gemeldete Verhalten ("0% Fortschritt, Fehler erst nach 10
        // Minuten"). Ein Socket-Timeout + begrenzte, aber vorhandene
        // Wiederholungsversuche sorgen dafür, dass ein einzelner
        // hängender Versuch nach spätestens ~30s abbricht und yt-dlp es
        // stattdessen mehrfach neu versucht, statt endlos zu warten.
        request.addOption("--socket-timeout", "30")
        request.addOption("--retries", "5")
        request.addOption("--fragment-retries", "5")

        // 📝 Untertitel automatisch herunterladen: --write-subs holt von
        // der Plattform bereitgestellte (manuelle) Untertitel, --write-auto-subs
        // zusätzlich automatisch generierte, --sub-langs all alle verfügbaren
        // Sprachen, --convert-subs srt vereinheitlicht das Zielformat auf SRT.
        if (downloadSubtitles) {
            request.addOption("--write-subs")
            request.addOption("--write-auto-subs")
            request.addOption("--sub-langs", "all")
            request.addOption("--convert-subs", "srt")
        }

        // ✂️ Nur einen Zeitausschnitt herunterladen -- yt-dlp's eigene,
        // gut dokumentierte CLI-Option, intern per ffmpeg-Postprocessing
        // umgesetzt (kein direkter FFmpeg-Klassenzugriff nötig).
        if (!clipStart.isNullOrBlank() && !clipEnd.isNullOrBlank()) {
            request.addOption("--download-sections", "*${clipStart}-${clipEnd}")
        }

        // 🖼️ Wallpaper-Modus: bestes verfügbares Thumbnail als JPG mitladen
        // (--write-thumbnail / --convert-thumbnails sind stabile, offiziell
        // dokumentierte yt-dlp-CLI-Optionen).
        if (wallpaperMode) {
            request.addOption("--write-thumbnail")
            request.addOption("--convert-thumbnails", "jpg")
        }

        if (isAudio) {
            request.addOption("-f", "bestaudio/best")
            request.addOption("-x")
            request.addOption("--audio-format", format)
        } else {
            // 📐 Format-String bewusst nach demselben Muster wie im
            // offiziellen Beispiel der Bibliothek aufgebaut (siehe
            // MOBILE_README.md) -- "bestvideo[ext=mp4]+bestaudio[ext=m4a]/
            // best[ext=mp4]/best": zuerst versuchen, beste Video- und
            // Audiospur separat zu holen und zusammenzuführen (braucht
            // FFmpeg, ist bereits initialisiert), mit zwei Rückfallstufen
            // für Plattformen, bei denen das nicht klappt. Die optionale
            // Höhenbegrenzung wird an "bestvideo" angehängt, wenn eine
            // konkrete Auflösung (statt "beste") gewählt wurde.
            val heightFilter = if (height == null || height <= 0) "" else "[height<=$height]"
            request.addOption(
                "-f",
                "bestvideo$heightFilter[ext=mp4]+bestaudio[ext=m4a]/" +
                    "best$heightFilter[ext=mp4]/best$heightFilter/best"
            )
            // 🎞️ Falls ein anderer Ziel-Container als mp4 gewünscht ist
            // (webm/mkv/mov), wird NACH dem Download remuxt statt die
            // Format-Auswahl selbst einzuschränken -- das hält die bewährte
            // "bestvideo+bestaudio"-Fallback-Kette oben intakt.
            if (format != "auto" && format != "mp4") {
                request.addOption("--remux-video", format)
            }
        }

        // 📸 Vor dem Download merken, welche Dateien schon im Ordner
        // liegen, damit wir nach Abschluss die NEU hinzugekommene Datei
        // erkennen können (statt nur den -- immer gleichen -- Ordner zu
        // melden). Fällt auf den Ordner zurück, falls sich das aus
        // irgendeinem Grund nicht bestimmen lässt.
        val beforeFiles = outDir.listFiles()?.map { it.absolutePath }?.toSet() ?: emptySet()

        // 🐛 KRITISCHER BUGFIX ("0% für immer, dann irgendwann ein
        // Fehler"): execute() blockiert für die gesamte Download-Dauer
        // (Minuten). Die processId früher erst NACH Abschluss über
        // result.success(processId) zurückzugeben bedeutete, dass Dart
        // (_activeProcessId in download_tab.dart) den kompletten Download
        // über gar keine processId verfügte -- alle in der Zwischenzeit
        // über den EventChannel gesendeten "started"/"progress"/"done"-
        // Events wurden deshalb von Dart verworfen (processId-Mismatch),
        // die Fortschrittsanzeige blieb bei 0% hängen. Jetzt wird die
        // processId SOFORT zurückgegeben, bevor der Download überhaupt
        // beginnt -- der eigentliche Fortschritt/Abschluss/Fehler läuft
        // ausschließlich noch über den EventChannel, nicht mehr über das
        // Method-Result.
        result.success(processId)

        Thread {
            try {
                mainHandler.post {
                    eventSink?.success(
                        mapOf("processId" to processId, "event" to "started")
                    )
                }
                YoutubeDL.getInstance().execute(request, processId) { progress, etaSeconds, line ->
                    mainHandler.post {
                        eventSink?.success(
                            mapOf(
                                "processId" to processId,
                                "event" to "progress",
                                "progress" to progress,
                                "eta" to etaSeconds,
                                "line" to line,
                            )
                        )
                    }
                }
                val afterFiles = outDir.listFiles() ?: emptyArray()
                val newFile = afterFiles
                    .filter { !beforeFiles.contains(it.absolutePath) }
                    .maxByOrNull { it.lastModified() }
                    ?: afterFiles.maxByOrNull { it.lastModified() }
                mainHandler.post {
                    eventSink?.success(
                        mapOf(
                            "processId" to processId,
                            "event" to "done",
                            "outputDir" to outDir.absolutePath,
                            "outputFile" to (newFile?.absolutePath ?: outDir.absolutePath),
                            "size" to (newFile?.length() ?: 0L),
                        )
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "download failed", e)
                mainHandler.post {
                    eventSink?.success(
                        mapOf(
                            "processId" to processId,
                            "event" to "error",
                            "error" to (e.message ?: "unknown error"),
                        )
                    )
                }
            }
        }.start()
    }

    private fun cancelDownload(processId: String, result: MethodChannel.Result) {
        try {
            // ✅ Methodenname gegen das offizielle Beispiel der Bibliothek
            // geprüft (nicht geraten, siehe MOBILE_README.md).
            YoutubeDL.getInstance().destroyProcessById(processId)
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCEL_FAILED", e.message, null)
        }
    }
}
