import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

/// 👑 Pendant zu page_admin() in main.py — nur für die beiden
/// OWNER_EMAILS sichtbar (siehe constants.dart + home_shell.dart), und
/// selbst dann erst nach einer erfolgreichen /api/verify-owner-Prüfung.
/// JEDE einzelne Aktion hier schickt zusätzlich das Owner-Passwort mit
/// (server-seitige Prüfung, siehe app.py) — der lokale E-Mail-Check ist
/// nur fürs Ein-/Ausblenden im Menü, keine echte Zugriffskontrolle.
class AdminTab extends StatefulWidget {
  final AppState state;
  const AdminTab({super.key, required this.state});

  @override
  State<AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<AdminTab> {
  final ownerPwCtl = TextEditingController();
  final emailCtl = TextEditingController();
  final daysCtl = TextEditingController();
  String? unlockError;
  String? msg;
  Color msgColor = kMuted;
  bool busy = false;
  List<Map<String, dynamic>> accounts = [];

  AppState get st => widget.state;

  Future<void> _unlock() async {
    final email = st.currentEmail ?? '';
    setState(() {
      busy = true;
      unlockError = null;
    });
    final r = await st.api.verifyOwner(email, ownerPwCtl.text);
    setState(() => busy = false);
    if (r['ok'] == true) {
      await st.setOwnerPassword(ownerPwCtl.text);
    } else {
      setState(() => unlockError = st.t('admin_wrong_pw'));
    }
  }

  int? get _days {
    final t = daysCtl.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _runAction(
      Future<Map<String, dynamic>> Function(String pw) call) async {
    final pw = st.ownerPassword;
    if (pw == null) return;
    setState(() {
      busy = true;
      msg = null;
    });
    final r = await call(pw);
    setState(() {
      busy = false;
      if (r['ok'] == true) {
        msg = st.t('admin_ok');
        msgColor = const Color(0xFF34D399);
      } else {
        msg = '✗ ${r['error'] ?? ''}';
        msgColor = const Color(0xFFF87171);
      }
    });
  }

  Future<void> _loadAccounts() async {
    final pw = st.ownerPassword;
    if (pw == null) return;
    setState(() => busy = true);
    final r = await st.api.adminListAccounts(pw);
    setState(() {
      busy = false;
      if (r['ok'] == true) {
        accounts = (r['accounts'] as List? ?? [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      } else {
        msg = '✗ ${r['error'] ?? ''}';
        msgColor = const Color(0xFFF87171);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!st.isOwnerUnlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text(st.t('admin_unlock_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted)),
              const SizedBox(height: 14),
              TextField(
                controller: ownerPwCtl,
                obscureText: true,
                decoration:
                    InputDecoration(hintText: st.t('admin_owner_pw_ph')),
              ),
              if (unlockError != null) ...[
                const SizedBox(height: 8),
                Text(unlockError!,
                    style: const TextStyle(color: Color(0xFFF87171))),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: busy ? null : _unlock,
                child: Text(st.t('admin_unlock_btn')),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(st.t('admin_title'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: st.accent.main)),
          const SizedBox(height: 14),
          TextField(
            controller: emailCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: st.t('admin_email_ph')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: daysCtl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: st.t('admin_days_ph')),
          ),
          if (msg != null) ...[
            const SizedBox(height: 8),
            Text(msg!, style: TextStyle(color: msgColor)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () => _runAction((pw) => st.api.adminGrantPremium(
                        pw, emailCtl.text.trim().toLowerCase(), _days)),
                child: Text(st.t('admin_grant_btn')),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _runAction((pw) => st.api.adminRevokePremium(
                        pw, emailCtl.text.trim().toLowerCase())),
                child: Text(st.t('admin_revoke_btn')),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _runAction((pw) => st.api.adminDeleteAccount(
                        pw, emailCtl.text.trim().toLowerCase())),
                child: Text(st.t('admin_delete_btn')),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _runAction((pw) => st.api.adminSetHelper(
                        pw, emailCtl.text.trim().toLowerCase(), true)),
                child: Text(st.t('admin_make_helper_btn')),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _runAction((pw) => st.api.adminSetHelper(
                        pw, emailCtl.text.trim().toLowerCase(), false)),
                child: Text(st.t('admin_unmake_helper_btn')),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _runAction((pw) => st.api.adminCreateCode(pw, _days)),
                child: Text(st.t('admin_create_code_btn')),
              ),
            ],
          ),
          const Divider(color: kCardDark2, height: 32),
          Text(st.t('admin_accounts_title'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : _loadAccounts,
            child: Text(st.t('admin_load_accounts')),
          ),
          const SizedBox(height: 10),
          ...accounts.map((a) => ListTile(
                dense: true,
                title: Text(a['email'] ?? '',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                    'premium: ${a['premium_until'] ?? '-'}  ·  role: ${a['role'] ?? '-'}',
                    style: const TextStyle(color: kMuted, fontSize: 11)),
              )),
        ],
      ),
    );
  }
}
