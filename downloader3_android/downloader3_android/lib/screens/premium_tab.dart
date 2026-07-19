import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';

class PremiumTab extends StatefulWidget {
  final AppState state;
  const PremiumTab({super.key, required this.state});

  @override
  State<PremiumTab> createState() => _PremiumTabState();
}

class _PremiumTabState extends State<PremiumTab> {
  final codeCtl = TextEditingController();
  String? msg;
  Color msgColor = kMuted;
  bool busy = false;

  AppState get st => widget.state;

  /// 💳 Öffnet die Bezahlseite im Browser (PayPal-Checkout auf der
  /// Landing-Page) -- die App selbst wickelt keine Zahlung ab, genau
  /// wie am Desktop. Nach der Zahlung bekommt der Nutzer per Mail einen
  /// Code, den er hier im "Code einlösen"-Feld einträgt.
  Future<void> _buyPremium() async {
    final uri = Uri.parse('https://lizziies.github.io/downloader3-checkout/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _redeem() async {
    final email = st.currentEmail;
    if (email == null) return;
    setState(() => busy = true);
    try {
      final r = await st.api.redeemCode(codeCtl.text.trim(), email);
      if (r['ok'] == true) {
        final days = r['days'];
        String until;
        if (days == null) {
          until = 'forever';
        } else {
          until = DateTime.now()
              .add(Duration(days: (days as num).toInt()))
              .toIso8601String();
        }
        await st.store.setPremium(until, st.store.premiumRole);
        setState(() {
          busy = false;
          msg = st.t('code_ok');
          msgColor = const Color(0xFF34D399);
        });
      } else {
        setState(() {
          busy = false;
          msg = st.t('code_bad');
          msgColor = const Color(0xFFF87171);
        });
      }
    } catch (_) {
      setState(() {
        busy = false;
        msg = st.t('contact_fail');
        msgColor = const Color(0xFFF87171);
      });
    }
    st.refreshPremiumStatus();
  }

  // ✉️ Kleiner Feedback-Dialog, der denselben contactOwner()-Call
  // wiederverwendet wie die Settings-Seite -- so muss der Nutzer nicht
  // extra zu den Einstellungen wechseln, um ein Problem zu melden.
  Future<void> _showFeedbackDialog() async {
    final feedbackCtl = TextEditingController();
    bool sending = false;
    String? feedbackMsg;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> send() async {
              final text = feedbackCtl.text.trim();
              if (text.isEmpty) return;
              setDialogState(() => sending = true);
              try {
                final r = await st.api
                    .contactOwner(st.currentEmail ?? '', text, 'android-app-premium-tab');
                setDialogState(() {
                  sending = false;
                  if (r['ok'] == true) {
                    feedbackMsg = st.t('settings_contact_sent');
                    feedbackCtl.clear();
                  } else {
                    feedbackMsg = '✗ ${r['error'] ?? ''}';
                  }
                });
              } catch (_) {
                setDialogState(() {
                  sending = false;
                  feedbackMsg = st.t('contact_fail');
                });
              }
            }

            return AlertDialog(
              backgroundColor: kCardDark,
              title: Text(st.t('settings_contact_title'),
                  style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: feedbackCtl,
                    maxLines: 3,
                    decoration:
                        InputDecoration(hintText: st.t('settings_contact_msg_ph')),
                  ),
                  if (feedbackMsg != null) ...[
                    const SizedBox(height: 6),
                    Text(feedbackMsg!, style: const TextStyle(color: kMuted)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(st.t('forgot_back')),
                ),
                ElevatedButton(
                  onPressed: sending ? null : send,
                  child: Text(st.t('settings_contact_send')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = st.isPremium;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCardDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  isPremium ? st.t('premium_active') : st.t('premium_inactive'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? const Color(0xFF34D399) : kMuted,
                  ),
                ),
                if (isPremium && st.store.premiumUntil != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    st.store.premiumUntil == 'forever'
                        ? st.t('premium_forever')
                        : '${st.t('premium_until')}: ${st.store.premiumUntil}',
                    style: const TextStyle(color: kMuted),
                  ),
                ],
              ],
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _buyPremium,
              child: Text('⭐ ${st.t('buy_premium')}'),
            ),
            const SizedBox(height: 6),
            Text(
              st.t('buy_premium_desc'),
              style: const TextStyle(color: kMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 20),
          Text(st.t('redeem_code'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: codeCtl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: st.t('code_placeholder')),
          ),
          if (msg != null) ...[
            const SizedBox(height: 8),
            Text(msg!, style: TextStyle(color: msgColor)),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: busy ? null : _redeem,
            child: Text(st.t('redeem')),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _showFeedbackDialog,
            icon: const Icon(Icons.help_outline, color: kMuted),
            label: Text(st.t('premium_feedback'),
                style: const TextStyle(color: kMuted)),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';

class PremiumTab extends StatefulWidget {
  final AppState state;
  const PremiumTab({super.key, required this.state});

  @override
  State<PremiumTab> createState() => _PremiumTabState();
}

class _PremiumTabState extends State<PremiumTab> {
  final codeCtl = TextEditingController();
  String? msg;
  Color msgColor = kMuted;
  bool busy = false;

  AppState get st => widget.state;

  /// 💳 Öffnet die Bezahlseite im Browser (PayPal-Checkout auf der
  /// Landing-Page) -- die App selbst wickelt keine Zahlung ab, genau
  /// wie am Desktop. Nach der Zahlung bekommt der Nutzer per Mail einen
  /// Code, den er hier im "Code einlösen"-Feld einträgt.
  Future<void> _buyPremium() async {
    final uri = Uri.parse('https://lizziies.github.io/downloader3-checkout/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _redeem() async {
    final email = st.currentEmail;
    if (email == null) return;
    setState(() => busy = true);
    try {
      final r = await st.api.redeemCode(codeCtl.text.trim(), email);
      if (r['ok'] == true) {
        final days = r['days'];
        String until;
        if (days == null) {
          until = 'forever';
        } else {
          until = DateTime.now()
              .add(Duration(days: (days as num).toInt()))
              .toIso8601String();
        }
        await st.store.setPremium(until, st.store.premiumRole);
        setState(() {
          busy = false;
          msg = st.t('code_ok');
          msgColor = const Color(0xFF34D399);
        });
      } else {
        setState(() {
          busy = false;
          msg = st.t('code_bad');
          msgColor = const Color(0xFFF87171);
        });
      }
    } catch (_) {
      setState(() {
        busy = false;
        msg = st.t('contact_fail');
        msgColor = const Color(0xFFF87171);
      });
    }
    st.refreshPremiumStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = st.isPremium;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCardDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  isPremium ? st.t('premium_active') : st.t('premium_inactive'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPremium ? const Color(0xFF34D399) : kMuted,
                  ),
                ),
                if (isPremium && st.store.premiumUntil != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    st.store.premiumUntil == 'forever'
                        ? st.t('premium_forever')
                        : '${st.t('premium_until')}: ${st.store.premiumUntil}',
                    style: const TextStyle(color: kMuted),
                  ),
                ],
              ],
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _buyPremium,
              child: Text('⭐ ${st.t('buy_premium')}'),
            ),
            const SizedBox(height: 6),
            Text(
              st.t('buy_premium_desc'),
              style: const TextStyle(color: kMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 20),
          Text(st.t('redeem_code'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: codeCtl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: st.t('code_placeholder')),
          ),
          if (msg != null) ...[
            const SizedBox(height: 8),
            Text(msg!, style: TextStyle(color: msgColor)),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: busy ? null : _redeem,
            child: Text(st.t('redeem')),
          ),
        ],
      ),
    );
  }
}
