import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

/// 🔄 Konvertierungs-Tab (Gerüst) -- die eigentliche Konvertierung
/// läuft nativ über FFmpeg. Die exakte Methoden-Signatur des nativen
/// FFmpeg-Wrappers (com.yausername.ffmpeg.FFmpeg) ist aktuell nicht
/// zweifelsfrei verifiziert -- nur init() ist bestätigt/dokumentiert.
/// Um keinen geratenen nativen Aufruf zu riskieren, der zur Laufzeit
/// crashen könnte, deckt diese Runde bewusst NUR das UI-Gerüst ab:
/// Tab, Premium-Sperre und Formularfelder. Der eigentliche
/// Konvertierungs-Call kommt in einer eigenen, sauber getesteten Runde
/// (siehe convert_coming_soon).
class ConvertTab extends StatefulWidget {
  final AppState state;
  const ConvertTab({super.key, required this.state});

  @override
  State<ConvertTab> createState() => _ConvertTabState();
}

class _ConvertTabState extends State<ConvertTab> {
  // 📁 Kein file_picker/file_selector-Dateibrowser für die Quelldatei
  // hier -- file_picker ist kein Dependency dieses Projekts und
  // file_selector deckt Android nicht zuverlässig ab. Als Platzhalter
  // dient ein einfaches Textfeld für den Dateipfad, bis eine echte
  // Dateiauswahl ohne unverifizierte Dependency möglich ist.
  final pathCtl = TextEditingController();
  String targetFormat = 'mp4';
  static const _formats = ['mp4', 'mp3', 'wav', 'mov'];

  AppState get st => widget.state;

  void _convert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(st.t('convert_coming_soon'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!st.isPremium) {
      return _LockedConvertView(state: st);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(st.t('nav_convert'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: st.accent.main)),
          const SizedBox(height: 16),
          Text(st.t('convert_select_file'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: pathCtl,
            decoration: InputDecoration(hintText: st.t('convert_select_file')),
          ),
          const SizedBox(height: 16),
          Text(st.t('convert_target_format'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
                  value: targetFormat,
            items: _formats
                .map((f) =>
                    DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => targetFormat = v);
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _convert,
            child: Text(st.t('convert_button')),
          ),
        ],
      ),
    );
  }
}

/// 🔒 Gleiche Sperr-Ansicht wie _LockedTabView in send_file_tab.dart
/// -- bewusst dupliziert statt importiert/exportiert, um send_file_tab.dart
/// nicht anfassen zu müssen; gleicher Look & Feel (Lock-Emoji + zentrierter
/// Hinweistext), damit sich der Convert-Tab wie ein natives Feature des
/// bestehenden Premium-Sperr-Musters anfühlt.
class _LockedConvertView extends StatelessWidget {
  final AppState state;
  const _LockedConvertView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(state.t('convert_premium_required'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
