import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../app_state.dart';
import '../theme.dart';

/// 🎨 Pendant zu page_ai_studio() in main.py — Text/Bild/Video-
/// Generierung über den gemeinsamen Gemini-Schlüssel des Servers (die
/// App selbst braucht/kennt keinen eigenen Schlüssel, siehe app.py).
class AiStudioTab extends StatefulWidget {
  final AppState state;
  const AiStudioTab({super.key, required this.state});

  @override
  State<AiStudioTab> createState() => _AiStudioTabState();
}

class _AiStudioTabState extends State<AiStudioTab>
    with SingleTickerProviderStateMixin {
  late final TabController tabCtl = TabController(length: 3, vsync: this);
  final promptCtl = TextEditingController();
  bool busy = false;
  String? error;
  String? textResult;
  Uint8List? imageResult;
  bool videoBusy = false;
  String? videoStatus;
  String? videoPath;

  AppState get st => widget.state;

  Future<void> _generateText() async {
    final email = st.currentEmail ?? '';
    final prompt = promptCtl.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
      textResult = null;
    });
    final r = await st.api.aiText(prompt, email);
    setState(() {
      busy = false;
      if (r['ok'] == true) {
        textResult = r['text'] as String?;
      } else {
        error = '✗ ${st.t('ai_fail')} (${r['error'] ?? ''})';
      }
    });
  }

  Future<void> _generateImage() async {
    final email = st.currentEmail ?? '';
    final prompt = promptCtl.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
      imageResult = null;
    });
    final r = await st.api.aiImage(prompt, email);
    setState(() {
      busy = false;
      if (r['ok'] == true && r['image_base64'] != null) {
        imageResult = base64Decode(r['image_base64'] as String);
      } else {
        error = '✗ ${st.t('ai_fail')} (${r['error'] ?? ''})';
      }
    });
  }

  Future<void> _generateVideo() async {
    final email = st.currentEmail ?? '';
    final prompt = promptCtl.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      videoBusy = true;
      error = null;
      videoPath = null;
      videoStatus = st.t('ai_video_generating');
    });
    final start = await st.api.aiVideoStart(prompt, email);
    if (start['ok'] != true || start['operation'] == null) {
      setState(() {
        videoBusy = false;
        error = '✗ ${st.t('ai_fail')} (${start['error'] ?? ''})';
      });
      return;
    }
    final op = start['operation'] as String;
    // ⏱️ Polling (wie am Desktop): Video-Generierung dauert Minuten,
    // deshalb regelmäßig nachfragen statt einmalig zu warten.
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return;
      final status = await st.api.aiVideoStatus(op);
      if (status['done'] == true) {
        if (status['ok'] != true) {
          setState(() {
            videoBusy = false;
            error = '✗ ${st.t('ai_fail')} (${status['error'] ?? ''})';
          });
          return;
        }
        break;
      }
    }
    final bytes = await st.api.aiVideoDownload(op);
    if (bytes == null) {
      setState(() {
        videoBusy = false;
        error = '✗ ${st.t('ai_fail')}';
      });
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/ai_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
    await file.writeAsBytes(bytes);
    setState(() {
      videoBusy = false;
      videoPath = file.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!st.isPremium) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text(st.t('ai_premium_locked'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(st.t('ai_title'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: st.accent.main)),
        ),
        TabBar(
          controller: tabCtl,
          labelColor: st.accent.main,
          unselectedLabelColor: kMuted,
          indicatorColor: st.accent.main,
          tabs: [
            Tab(text: st.t('ai_text_tab')),
            Tab(text: st.t('ai_image_tab')),
            Tab(text: st.t('ai_video_tab')),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TextField(
            controller: promptCtl,
            maxLines: 2,
            decoration: InputDecoration(hintText: st.t('ai_prompt_ph')),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tabCtl,
            children: [
              _buildTextTab(),
              _buildImageTab(),
              _buildVideoTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: busy ? null : _generateText,
            child: Text(busy ? st.t('ai_generating') : st.t('ai_generate_btn')),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: Color(0xFFF87171))),
          ],
          if (textResult != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kCardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(textResult!,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildImageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: busy ? null : _generateImage,
            child: Text(busy ? st.t('ai_generating') : st.t('ai_generate_btn')),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: Color(0xFFF87171))),
          ],
          if (imageResult != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(imageResult!),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVideoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: videoBusy ? null : _generateVideo,
            child: Text(
                videoBusy ? st.t('ai_video_generating') : st.t('ai_generate_btn')),
          ),
          if (videoBusy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: Color(0xFFF87171))),
          ],
          if (videoPath != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => OpenFilex.open(videoPath!),
              icon: const Icon(Icons.play_arrow),
              label: const Text('▶'),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
