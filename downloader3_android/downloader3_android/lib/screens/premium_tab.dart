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
