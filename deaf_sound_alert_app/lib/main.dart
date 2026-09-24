import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/sound_config_screen.dart';
import 'screens/smartwatch_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const DeafSoundAlertApp(),
    ),
  );
}

class DeafSoundAlertApp extends StatelessWidget {
  const DeafSoundAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deaf Alert - Sinhala & Sound Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF059669),
          surface: Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HistoryScreen(),
    SoundConfigScreen(),
    SmartwatchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D2FF)),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF111A2E),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: provider.isListening
                        ? const Color(0xFFFF3B30).withValues(alpha: 0.2)
                        : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hearing_rounded,
                    color: provider.isListening
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF00D2FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEAF SOUND ALERT',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      provider.isListening ? '● LIVE LISTENING' : 'OFFLINE MODE',
                      style: TextStyle(
                        color: provider.isListening
                            ? const Color(0xFFFF3B30)
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.watch_rounded,
                  color: provider.isSmartwatchConnected
                      ? const Color(0xFF34C759)
                      : Colors.white38,
                ),
                onPressed: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: const Color(0xFF111A2E),
            selectedItemColor: const Color(0xFF00D2FF),
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Monitor',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.tune_rounded),
                label: 'Sound Priority',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.watch_rounded),
                label: 'Smartwatch',
              ),
            ],
          ),
        );
      },
    );
  }
}
