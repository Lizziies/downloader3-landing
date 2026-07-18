import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

/// 🤝 Pendant zu page_helper() in main.py -- öffentliche Ehrentafel
/// (für alle sichtbar) + der private "eigenen Namen setzen/entfernen"-
/// Bereich (nur für Konten mit Rang "helper", serverseitig geprüft).
class HelperTab extends StatefulWidget {
  final AppState state;
  const HelperTab({super.key, required this.state});

  @override
  State<HelperTab> createState() => _HelperTabState();
}

class _HelperTabState extends State<HelperTab> {
  static const int maxLen = 24; // HONOR_NAME_MAX_LEN, siehe app.py
  List<String> honorBoard = [];
  bool loadingBoard = true;
  final nameCtl = TextEditingController();
  String? msg;
  Color msgColor = kMuted;
  bool busy = false;

  AppState get st => widget.state;
  bool get isHelper => st.store.premiumRole == 'helper';

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    setState(() => loadingBoard = true);
    try {
      final r = await st.api.helpersPublic();
      final list =
          (r['helpers'] as List? ?? []).map((e) => e.toString()).toList();
      setState(() {
        honorBoard = list;
        loadingBoard = false;
      });
    } catch (_) {
      setState(() => loadingBoard = false);
    }
  }

  Future<void> _setName() async {
    final email = st.currentEmail;
    if (email == null) return;
    final name = nameCtl.text.trim();
    if (name.isEmpty) return;
    if (name.length > maxLen) {
      setState(() {
        msg = st.t('helper_name_too_long');
        msgColor = const Color(0xFFF87171);
      });
      return;
    }
    setState(() {
      busy = true;
      msg = null;
    });
    final r = await st.api.helperSetPublic(email, name, true);
    setState(() {
      busy = false;
      if (r['ok'] == true) {
        msg = st.t('helper_saved');
        msgColor = const Color(0xFF34D399);
        nameCtl.clear();
      } else {
        msg = '✗ ${r['error'] ?? ''}';
        msgColor = const Color(0xFFF87171);
      }
    });
    _loadBoard();
  }

  Future<void> _removeName() async {
    final email = st.currentEmail;
    if (email == null) return;
    setState(() => busy = true);
    final r = await st.api.helperSetPublic(email, '', false);
    setState(() {
      busy = false;
      if (r['ok'] == true) {
        msg = st.t('helper_removed');
        msgColor = const Color(0xFF34D399);
      } else {
        msg = '✗ ${r['error'] ?? ''}';
        msgColor = const Color(0xFFF87171);
      }
    });
    _loadBoard();
  }

  Future<void> _createCode() async {
    final email = st.currentEmail;
    if (email == null) return;
    setState(() => busy = true);
    final r = await st.api.helperCreateCode(email);
    setState(() {
      busy = false;
      if (r['ok'] == true) {
        msg = '${st.t('helper_code_created')} ${r['code']}';
        msgColor = const Color(0xFF34D399);
      } else if (r['error'] == 'cooldown') {
        final h = r['hours_left'];
        msg = '${st.t('helper_cooldown')} ${h}h';
        msgColor = const Color(0xFFFBBF24);
      } else {
        msg = '✗ ${r['error'] ?? ''}';
        msgColor = const Color(0xFFF87171);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(st.t('helper_title'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: st.accent.main)),
          const SizedBox(height: 6),
          Text(st.t('helper_desc'), style: const TextStyle(color: kMuted)),
          const SizedBox(height: 14),
          if (loadingBoard)
            const Center(child: CircularProgressIndicator())
          else if (honorBoard.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('—', style: TextStyle(color: kMuted)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: honorBoard
                  .map((name) => Chip(
                        avatar: const Text('💜'),
                        label: Text(name),
                        backgroundColor: kCardDark2,
                        labelStyle: const TextStyle(color: Colors.white),
                      ))
                  .toList(),
            ),
          const Divider(color: kCardDark2, height: 32),
          if (!isHelper)
            Text(st.t('helper_only_for_helpers'),
                style: const TextStyle(color: kMuted))
          else ...[
            Text(st.t('helper_your_name'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtl,
              maxLength: maxLen,
              decoration: InputDecoration(hintText: st.t('helper_name_ph')),
            ),
            if (msg != null) ...[
              const SizedBox(height: 4),
              Text(msg!, style: TextStyle(color: msgColor)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : _setName,
                    child: Text(st.t('helper_set_btn')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : _removeName,
                    child: Text(st.t('helper_remove_btn')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: busy ? null : _createCode,
              child: Text(st.t('helper_create_code_btn')),
            ),
          ],
        ],
      ),
    );
  }
}
