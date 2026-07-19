import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../theme.dart';
import '../update_checker.dart';
import 'auth_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../notification_helper.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
bool busyBackup = false;
String? backupMsg;

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

Future<File> _backupFile() async {
final dir = await getApplicationDocumentsDirectory();
return File('${dir.path}/downloader3_backup.json');
}

Future<void> _createBackup() async {
setState(() {
busyBackup = true;
backupMsg = null;
});
try {
final data = st.store.exportBackup();
final file = await _backupFile();
await file.writeAsString(jsonEncode(data));
setState(() {
busyBackup = false;
backupMsg = st.t('backup_created_success');
});
} catch (e) {
setState(() {
busyBackup = false;
backupMsg = '✗ ${st.t('backup_restore_failed')}';
});
}
}

Future<void> _restoreBackup() async {
setState(() {
busyBackup = true;
backupMsg = null;
});
try {
final file = await _backupFile();
if (!await file.exists()) {
setState(() {
busyBackup = false;
backupMsg = '✗ ${st.t('backup_restore_failed')}';
});
return;
}
final raw = await file.readAsString();
final data = jsonDecode(raw) as Map<String, dynamic>;
await st.store.importBackup(data);
setState(() {
busyBackup = false;
backupMsg = st.t('backup_restored_success');
});
} catch (e) {
setState(() {
busyBackup = false;
backupMsg = '✗ ${st.t('backup_restore_failed')}';
});
}
}

Future<void> _pickMatchingColor(BuildContext context) async {
Color picked = st.accent.main;
final result = await showDialog<Color>(
context: context,
builder: (ctx) => AlertDialog(
backgroundColor: kCardDark,
title: Text(st.t('matching_mode_title'),
style: const TextStyle(color: Colors.white)),
content: SingleChildScrollView(
child: ColorPicker(
pickerColor: picked,
onColorChanged: (c) => picked = c,
enableAlpha: false,
),
),
actions: [
TextButton(
onPressed: () => Navigator.of(ctx).pop(),
child: Text(st.language == 'de' ? 'Abbrechen' : 'Cancel'),
),
ElevatedButton(
onPressed: () => Navigator.of(ctx).pop(picked),
child: Text(st.t('matching_apply')),
),
],
),
);
if (result != null) {
setState(() => st.setMatchingAccent(result));
}
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
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(st.t('matching_mode_title'),
style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.bold)),
const SizedBox(height: 4),
Text(st.t('matching_mode_hint'),
style: const TextStyle(color: kMuted, fontSize: 12)),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: OutlinedButton(
onPressed: () => _pickMatchingColor(context),
child: Text(st.t('matching_apply')),
),
),
if (st.store.matchingModeEnabled) ...[
const SizedBox(width: 8),
Expanded(
child: OutlinedButton(
onPressed: () => setState(st.resetMatchingMode),
child: Text(st.t('matching_reset')),
),
),
],
],
),
],
),
),
const Divider(color: kCardDark2),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(st.t('settings_font_section_title'),
style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
Text(st.t('settings_font_family'),
style: const TextStyle(color: kMuted, fontSize: 12)),
DropdownButton<String>(
value: st.store.fontFamily,
dropdownColor: kCardDark2,
isExpanded: true,
items: kFontOptions
.map((f) => DropdownMenuItem(
value: f.key,
child: Text(f.label,
style: const TextStyle(color: Colors.white)),
))
.toList(),
onChanged: (v) {
if (v != null) setState(() => st.setFontFamily(v));
},
),
const SizedBox(height: 8),
Text(
'${st.t('settings_font_size')}: ${(st.store.fontSizeScale * 100).round()}%',
style: const TextStyle(color: kMuted, fontSize: 12)),
Slider(
value: st.store.fontSizeScale,
min: 0.8,
max: 1.5,
divisions: 14,
activeColor: st.accent.main,
label: '${(st.store.fontSizeScale * 100).round()}%',
onChanged: (v) => setState(() => st.setFontSizeScale(v)),
),
const SizedBox(height: 4),
OutlinedButton(
onPressed: () => setState(() {
st.setFontFamily('ComicNeue');
st.setFontSizeScale(1.1);
}),
child: Text(st.t('settings_font_comic_preset')),
),
],
),
),
const Divider(color: kCardDark2),
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
SwitchListTile(
title: Text(st.t('settings_notifications_enabled'),
style: const TextStyle(color: Colors.white)),
value: st.store.notificationsEnabled,
activeColor: st.accent.main,
onChanged: (v) => setState(() => st.store.notificationsEnabled = v),
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
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(st.t('settings_backup_section_title'),
style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
Row(
children: [
Expanded(
child: OutlinedButton(
onPressed: busyBackup ? null : _createBackup,
child: Text(st.t('settings_backup_create')),
),
),
const SizedBox(width: 8),
Expanded(
child: OutlinedButton(
onPressed: busyBackup ? null : _restoreBackup,
child: Text(st.t('settings_backup_restore')),
),
),
],
),
if (backupMsg != null) ...[
const SizedBox(height: 6),
Text(backupMsg!, style: const TextStyle(color: kMuted)),
],
],
),
),
SwitchListTile(
title: Text(st.t('settings_auto_backup'),
style: const TextStyle(color: Colors.white)),
value: st.store.autoBackupEnabled,
activeColor: st.accent.main,
onChanged: (v) => setState(() => st.store.autoBackupEnabled = v),
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
