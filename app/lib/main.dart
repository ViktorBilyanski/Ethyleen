import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/alert_service.dart';
import 'services/firebase_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final settings = SettingsService();
  await settings.load();

  // Initialize local alert notifications
  final alertService = AlertService();
  await alertService.initialize();
  alertService.startListening();

  runApp(const EthyleenApp());
}

class EthyleenApp extends StatelessWidget {
  const EthyleenApp({super.key});

  static final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121220),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF42A5F5),
      surface: Color(0xFF1E1E2E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121220),
      elevation: 0,
      centerTitle: true,
    ),
  );

  static final _lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1A73E8),
      surface: Colors.white,
      onSurface: Color(0xFF202124),
      surfaceContainerHighest: Color(0xFFF1F3F4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Color(0xFF202124),
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService().isDarkMode,
      builder: (_, isDark, __) => MaterialApp(
        title: 'Ethyleen',
        debugShowCheckedModeBanner: false,
        theme: isDark ? _darkTheme : _lightTheme,
        home: SettingsService().onboardingCompleted
            ? const MainScreen()
            : const _OnboardingGate(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final FirebaseService _firebase = FirebaseService();

  final _screens = const [
    DashboardScreen(),
    HistoryScreen(),
  ];

  void _showCalibrateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Calibrate Sensors'),
        content: const Text(
          'Place the device in your fridge with only fresh food (no spoiled items). '
          'The device will measure the environment for ~25 seconds and set it as the new baseline.\n\n'
          'Make sure the fridge door stays closed during calibration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startCalibration();
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _startCalibration() {
    _firebase.startCalibration();

    late final subscription;
    subscription = _firebase.calibrationStream.listen((data) {
      if (data == null) return;
      final status = data['status'] as String?;

      if (status == 'calibrating') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calibrating sensors... keep the fridge closed.'),
            duration: Duration(seconds: 20),
          ),
        );
      } else if (status == 'done') {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Calibration complete! R0: '
              'MQ135=${data['mq135_r0']?.toStringAsFixed(2)}  '
              'MQ3=${data['mq3_r0']?.toStringAsFixed(2)}  '
              'MQ9=${data['mq9_r0']?.toStringAsFixed(2)}',
            ),
            duration: const Duration(seconds: 6),
            backgroundColor: const Color(0xFF66BB6A),
          ),
        );
        subscription.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, color: Color(0xFF66BB6A), size: 22),
            SizedBox(width: 8),
            Text(
              'Ethyleen',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, size: 22),
            tooltip: 'Calibrate sensors',
            onPressed: _showCalibrateDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        selectedItemColor: const Color(0xFF42A5F5),
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      onComplete: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      },
    );
  }
}
