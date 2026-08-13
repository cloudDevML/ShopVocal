import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/auth_state.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/dashboard/presentation/dashboard_state.dart';
import 'features/inventory/presentation/inventory_screen.dart';
import 'features/inventory/presentation/inventory_state.dart';
import 'features/voice_assistant/presentation/voice_assistant_overlay.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Assistant Intelligent Commerçant',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Bascule automatique clair/sombre selon le système
      debugShowCheckedModeBanner: false,
      home: _getHomeScreen(authState.status),
    );
  }

  Widget _getHomeScreen(AuthStatus status) {
    switch (status) {
      case AuthStatus.initial:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.authenticated:
        return const MainDashboardScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      default:
        return const AuthScreen();
    }
  }
}

// Écran principal avec onglets et bouton assistant vocal
class MainDashboardScreen extends ConsumerStatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  ConsumerState<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends ConsumerState<MainDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    InventoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[MAIN] MainDashboardScreen.initState()');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authStatus = ref.read(authProvider).status;
      debugPrint('[MAIN] addPostFrameCallback → authStatus = $authStatus');
      if (authStatus == AuthStatus.authenticated) {
        debugPrint('[MAIN] → Chargement dashboard + inventory (initState)');
        ref.read(dashboardProvider.notifier).loadDashboard();
        ref.read(inventoryProvider.notifier).loadInventory();
      } else {
        debugPrint('[MAIN] ⚠️ Pas encore authentifié dans initState, en attente du ref.listen');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Écouter les changements d'auth pour recharger les données après login
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated &&
          previous?.status != AuthStatus.authenticated) {
        ref.read(dashboardProvider.notifier).loadDashboard();
        ref.read(inventoryProvider.notifier).loadInventory();
      }
    });

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primaryColor,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Comptabilité',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          VoiceAssistantOverlay.show(context);
        },
        backgroundColor: AppTheme.primaryColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.mic, color: Colors.white, size: 28),
      ),
    );
  }
}

