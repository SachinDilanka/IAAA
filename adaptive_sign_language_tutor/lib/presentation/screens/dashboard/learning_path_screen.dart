import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/gesture_asset_paths.dart';
import '../analytics/analytics_screen.dart';
import '../avatar_lib/avatar_library_screen.dart';
import '../lesson/practice_workspace.dart';

class LearningPathScreen extends StatefulWidget {
  const LearningPathScreen({super.key});

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  Map<String, dynamic>? _userProgress;
  String _nextLetter = 'A';
  String? _nextLetterAsset;
  String _nextMonth = 'ජනවාරි';
  String? _nextMonthAsset;
  bool _isLoading = true;

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

  static const _monthEnglishNames = {
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

  @override
  void initState() {
    super.initState();
    _loadPathData();
  }

  Future<void> _loadPathData() async {
    final progress = await DatabaseHelper.instance.getUserProgress();
    final letter = await DatabaseHelper.instance.getNextLetter();
    final month = await DatabaseHelper.instance.getNextMonth();
    final letterPractice = await _findNextAvailableLetter(letter);
    final monthPractice = await _findNextAvailableMonth(month);

    if (!mounted) return;
    setState(() {
      _userProgress = progress;
      _nextLetter = letterPractice.$1;
      _nextLetterAsset = letterPractice.$2;
      _nextMonth = monthPractice.$1;
      _nextMonthAsset = monthPractice.$2;
      _isLoading = false;
    });
  }

  Future<(String, String?)> _findNextAvailableLetter(String start) async {
    final startCode = start.codeUnitAt(0);
    for (var offset = 0; offset < 26; offset++) {
      final letter = String.fromCharCode(65 + (startCode - 65 + offset) % 26);
      final path = GestureAssetPaths.forLetter(letter);
      if (path == null) continue;
      try {
        await rootBundle.loadString(path);
        return (letter, path);
      } on FlutterError {
        continue;
      }
    }
    return (start, null);
  }

  Future<(String, String?)> _findNextAvailableMonth(String start) async {
    final startIndex = _months.indexOf(start);
    final normalizedIndex = startIndex < 0 ? 0 : startIndex;
    for (var offset = 0; offset < _months.length; offset++) {
      final month = _months[(normalizedIndex + offset) % _months.length];
      final english = _monthEnglishNames[month]!;
      final path = GestureAssetPaths.forMonth(english);
      try {
        await rootBundle.loadString(path);
        return (month, path);
      } on FlutterError {
        continue;
      }
    }
    return (start, null);
  }

  Future<void> _startPractice({
    required String title,
    required String? assetPath,
  }) async {
    if (assetPath == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PracticeWorkspaceScreen(
          lessonId: null,
          lessonTitle: title,
          referenceAssetPath: assetPath,
        ),
      ),
    );
    await _loadPathData();
  }

  Future<void> _openLibrary() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const AvatarLibraryScreen(),
      ),
    );
  }

  Future<void> _openProgress() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const AnalyticsScreen(),
      ),
    );
    await _loadPathData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mastery = (_userProgress?['overall_mastery'] as num? ?? 0).toDouble();
    final mastered = _userProgress?['mastered_signs'] as int? ?? 0;
    final total = _userProgress?['total_signs'] as int? ?? 38;
    final streak = _userProgress?['daily_streak'] as int? ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101820),
        title: Text(
          'Lesson Pathways',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _topBadge(Icons.bolt_rounded, '$mastered'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlayerCard(
              mastery: mastery,
              mastered: mastered,
              total: total,
              streak: streak,
            ),
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR ADVENTURE',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF76D7D0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Choose your next quest',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$mastered/$total signs',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            _buildWorldHeader(),
            const SizedBox(height: 15),
            _buildPathNode(
              number: '01',
              title: 'Letter $_nextLetter',
              subtitle: 'SSL Alphabet • Start a practice round',
              icon: Icons.front_hand_rounded,
              color: const Color(0xFF69D5D2),
              unlocked: _nextLetterAsset != null,
              alignment: Alignment.centerLeft,
              onTap: () => _startPractice(
                title: 'Letter $_nextLetter',
                assetPath: _nextLetterAsset,
              ),
            ),
            _buildPathConnector(
              color: _nextLetterAsset == null
                  ? Colors.white24
                  : const Color(0xFF69D5D2),
              alignment: Alignment.centerLeft,
            ),
            _buildPathNode(
              number: '02',
              title: _nextMonth,
              subtitle: 'Month signs • Your next challenge',
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF70C9FF),
              unlocked: _nextMonthAsset != null,
              alignment: Alignment.centerRight,
              onTap: () => _startPractice(
                title: _nextMonth,
                assetPath: _nextMonthAsset,
              ),
            ),
            _buildPathConnector(
              color: _nextMonthAsset == null
                  ? Colors.white24
                  : const Color(0xFF70C9FF),
              alignment: Alignment.centerRight,
            ),
            _buildPathNode(
              number: '03',
              title: 'Explore the library',
              subtitle: 'Choose any available sign to practice',
              icon: Icons.auto_stories_rounded,
              color: const Color(0xFFB79AFF),
              unlocked: true,
              alignment: Alignment.centerLeft,
              onTap: _openLibrary,
            ),
            _buildPathConnector(
              color: const Color(0xFFB79AFF),
              alignment: Alignment.centerLeft,
            ),
            _buildPathNode(
              number: '04',
              title: 'Progress hub',
              subtitle: 'Review your accuracy and practice streak',
              icon: Icons.emoji_events_rounded,
              color: const Color(0xFFFFCF70),
              unlocked: true,
              alignment: Alignment.centerRight,
              onTap: _openProgress,
            ),
            const SizedBox(height: 17),
            Center(
              child: Text(
                'Every sign brings you one step closer!',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required double mastery,
    required int mastered,
    required int total,
    required int streak,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B46), Color(0xFF1A2C40), Color(0xFF282644)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF75D8D2).withValues(alpha: .2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF39C8B7).withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF72D9CE).withValues(alpha: .18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF72D9CE).withValues(alpha: .45),
                  ),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFF83E4D8),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIGN QUEST',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    Text(
                      mastered == 0 ? 'New Explorer' : 'Sign Explorer',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _topBadge(Icons.local_fire_department_rounded, '$streak days'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PATH PROGRESS',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${(mastery * 100).round()}%',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF8EE5DB),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: mastery.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: .12),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF75D8D2)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$mastered of $total signs mastered',
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF25323D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.public_rounded,
            color: Color(0xFF77D7D0),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SSL Sign World',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildPathNode({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool unlocked,
    required Alignment alignment,
    required VoidCallback onTap,
  }) {
    final nodeColor = unlocked ? color : Colors.blueGrey.shade400;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Opacity(
            opacity: unlocked ? 1 : .56,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: unlocked ? onTap : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF24323D),
                        nodeColor.withValues(alpha: unlocked ? .12 : .04),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: nodeColor.withValues(alpha: unlocked ? .42 : .2),
                    ),
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: nodeColor.withValues(alpha: .08),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: nodeColor.withValues(alpha: .16),
                          border: Border.all(
                            color: nodeColor.withValues(alpha: .8),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          unlocked ? icon : Icons.lock_rounded,
                          color: nodeColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEVEL $number',
                              style: GoogleFonts.poppins(
                                color: nodeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        unlocked
                            ? Icons.play_circle_fill_rounded
                            : Icons.lock_outline_rounded,
                        color: nodeColor,
                        size: 25,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPathConnector({
    required Color color,
    required Alignment alignment,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.only(left: 23, right: 23),
        child: SizedBox(
          height: 34,
          child: Column(
            children: [
              Container(
                width: 2,
                height: 20,
                color: color.withValues(alpha: .55),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: color.withValues(alpha: .85),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF24323D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFFD16E)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
