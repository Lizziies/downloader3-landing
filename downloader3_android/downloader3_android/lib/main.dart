import 'package:flutter/material.dart';
import 'app_state.dart';
import 'auth_store.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'notification_helper.dart';

void main() {
  runApp(const Downloader3App());
}

class Downloader3App extends StatefulWidget {
  const Downloader3App({super.key});

  @override
  State<Downloader3App> createState() => _Downloader3AppState();
}

class _Downloader3AppState extends State<Downloader3App> {
  AppState? appState;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final store = await AuthStore.load();
    await NotificationHelper.init();
    await NotificationHelper.requestPermission();
    if (store.autoBackupEnabled) {
      await _maybeAutoBackup(store);
    }
    setState(() => appState = AppState(store));
  }

  /// 💾 Einfacher Auto-Backup-Check beim App-Start: schreibt höchstens
  /// einmal alle 24 Stunden eine Sicherung in den Dokumente-Ordner --
  /// bewusst kein Background-Scheduling (z. B. WorkManager), das wäre
  /// für diesen Zweck überdimensioniert.
  Future<void> _maybeAutoBackup(AuthStore store) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/downloader3_backup.json');
      final now = DateTime.now();
      if (await file.exists()) {
        final mtime = await file.lastModified();
        if (now.difference(mtime) < const Duration(hours: 24)) return;
      }
      await file.writeAsString(jsonEncode(store.exportBackup()));
    } catch (_) {
      // ⚠️ Auto-Backup darf den App-Start niemals blockieren/crashen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = appState;
    if (state == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(kAccents[0]),
        home: const SplashScreen(),
      );
    }
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final loggedIn = state.currentEmail != null;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Downloader<3',
          theme: buildAppTheme(state.accent),
          home: loggedIn ? HomeShell(state: state) : AuthScreen(state: state),
        );
      },
    );
  }
}
