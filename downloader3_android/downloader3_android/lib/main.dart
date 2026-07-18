import 'package:flutter/material.dart';
import 'app_state.dart';
import 'auth_store.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

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
    setState(() => appState = AppState(store));
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
