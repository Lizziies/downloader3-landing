import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import 'verify_screen.dart';
import 'forgot_password_screen.dart';
import 'home_shell.dart';

class AuthScreen extends StatefulWidget {
  final AppState state;
  const AuthScreen({super.key, required this.state});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String mode = 'register';
  final emailCtl = TextEditingController();
  final pwCtl = TextEditingController();
  String? error;
  bool busy = false;

  AppState get st => widget.state;

  bool _validEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  Future<void> _submit() async {
    final email = emailCtl.text.trim().toLowerCase();
    final pw = pwCtl.text;
    if (!_validEmail(email)) {
      setState(() => error = st.t('invalid_email'));
      return;
    }
    if (pw.length < 4) {
      setState(() => error = st.t('pw_too_short'));
      return;
    }
    setState(() {
      busy = true;
      error = st.t('checking_account');
    });

    final deviceVerifiedKey = 'device_verified_$email';
    final alreadyVerifiedHere =
        st.store.prefs.getBool(deviceVerifiedKey) ?? false;

    Map<String, dynamic> result;
    try {
      if (mode == 'register') {
        result = await st.api.register(email, pw);
        if (result['ok'] != true) {
          setState(() {
            busy = false;
            error = (result['error'] == 'exists')
                ? st.t('user_exists')
                : st.t('no_backend');
          });
          return;
        }
      } else {
        result = await st.api.login(email, pw);
        if (result['ok'] != true) {
          setState(() {
            busy = false;
            error = st.t('wrong_login');
          });
          return;
        }
      }
    } catch (_) {
      setState(() {
        busy = false;
        error = st.t('no_backend');
      });
      return;
    }

    await st.store.setCurrentEmail(email);
    setState(() => busy = false);
    if (!mounted) return;

    if (alreadyVerifiedHere) {
      await _goHome();
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerifyScreen(
        state: st,
        email: email,
        onVerified: () async {
          await st.store.prefs.setBool(deviceVerifiedKey, true);
          await _goHome();
        },
      ),
    ));
  }

  Future<void> _goHome() async {
    await st.refreshPremiumStatus();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeShell(state: st)),
      (route) => false,
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
                const Text('💜', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(
                  st.t('welcome'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: st.accent.main,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(st.toggleLanguage),
                  child: const Text(
                    '🌐 Deutsch / English',
                    style: TextStyle(color: kMuted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  mode == 'register' ? st.t('create_account') : st.t('login'),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: st.t('email')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pwCtl,
                  obscureText: true,
                  decoration: InputDecoration(hintText: st.t('password')),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(color: Color(0xFFF87171)),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(mode == 'register'
                            ? st.t('register')
                            : st.t('login')),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    mode = mode == 'register' ? 'login' : 'register';
                    error = null;
                  }),
                  child: Text(
                    mode == 'register' ? st.t('have_account') : st.t('no_account'),
                    style: TextStyle(color: st.accent.main),
                  ),
                ),
                if (mode == 'login')
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordScreen(
                          state: st,
                          prefillEmail: emailCtl.text.trim(),
                        ),
                      ),
                    ),
                    child: Text(
                      st.t('forgot_password'),
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
