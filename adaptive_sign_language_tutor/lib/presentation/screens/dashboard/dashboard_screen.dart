import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/gesture_asset_paths.dart';
import '../analytics/analytics_screen.dart';
import '../avatar_lib/avatar_library_screen.dart';
import '../lesson/practice_workspace.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _userProgress;
  String _nextLetter = 'A';
  String? _nextReferenceAssetPath;
  String _nextMonth = 'ජනවාරි';
  String? _nextMonthReferenceAssetPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final progress = await DatabaseHelper.instance.getUserProgress();
    final nextLetter = await DatabaseHelper.instance.getNextLetter();
    final nextMonth = await DatabaseHelper.instance.getNextMonth();
    final nextPractice = await _findNextAvailablePractice(nextLetter);
    final nextMonthPractice = await _findNextAvailableMonth(nextMonth);

    if (!mounted) return;
    setState(() {
      _userProgress = progress;
      _nextLetter = nextPractice.$1;
      _nextReferenceAssetPath = nextPractice.$2;
      _nextMonth = nextMonthPractice.$1;
      _nextMonthReferenceAssetPath = nextMonthPractice.$2;
      _isLoading = false;
    });
  }

  Future<(String, String?)> _findNextAvailablePractice(
    String startingLetter,
  ) async {
    final startingCode = startingLetter.codeUnitAt(0);
    for (var offset = 0; offset < 26; offset++) {
      final letter = String.fromCharCode(
        65 + (startingCode - 65 + offset) % 26,
      );
      final assetPath = _referenceAssetPath(letter);
      if (assetPath == null) continue;
      try {
        await rootBundle.loadString(assetPath);
        return (letter, assetPath);
      } on FlutterError {
        continue;
      }
    }
    return (startingLetter, null);
  }

  String? _referenceAssetPath(String letter) {
    return GestureAssetPaths.forLetter(letter);
  }

  Future<(String, String?)> _findNextAvailableMonth(
    String startingMonth,
  ) async {
    final monthIndex = _months.indexOf(startingMonth);
    final startingIndex = monthIndex < 0 ? 0 : monthIndex;
    for (var offset = 0; offset < _months.length; offset++) {
      final month = _months[(startingIndex + offset) % _months.length];
      final assetPath = _monthReferenceAssetPath(month);
      try {
        await rootBundle.loadString(assetPath);
        return (month, assetPath);
      } on FlutterError {
        continue;
      }
    }
    return (startingMonth, null);
  }

  String _monthReferenceAssetPath(String month) {
    final englishMonth = _englishMonthName(month);
    return GestureAssetPaths.forMonth(englishMonth);
  }

  Future<void> _openNextPractice() async {
    final referenceAssetPath = _nextReferenceAssetPath;
    if (referenceAssetPath == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticeWorkspaceScreen(
          lessonId: null,
          lessonTitle: 'Letter $_nextLetter',
          referenceAssetPath: referenceAssetPath,
        ),
      ),
    );
    await _loadDashboardData();
  }

  Future<void> _openNextMonthPractice() async {
    final referenceAssetPath = _nextMonthReferenceAssetPath;
    if (referenceAssetPath == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticeWorkspaceScreen(
          lessonId: null,
          lessonTitle: _nextMonth,
          referenceAssetPath: referenceAssetPath,
        ),
      ),
    );
    await _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final double mastery = _userProgress?['overall_mastery'] ?? 0.0;
    final int streak = _userProgress?['daily_streak'] ?? 0;
    final int masteredSigns = _userProgress?['mastered_signs'] ?? 0;
    final int totalSigns = _userProgress?['total_signs'] ?? 26;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1320),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF4DA3FF),
              child: Text(
                'S',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning,',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                Text(
                  'Hi, Learner!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F5AEF), Color(0xFF5937FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4E64F9).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OVERALL MASTERY',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          masteredSigns == 0
                              ? 'Getting started'
                              : masteredSigns >= totalSigns
                              ? 'Advanced'
                              : 'In progress',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(mastery * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$masteredSigns of $totalSigns signs mastered',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMiniBadge(
                        Icons.check_circle,
                        '$masteredSigns/$totalSigns Mastered',
                      ),
                      const SizedBox(width: 12),
                      _buildMiniBadge(
                        Icons.local_fire_department,
                        '$streak Days Streak',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Continue Practice Section
            Text(
              'UP NEXT',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF171F2D),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF2D73FF),
                  child: Icon(Icons.play_arrow, color: Colors.white),
                ),
                title: Text(
                  _nextReferenceAssetPath == null
                      ? 'No more letters available'
                      : 'Letter "$_nextLetter"',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  _nextReferenceAssetPath == null
                      ? 'Gesture references are not available'
                      : 'Next in your alphabet practice • Beginner',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                onTap: _openNextPractice,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF171F2D),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF17B37B),
                  child: Icon(Icons.calendar_month, color: Colors.white),
                ),
                title: Text(
                  _nextMonthReferenceAssetPath == null
                      ? 'No month gestures available'
                      : '"$_nextMonth"',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  _nextMonthReferenceAssetPath == null
                      ? 'Gesture references are not available'
                      : 'Dynamic gesture practice • Beginner',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                onTap: _openNextMonthPractice,
              ),
            ),
            const SizedBox(height: 24),

            // Quick Access Cards Grid
            Text(
              'Quick Access',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickCard(
                    Icons.view_in_ar,
                    '3D Avatar Sign Library',
                    'Explore gestures',
                    Colors.purpleAccent.shade100,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AvatarLibraryScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickCard(
                    Icons.bar_chart,
                    'My Progress Analytics',
                    'Accuracy trends',
                    Colors.lightBlueAccent.shade100,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AnalyticsScreen(),
                        ),
                      );
                      await _loadDashboardData();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'ජනවාරි',
    'පෙබරවාරි',
    'මාර්තු',
    'අප්‍රේල්',
    'මැයි',
    'ජූනි',
    'ජූලි',
    'අගෝස්තු',
    'සැප්තැම්බර්',
    'ඔක්තෝබර්',
    'නොවැම්බර්',
    'දෙසැම්බර්',
  ];

  static const Map<String, String> _monthEnglishNames = {
    'ජනවාරි': 'January',
    'පෙබරවාරි': 'February',
    'මාර්තු': 'March',
    'අප්‍රේල්': 'April',
    'මැයි': 'May',
    'ජූනි': 'June',
    'ජූලි': 'July',
    'අගෝස්තු': 'August',
    'සැප්තැම්බර්': 'September',
    'ඔක්තෝබර්': 'October',
    'නොවැම්බර්': 'November',
    'දෙසැම්බර්': 'December',
  };

  static String _englishMonthName(String month) =>
      _monthEnglishNames[month] ?? month;

  Widget _buildQuickCard(
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF171F2D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
