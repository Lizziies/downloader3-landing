import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../constants.dart';
import '../theme.dart';
import '../update_checker.dart';
import 'download_tab.dart';
import 'convert_tab.dart';
import 'premium_tab.dart';
import 'send_file_tab.dart';
import 'helper_tab.dart';
import 'settings_tab.dart';
import 'admin_tab.dart';
import 'auth_screen.dart';

class HomeShell extends StatefulWidget {
final AppState state;
const HomeShell({super.key, required this.state});

@override
State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
int tab = 0;
UpdateInfo? update;

AppState get st => widget.state;

@override
void initState() {
super.initState();
_initUpdateCheck();
st.refreshPremiumStatus();
}

Future<void> _initUpdateCheck() async {
final info = await PackageInfo.fromPlatform();
final u = await checkForUpdate(info.version);
if (mounted) setState(() => update = u);
}

bool get isOwnerEmail =>
kOwnerEmails.contains((st.currentEmail ?? '').toLowerCase());

List<_NavItem> get _items => [
_NavItem(st.t('nav_download'), Icons.download_rounded,
(s) => DownloadTab(state: s)),
_NavItem(st.t('nav_convert'), Icons.transform_rounded,
(s) => ConvertTab(state: s)),
_NavItem(st.t('nav_sendfile'), Icons.send_rounded,
(s) => SendFileTab(state: s)),
_NavItem(st.t('nav_premium'), Icons.star_rounded,
(s) => PremiumTab(state: s)),
_NavItem(st.t('nav_helper'), Icons.favorite_rounded,
(s) => HelperTab(state: s)),
_NavItem(st.t('nav_settings'), Icons.settings_rounded,
(s) => SettingsTab(state: s)),
if (isOwnerEmail)
_NavItem(
st.t('nav_admin'), Icons.shield_rounded, (s) => AdminTab(state: s)),
];

@override
Widget build(BuildContext context) {
final items = _items;
final current = tab < items.length ? items[tab] : items[0];
return Scaffold(
backgroundColor: kBgDark,
appBar: AppBar(
backgroundColor: kBgDark,
title: Text(current.label, style: TextStyle(color: st.accent.main)),
),
drawer: Drawer(
backgroundColor: kCardDark,
child: SafeArea(
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
Padding(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
const Text('💜', style: TextStyle(fontSize: 26)),
const SizedBox(width: 10),
Text(st.t('home_title'),
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
color: st.accent.main)),
],
),
if (st.currentEmail != null) ...[
const SizedBox(height: 6),
Text(st.currentEmail!,
style: const TextStyle(fontSize: 12, color: kMuted)),
],
],
),
),
for (var i = 0; i < items.length; i++)
ListTile(
leading: Icon(items[i].icon,
color: tab == i ? st.accent.main : kMuted),
title: Text(items[i].label,
style: TextStyle(
color: tab == i ? st.accent.main : Colors.white)),
selected: tab == i,
onTap: () {
setState(() => tab = i);
Navigator.of(context).pop();
},
),
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
),
),
),
body: Column(
children: [
if (update != null) _UpdateBanner(info: update!, s: st),
Expanded(child: current.builder(st)),
],
),
);
}
}

class _NavItem {
final String label;
final IconData icon;
final Widget Function(AppState) builder;
_NavItem(this.label, this.icon, this.builder);
}

class _UpdateBanner extends StatelessWidget {
final UpdateInfo info;
final AppState s;
const _UpdateBanner({required this.info, required this.s});

@override
Widget build(BuildContext context) {
return Container(
width: double.infinity,
color: const Color(0xFF3A2E12),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
child: Row(
children: [
const Text('🚀', style: TextStyle(fontSize: 18)),
const SizedBox(width: 8),
Expanded(
child: Text('${s.t('update_available')}: v${info.version}',
style: const TextStyle(color: Colors.white)),
),
TextButton(
onPressed: () {
final url = info.apkUrl ?? info.htmlUrl;
if (url.isNotEmpty) {
launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
},
child: Text(s.t('update_now')),
),
],
),
);
}
}
