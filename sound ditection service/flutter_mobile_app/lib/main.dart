import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai/sound_classifier_service.dart';
import 'wearable/smartwatch_service.dart';
import 'storage/history_database.dart';

import 'screens/home_screen.dart';
import 'screens/detection_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final historyDb = HistoryDatabase();
  await historyDb.loadHistory();

  final soundClassifierService = SoundClassifierService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: soundClassifierService),
        ChangeNotifierProvider.value(value: SmartwatchService()),
        ChangeNotifierProvider.value(value: historyDb),
      ],
      child: const SoundAlertApp(),
    ),
  );
}

class SoundAlertApp extends StatelessWidget {
  const SoundAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcousticAware DEAF AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'NotoSansSinhala',
        fontFamilyFallback: const ['NotoSansSinhala', 'Arial', 'sans-serif'],
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Natural Deep Slate 900
        primaryColor: const Color(0xFF2563EB), // Natural Cobalt Blue
        cardColor: const Color(0xFF1E293B), // Natural Slate 800
        dividerColor: const Color(0xFF334155), // Natural Slate 700
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF059669),
          surface: Color(0xFF1E293B),
          error: Color(0xFFDC2626),
        ),
        useMaterial3: true,
      ),
      home: const NavigationHostScreen(),
    );
  }
}

class NavigationHostScreen extends StatefulWidget {
  const NavigationHostScreen({super.key});


  @override
  State<NavigationHostScreen> createState() => _NavigationHostScreenState();
}

class _NavigationHostScreenState extends State<NavigationHostScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    DetectionScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF2563EB).withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF3B82F6)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_rounded),
            selectedIcon: Icon(Icons.graphic_eq_rounded, color: Color(0xFF3B82F6)),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF3B82F6)),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF3B82F6)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

