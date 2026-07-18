import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../app_state.dart';
import '../theme.dart';

/// 📤 Pendant zu page_send_file() in main.py. Wichtiger Unterschied zur
/// Windows-App: dort gibt's für große Dateien einen Upload zu einem
/// externen Datei-Hoster (gofile.io) mit anschließendem Link-Versand.
/// Das ist ein eigenes, nicht-triviales Stück Technik (siehe die
/// gofile.io-Debugging-Runde) -- für Phase 1 des Send-File-Tabs bleibt
/// es hier bewusst beim direkten E-Mail-Anhang bis 6 MB (server-seitig
/// ohnehin hart begrenzt, siehe SMALL_ATTACH_LIMIT in app.py); der
/// Upload-zu-gofile.io-Weg lässt sich in einer der nächsten Runden 1:1
/// aus main.py übernehmen, sobald das hier im echten Betrieb läuft.
class SendFileTab extends StatefulWidget {
  final AppState state;
  const SendFileTab({super.key, required this.state});

  @override
  State<SendFileTab> createState() => _SendFileTabState();
}

class _SendFileTabState extends State<SendFileTab> {
  static const int _limit = 6 * 1024 * 1024; // 6 MB, siehe SMALL_ATTACH_LIMIT
  XFile? picked;
  int pickedSize = 0;
  final toCtl = TextEditingController();
  final msgCtl = TextEditingController();
  String? status;
  Color statusColor = kMuted;
  bool busy = false;

  AppState get st => widget.state;

  Future<void> _pickFile() async {
    final f = await openFile();
    if (f == null) return;
    final size = await f.length();
    setState(() {
      picked = f;
      pickedSize = size;
      status = null;
    });
  }

  Future<void> _send() async {
    final email = st.currentEmail;
    if (email == null) return;
    final f = picked;
    if (f == null) {
      setState(() {
        status = st.t('sendfile_need_file');
        statusColor = const Color(0xFFFBBF24);
      });
      return;
    }
    if (pickedSize > _limit) {
      setState(() {
        status = st.t('sendfile_too_big');
        statusColor = const Color(0xFFF87171);
      });
      return;
    }
    final to = toCtl.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(to)) {
      setState(() {
        status = st.t('invalid_email');
        statusColor = const Color(0xFFF87171);
      });
      return;
    }
    setState(() {
      busy = true;
      status = st.t('sendfile_sending');
      statusColor = kMuted;
    });
    try {
      final bytes = await File(f.path).readAsBytes();
      final b64 = base64Encode(bytes);
      final r = await st.api.sendFile(
        fromEmail: email,
        to: to,
        message: msgCtl.text.trim(),
        filename: f.name,
        contentB64: b64,
      );
      setState(() {
        busy = false;
        if (r['ok'] == true) {
          status = '✓ ${st.t('sendfile_sent')}';
          statusColor = const Color(0xFF34D399);
        } else {
          status = '✗ ${st.t('sendfile_fail')} (${r['error'] ?? ''})';
          statusColor = const Color(0xFFF87171);
        }
      });
    } catch (e) {
      setState(() {
        busy = false;
        status = '✗ ${st.t('sendfile_fail')}';
        statusColor = const Color(0xFFF87171);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!st.isPremium) {
      return _LockedTabView(
        message: st.t('sendfile_premium_locked'),
        state: st,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(st.t('sendfile_title'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: st.accent.main)),
          const SizedBox(height: 6),
          Text(st.t('sendfile_intro'),
              style: const TextStyle(color: kMuted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(picked?.name ?? st.t('sendfile_pick_file')),
          ),
          if (picked != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${(pickedSize / 1024 / 1024).toStringAsFixed(2)} MB',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: toCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: st.t('sendfile_recipient')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: msgCtl,
            maxLines: 3,
            decoration: InputDecoration(hintText: st.t('sendfile_message')),
          ),
          if (status != null) ...[
            const SizedBox(height: 10),
            Text(status!, style: TextStyle(color: statusColor)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: busy ? null : _send,
            child: Text(st.t('sendfile_send_btn')),
          ),
        ],
      ),
    );
  }
}

/// 🔒 Gemeinsame "Premium-Feature"-Ansicht -- dieselbe Idee wie das
/// gelbe Info-Banner am Desktop (page_send_file in main.py), hier als
/// eigene ganzseitige Ansicht statt Banner, da Mobile-Bildschirme
/// weniger Platz für einen dauerhaften Banner UND den vollen
/// Formularinhalt gleichzeitig haben.
class _LockedTabView extends StatelessWidget {
  final String message;
  final AppState state;
  const _LockedTabView({required this.message, required this.state});

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
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
