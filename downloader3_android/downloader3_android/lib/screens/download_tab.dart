import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../app_state.dart';
import '../native_downloader.dart';
import '../theme.dart';

/// ⬇️ Pendant zu page_download() in main.py -- echter Download-Motor
/// über DownloaderPlugin.kt / native_downloader.dart (yt-dlp+ffmpeg,
/// nativ ins Handy eingebettet über die youtubedl-android-Bibliothek).
///
/// ⚠️ EHRLICHER HINWEIS (siehe MOBILE_README.md für Details): dieser
/// Code wurde sorgfältig gegen die offizielle Bibliotheks-Doku
/// geschrieben (nicht geraten), konnte aber mangels Android-Gerät/
/// -Emulator in dieser Umgebung NICHT selbst gebaut und getestet
/// werden. Der erste echte Test auf einem Handy ist also wichtig --
/// falls dabei ein Fehler auftaucht, bitte die genaue Meldung schicken,
/// dann lässt sich gezielt nachbessern (genau wie beim file.io/
/// gofile.io-Fall vorher).
class DownloadTab extends StatefulWidget {
  final AppState state;
  const DownloadTab({super.key, required this.state});

  @override
  State<DownloadTab> createState() => _DownloadTabState();
}

class _DownloadTabState extends State<DownloadTab> {
  final urlCtl = TextEditingController();
  String mode = 'video'; // 'video' oder 'audio'
  String quality = 'best'; // 'best', '1080', '720', '480'
  bool initializing = true;
  bool initFailed = false;
  bool downloading = false;
  double? progress;
  String? statusLine;
  String? error;
  String? finishedDir;
  StreamSubscription? _sub;
  String? _activeProcessId;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _init();
    _sub = NativeDownloader.progressStream.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
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
        setState(() {
          final p = e['progress'];
          progress = p is num ? p.toDouble() / 100 : null;
          statusLine = e['line'] as String?;
        });
        break;
      case 'done':
        setState(() {
          downloading = false;
          progress = 1.0;
          finishedDir = e['outputDir'] as String?;
        });
        break;
      case 'error':
        setState(() {
          downloading = false;
          error = e['error'] as String?;
        });
        break;
    }
  }

  Future<void> _startDownload() async {
    final url = urlCtl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      downloading = true;
      progress = 0;
      statusLine = null;
      error = null;
      finishedDir = null;
    });
    try {
      final processId = await NativeDownloader.startDownload(
        url: url,
        mode: mode,
        quality: quality,
      );
      _activeProcessId = processId;
    } catch (e) {
      setState(() {
        downloading = false;
        error = e.toString();
      });
    }
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
            TextField(
              controller: urlCtl,
              decoration: InputDecoration(hintText: st.t('download_url_ph')),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'video', label: Text('🎬 Video')),
                      ButtonSegment(value: 'audio', label: Text('🎵 Audio')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setState(() => mode = s.first),
                  ),
                ),
              ],
            ),
            if (mode == 'video') ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['best', '1080', '720', '480']
                    .map((q) => ChoiceChip(
                          label: Text(q == 'best' ? 'Beste' : '$q p'),
                          selected: quality == q,
                          onSelected: (_) => setState(() => quality = q),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: downloading ? null : _startDownload,
              child: Text(downloading
                  ? '${((progress ?? 0) * 100).toStringAsFixed(0)}%'
                  : st.t('nav_download')),
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
                  color: kCardDark,
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
        ],
      ),
    );
  }
}
