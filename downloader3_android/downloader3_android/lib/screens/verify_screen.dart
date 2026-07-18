import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

class VerifyScreen extends StatefulWidget {
  final AppState state;
  final String email;
  final VoidCallback onVerified;
  const VerifyScreen({
    super.key,
    required this.state,
    required this.email,
    required this.onVerified,
  });

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final codeCtl = TextEditingController();
  String status = '';
  String? error;
  bool sending = true;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  Future<void> _sendCode() async {
    setState(() {
      sending = true;
      status = '🔄 ${st.t('verify_sending')}';
    });
    final code = st.store.startVerification(widget.email);
    try {
      final r = await st.api.sendCode(widget.email, code);
      if (r['ok'] == true) {
        setState(() {
          sending = false;
          status = '✓ ${st.t('verify_sent')}\n${widget.email}';
        });
      } else {
        setState(() {
          sending = false;
          status = '✗ ${r['error'] ?? st.t('contact_fail')}';
        });
      }
    } catch (_) {
      setState(() {
        sending = false;
        status = '✗ ${st.t('contact_fail')}';
      });
    }
  }

  void _confirm() {
    final result =
        st.store.checkVerification(widget.email, codeCtl.text.trim());
    if (result == 'ok') {
      widget.onVerified();
    } else if (result == 'expired') {
      setState(() => error = st.t('verify_expired'));
    } else {
      setState(() => error = st.t('verify_wrong'));
    }
  }

  void _showSpamHint() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCardDark2,
        title: Column(
          children: [
            const Text('📥', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 8),
            Text(st.t('spam_hint_title'),
                style: TextStyle(
                    color: st.accent.main, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(st.t('spam_hint_text'),
            style: const TextStyle(color: Colors.white, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(st.t('verify_title'),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: st.accent.main),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, letterSpacing: 4),
                  decoration:
                      InputDecoration(hintText: st.t('verify_code_ph')),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(color: Color(0xFFF87171))),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: sending ? null : _confirm,
                    child: Text(st.t('verify_button')),
                  ),
                ),
                TextButton(
                  onPressed: sending ? null : _sendCode,
                  child: Text(st.t('verify_resend'),
                      style: TextStyle(color: st.accent.main)),
                ),
                TextButton(
                  onPressed: _showSpamHint,
                  child: Text(st.t('spam_hint_btn'),
                      style: const TextStyle(color: kMuted, fontSize: 11)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(st.t('verify_cancel'),
                      style: const TextStyle(color: kMuted, fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
