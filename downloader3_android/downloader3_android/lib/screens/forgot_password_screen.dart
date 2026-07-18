import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AppState state;
  final String prefillEmail;
  const ForgotPasswordScreen({
    super.key,
    required this.state,
    this.prefillEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController emailCtl =
      TextEditingController(text: widget.prefillEmail);
  final codeCtl = TextEditingController();
  final newPwCtl = TextEditingController();
  String status = '';
  String? error;
  bool codeSent = false;
  bool busy = false;

  AppState get st => widget.state;

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  Future<void> _sendCode() async {
    final email = emailCtl.text.trim().toLowerCase();
    if (!_validEmail(email)) {
      setState(() => error = st.t('invalid_email'));
      return;
    }
    setState(() {
      error = null;
      busy = true;
      status = st.t('verify_sending');
    });
    final code = st.store.startVerification(email);
    try {
      final r = await st.api.sendCode(email, code,
          subject: '{app}: password reset code {code}');
      if (r['ok'] == true) {
        setState(() {
          busy = false;
          codeSent = true;
          status = '${st.t('forgot_code_sent')} $email';
        });
      } else {
        setState(() {
          busy = false;
          status = '✗ ${r['error'] ?? st.t('contact_fail')}';
        });
      }
    } catch (_) {
      setState(() {
        busy = false;
        status = '✗ ${st.t('contact_fail')}';
      });
    }
  }

  Future<void> _confirm() async {
    final email = emailCtl.text.trim().toLowerCase();
    if (newPwCtl.text.length < 4) {
      setState(() => error = st.t('pw_too_short'));
      return;
    }
    final result = st.store.checkVerification(email, codeCtl.text.trim());
    if (result == 'expired') {
      setState(() => error = st.t('verify_expired'));
      return;
    }
    if (result != 'ok') {
      setState(() => error = st.t('verify_wrong'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await st.api.register(email, newPwCtl.text);
      if (r['ok'] != true && r['error'] != 'exists') {
        setState(() {
          busy = false;
          error = st.t('forgot_no_account');
        });
        return;
      }
    } catch (_) {
      setState(() {
        busy = false;
        error = st.t('contact_fail');
      });
      return;
    }
    setState(() {
      busy = false;
      status = st.t('forgot_ok');
    });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.of(context).pop();
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
      appBar: AppBar(backgroundColor: kBgDark),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(st.t('forgot_title'),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: st.accent.main),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(st.t('forgot_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMuted)),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: st.t('email')),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ],
                if (codeSent) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeCtl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(hintText: st.t('verify_code_ph')),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPwCtl,
                    obscureText: true,
                    decoration:
                        InputDecoration(hintText: st.t('forgot_new_pw_ph')),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: const TextStyle(color: Color(0xFFF87171))),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : (codeSent ? _confirm : _sendCode),
                    child: Text(codeSent
                        ? st.t('forgot_confirm_btn')
                        : st.t('forgot_send_code')),
                  ),
                ),
                if (codeSent)
                  TextButton(
                    onPressed: _showSpamHint,
                    child: Text(st.t('spam_hint_btn'),
                        style: const TextStyle(color: kMuted, fontSize: 11)),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(st.t('forgot_back'),
                      style: TextStyle(color: st.accent.main)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
