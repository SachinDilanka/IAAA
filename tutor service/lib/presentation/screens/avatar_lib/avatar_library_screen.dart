import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/gesture_asset_paths.dart';
import '../lesson/practice_workspace.dart';

class AvatarLibraryScreen extends StatefulWidget {
  const AvatarLibraryScreen({super.key});

  @override
  State<AvatarLibraryScreen> createState() => _AvatarLibraryScreenState();
}

enum _LibraryCategory { alphabet, months, verbs }

class _AvatarLibraryScreenState extends State<AvatarLibraryScreen> {
  String _searchQuery = '';
  _LibraryCategory _selectedCategory = _LibraryCategory.alphabet;

  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
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

  static const Map<String, String> _verbs = {
    'adinawa': 'අදිනවා',
    'adum_sodanawa': 'ඇඳුම් සෝදනවා',
    'ahanawa': 'අහනවා',
    'andanawa': 'අඬනවා',
    'athu_gaanawa': 'අතු ගානවා',
    'awidinawa': 'ඇවිදිනවා',
    'bonawa': 'බොනවා',
    'duwanawa': 'දුවනවා',
    'hinawenawa': 'හිනාවෙනවා',
    'kaamak_hadanawa': 'කෑමක් හදනවා',
    'kanawa': 'කනවා',
    'liyanawa': 'ලියනවා',
    'muuna_soodanawa': 'මූණ සෝදනවා',
    'naanawa': 'නානවා',
    'nagitinawa': 'නැගිටිනවා',
    'paadam_karanawa': 'පාඩම් කරනවා',
    'paninawa': 'පනිනවා',
    'soynawa': 'සොයනවා',
    'udaw_karanawa': 'උදව් කරනවා',
    'waadi_wenawa': 'වාඩි වෙනවා',
  };

  static String _englishMonthName(String month) =>
      _monthEnglishNames[month] ?? month;

  String? _letterReferenceAssetPath(String letter) {
    return GestureAssetPaths.forLetter(letter);
  }

  String _monthReferenceAssetPath(String month) {
    final englishMonth = _englishMonthName(month);
    return GestureAssetPaths.forMonth(englishMonth);
  }

  String _verbReferenceAssetPath(String verb) =>
      GestureAssetPaths.forVerb(verb);

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final items = switch (_selectedCategory) {
      _LibraryCategory.months => _months.where((month) {
        final englishMonth = _englishMonthName(month);
        return month.toLowerCase().contains(query) ||
            englishMonth.toLowerCase().contains(query);
      }).toList(),
      _LibraryCategory.verbs =>
        _verbs.entries
            .where(
              (verb) =>
                  verb.value.toLowerCase().contains(query) ||
                  verb.key.replaceAll('_', ' ').contains(query),
            )
            .toList(),
      _LibraryCategory.alphabet =>
        _letters
            .split('')
            .where((letter) => 'letter $letter'.contains(query))
            .toList(),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0D1320),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SSL Sign Library',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (_selectedCategory) {
                    _LibraryCategory.months =>
                      'Choose a month sign to practice with the camera.',
                    _LibraryCategory.verbs =>
                      'Choose an action sign to practice with the camera.',
                    _LibraryCategory.alphabet =>
                      'Choose a letter to practice with the camera.',
                  },
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<_LibraryCategory>(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF4A6CF7);
                      }
                      return const Color(0xFF171F2D);
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.white70;
                    }),
                    side: WidgetStateProperty.all(
                      const BorderSide(color: Colors.white12),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: _LibraryCategory.alphabet,
                      label: Text('Alphabet'),
                      icon: Icon(Icons.abc),
                    ),
                    ButtonSegment(
                      value: _LibraryCategory.months,
                      label: Text('Months'),
                      icon: Icon(Icons.calendar_month),
                    ),
                    ButtonSegment(
                      value: _LibraryCategory.verbs,
                      label: Text('Verbs'),
                      icon: Icon(Icons.directions_run_rounded),
                    ),
                  ],
                  selected: {_selectedCategory},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedCategory = selection.first;
                      _searchQuery = '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: switch (_selectedCategory) {
                      _LibraryCategory.months => 'Search months...',
                      _LibraryCategory.verbs => 'Search verbs...',
                      _LibraryCategory.alphabet => 'Search letters...',
                    },
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF171F2D),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'No ${switch (_selectedCategory) {
                        _LibraryCategory.months => 'months',
                        _LibraryCategory.verbs => 'verbs',
                        _LibraryCategory.alphabet => 'letters',
                      }} found.',
                      style: GoogleFonts.poppins(color: Colors.white60),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.05,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final title = switch (_selectedCategory) {
                        _LibraryCategory.months => item as String,
                        _LibraryCategory.verbs =>
                          (item as MapEntry<String, String>).value,
                        _LibraryCategory.alphabet => 'Letter $item',
                      };
                      final referenceAssetPath = switch (_selectedCategory) {
                        _LibraryCategory.months => _monthReferenceAssetPath(
                          item as String,
                        ),
                        _LibraryCategory.verbs => _verbReferenceAssetPath(
                          (item as MapEntry<String, String>).key,
                        ),
                        _LibraryCategory.alphabet => _letterReferenceAssetPath(
                          item as String,
                        ),
                      };
                      return _buildSignCard(
                        title: title,
                        badge: switch (_selectedCategory) {
                          _LibraryCategory.months => (item as String).substring(
                            0,
                            3,
                          ),
                          _LibraryCategory.verbs => 'ක්‍රියා',
                          _LibraryCategory.alphabet => item as String,
                        },
                        referenceAssetPath: referenceAssetPath,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignCard({
    required String title,
    required String badge,
    required String? referenceAssetPath,
  }) {
    final hasReference = referenceAssetPath != null;
    return Card(
      color: const Color(0xFF171F2D),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PracticeWorkspaceScreen(
                lessonId: null,
                lessonTitle: title,
                referenceAssetPath: referenceAssetPath,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: hasReference
                    ? const Color(0xFF4A6CF7).withOpacity(0.18)
                    : Colors.amber.withOpacity(0.18),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(
                    color: hasReference ? Colors.white : Colors.amberAccent,
                    fontSize: badge.length > 1 ? 20 : 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasReference
                    ? 'Tap to practice'
                    : 'Tracking only • reference missing',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: hasReference ? Colors.white60 : Colors.amberAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
