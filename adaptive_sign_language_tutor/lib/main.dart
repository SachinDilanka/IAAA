import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
import 'presentation/screens/avatar_lib/avatar_library_screen.dart';
import 'presentation/screens/dashboard/learning_path_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdaptiveSignTutorApp());
}

class AdaptiveSignTutorApp extends StatelessWidget {
  const AdaptiveSignTutorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(brightness: Brightness.dark, useMaterial3: true);

    return MaterialApp(
      title: 'Adaptive Sign Language Tutor',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1320),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme),
        cardTheme: const CardThemeData(
          color: Color(0xFF171F2D),
        ),
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
  int _selectedIndex = 0;

  static final List<Widget> _screens = [
    const LearningPathScreen(),
    const AvatarLibraryScreen(),
    const AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedItemColor: const Color(0xFF5B8CFF),
              unselectedItemColor: Colors.white60,
              selectedLabelStyle: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_books_rounded),
                  label: 'Library',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'Progress',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}