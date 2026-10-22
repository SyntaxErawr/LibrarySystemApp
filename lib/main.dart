import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student_shell.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/token_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LibrarySystemApp());
}

class LibrarySystemApp extends StatelessWidget {
  const LibrarySystemApp({super.key, this.auth});
  final AuthProvider? auth;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) =>
        (auth ?? AuthProvider(AuthService(ApiService()), SecureTokenStore()))
          ..restore(),
    child: MaterialApp(
      title: 'By the Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8DD),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF286444)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF286444),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFCEBC8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF286444),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const AuthGate(),
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _hadSession = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthProvider>().refreshStudent();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (_hadSession && auth.student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.read<AuthProvider>().student == null) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
    _hadSession = auth.student != null;
    if (auth.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.student == null
        ? const LoginScreen()
        : StudentShell(key: ValueKey(auth.student!.id));
  }
}
