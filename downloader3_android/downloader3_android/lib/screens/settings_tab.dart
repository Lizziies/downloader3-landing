import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';
import '../update_checker.dart';
import 'auth_screen.dart';

class SettingsTab extends StatefulWidget {
final AppState state;
const SettingsTab({super.key, required this.state});

@override
State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
final contactCtl = TextEditingController();
String? updateMsg;
String? contactMsg;
bool busyUpdate = false;
bool busyContact = false;

AppState get st => widget.state;

Future<void> _checkUpdate() async {
setState(() {
busyUpdate = true;
updateMsg = null;
});
final pkg = await PackageInfo.fromPlatform();
final info = await checkForUpdate(pkg.version);
setState(() {
busyUpdate = false;
updateMsg = info != null
? '🚀 ${st.t('update_available')}: v${info.version}'
: st.t('up_to_date');
});
}

Future<void> _visitWebsite() async {
final uri = Uri.parse('https://lizziies.github.io/downloader3-landing/');
await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _sendContact() async {
final msg = contactCtl.text.trim();
if (msg.isEmpty) return;
setState(() {
busyContact = true;
contactMsg = null;
});
final r = await st.api
.contactOwner(st.currentEmail ?? '', msg, 'android-app');
setState(() {
busyContact = false;
if (r['ok'] == true) {
contactMsg = st.t('settings_contact_sent');
contactCtl.clear();
} else {
contactMsg = '✗ ${r['error'] ?? ''}';
}
});
}

@override
Widget build(BuildContext context) {
return ListView(
padding: const EdgeInsets.all(16),
children: [
Text(st.t('settings_title'),
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: st.accent.main)),
const SizedBox(height: 12),
ListTile(
leading: const Icon(Icons.language, color: kMuted),
title: const Text('🌐 Deutsch / English',
style: TextStyle(color: Colors.white)),
onTap: st.toggleLanguage,
),
const Divider(color: kCardDark2),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(st.t('settings_accent'),
style: const TextStyle(color: kMuted, fontSize: 12)),
const SizedBox(height: 8),
Wrap(
spacing: 10,
children: kAccents
.map((a) => GestureDetector(
onTap: () => st.setAccent(a.name),
child: CircleAvatar(
backgroundColor: a.main,
radius: 16,
child: st.store.accent == a.name
? const Icon(Icons.check,
color: Colors.white, size: 16)
: null,
),
))
.toList(),
),
],
),
),
const Divider(color: kCardDark2),
SwitchListTile(
title: Text(st.t('settings_wifi_priority'),
style: const TextStyle(color: Colors.white)),
value: st.store.wifiPriority,
activeColor: st.accent.main,
onChanged: (v) => setState(() => st.store.wifiPriority = v),
),
SwitchListTile(
title: Text(st.t('settings_mobile_data_allowed'),
style: const TextStyle(color: Colors.white)),
value: st.store.mobileDataAllowed,
activeColor: st.accent.main,
onChanged: (v) => setState(() => st.store.mobileDataAllowed = v),
),
const Divider(color: kCardDark2),
ListTile(
leading: const Icon(Icons.system_update, color: kMuted),
title: Text(st.t('settings_check_update'),
style: const TextStyle(color: Colors.white)),
subtitle: updateMsg != null
? Text(updateMsg!, style: const TextStyle(color: kMuted))
: null,
trailing: busyUpdate
? const SizedBox(
width: 18,
height: 18,
child: CircularProgressIndicator(strokeWidth: 2))
: null,
onTap: busyUpdate ? null : _checkUpdate,
),
ListTile(
leading: const Icon(Icons.public, color: kMuted),
title: Text(st.t('settings_visit_website'),
style: const TextStyle(color: Colors.white)),
onTap: _visitWebsite,
),
const Divider(color: kCardDark2),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(st.t('settings_contact_title'),
style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
TextField(
controller: contactCtl,
maxLines: 3,
decoration: InputDecoration(
hintText: st.t('settings_contact_msg_ph')),
),
if (contactMsg != null) ...[
const SizedBox(height: 6),
Text(contactMsg!, style: const TextStyle(color: kMuted)),
],
const SizedBox(height: 8),
ElevatedButton(
onPressed: busyContact ? null : _sendContact,
child: Text(st.t('settings_contact_send')),
),
],
),
),
const Divider(color: kCardDark2),
ListTile(
leading: const Icon(Icons.logout, color: Color(0xFFF87171)),
title: Text(st.t('logout'),
style: const TextStyle(color: Color(0xFFF87171))),
onTap: () async {
await st.logout();
if (context.mounted) {
Navigator.of(context).pushAndRemoveUntil(
MaterialPageRoute(builder: (_) => AuthScreen(state: st)),
(route) => false,
);
}
},
),
],
);
}
}
