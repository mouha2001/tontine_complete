import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/tontines/tontines_screen.dart';
import 'screens/cotisations/cotisations_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Barre de statut transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const TontineApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  APP ROOT
// ─────────────────────────────────────────────────────────
class TontineApp extends StatelessWidget {
  const TontineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tontine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _AppShell(),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  SHELL — gère auth vs app
// ─────────────────────────────────────────────────────────
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  @override
  void initState() {
    super.initState();
    // Vérifie le token au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Splash pendant la vérification
    if (auth.status == AuthStatus.unknown) {
      return Scaffold(
        backgroundColor: AppColors.primary,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.savings_rounded, color: AppColors.accent, size: 64),
                SizedBox(height: 24),
                Text('Tontine',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
                SizedBox(height: 32),
                CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Non authentifié → Login
    if (auth.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    // Authentifié → App principale
    return const _MainNav();
  }
}

// ─────────────────────────────────────────────────────────
//  NAVIGATION PRINCIPALE
// ─────────────────────────────────────────────────────────
class _MainNav extends StatefulWidget {
  const _MainNav();

  @override
  State<_MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<_MainNav> {
  int _index = 0;
  int _unread = 0;
  DateTime? _lastBack;
  final _api = ApiService();

  final _screens = const [
    DashboardScreen(),
    TontinesScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final n = await _api.getUnreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  void _onTap(int i) {
    setState(() => _index = i);
    _lastBack = null; // le double-tap n'exige que deux « retour » consécutifs
    // rafraîchit le compteur (ex. après avoir consulté/lu les alertes)
    _loadUnread();
  }

  Widget _alertIcon(IconData icon) => _unread > 0
      ? Badge.count(count: _unread, child: Icon(icon))
      : Icon(icon);

  void _handleBack() {
    // Sur un onglet autre que l'Accueil → revenir à l'Accueil
    if (_index != 0) {
      setState(() => _index = 0);
      _lastBack = null;
      return;
    }
    // Sur l'Accueil → double-tap pour quitter
    final now = DateTime.now();
    if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Appuyez encore pour quitter'),
        duration: Duration(seconds: 2),
      ));
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: _screens,
        ),
        bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTap,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.savings_outlined),
              activeIcon: Icon(Icons.savings_rounded),
              label: 'Tontines',
            ),
            BottomNavigationBarItem(
              icon: _alertIcon(Icons.notifications_outlined),
              activeIcon: _alertIcon(Icons.notifications_rounded),
              label: 'Alertes',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
        ),
      ),
    );
  }
}