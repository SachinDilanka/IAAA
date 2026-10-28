import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/communication_models.dart';
import '../data/communication_data.dart';
import '../data/venue_data.dart';
import '../services/suggest_api.dart';
import '../controllers/venue_controller.dart';
import '../providers/venue_provider.dart';
import '../widgets/suggestion_panel.dart';
import '../widgets/interactive_venue_map.dart';
import '../widgets/sinhala_speech_box.dart';
import '../widgets/message_card_overlay.dart';
import '../config/app_config.dart';
import 'category_detail_screen.dart';
import '../theme/app_theme.dart';

class QuickMessageItem {
  final String english;
  final String sinhala;
  final String category;

  const QuickMessageItem({
    required this.english,
    required this.sinhala,
    required this.category,
  });
}

class HomeScreen extends StatefulWidget {
  final VenueController? controller;

  const HomeScreen({super.key, this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SuggestApi _suggestApi;
  VenueController? _localController;

  VenueController get _venueController {
    if (widget.controller != null) return widget.controller!;
    final provider = VenueProvider.maybeOf(context);
    if (provider != null) return provider;
    _localController ??= VenueController();
    return _localController!;
  }

  VenueType get _selectedVenueType => _venueController.currentVenueType;
  VenueItem? get _activeVenue => _venueController.currentVenue;
  List<CommunicationCategory> get _categories => _venueController.currentCategories;
  bool get _isGpsDetected => _venueController.isGpsDetected;
  double get _currentLat => _venueController.lastPosition?.latitude ?? _venueController.currentVenue?.lat ?? 6.9192;
  double get _currentLon => _venueController.lastPosition?.longitude ?? _venueController.currentVenue?.lon ?? 79.8681;

  bool _isLoading = false;
  int _currentBottomNavIndex = 0;

  // Recent & favorites tracking
  final List<QuickMessageItem> _history = [];
  final Set<String> _favorites = {};


  @override
  void initState() {
    super.initState();
    _suggestApi = SuggestApi(baseUrl: AppConfig.suggestApiBaseUrl);
  }

  @override
  void dispose() {
    _suggestApi.dispose();
    _localController?.dispose();
    super.dispose();
  }

  VenueCategory _mapVenueTypeToCategory(VenueType type) {
    switch (type) {
      case VenueType.supermarket:
        return VenueCategory.supermarket;
      case VenueType.hospital:
        return VenueCategory.hospital;
      case VenueType.bank:
        return VenueCategory.bank;
      case VenueType.restaurant:
        return VenueCategory.restaurant;
      case VenueType.other:
        return VenueCategory.supermarket;
    }
  }

  void _switchVenueType(VenueType type) {
    _venueController.selectManualCategory(type);
  }

  void _selectVenueItem(VenueItem item, {bool fromGps = false}) {
    if (fromGps) {
      _venueController.useGpsAgain();
    } else {
      _venueController.selectManualVenue(item);
    }
  }

  Future<void> _simulateGpsDetection(double lat, double lon) async {
    setState(() => _isLoading = true);
    try {
      _venueController.onPositionUpdate(Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 15.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  QuickMessageItem _resolveBilingualPair({
    required String sinhala,
    required String english,
    String categoryName = '',
  }) {
    String rawSi = sinhala.trim();
    String rawEn = english.trim();

    final bool hasSi = RegExp(r'[\u0D80-\u0DFF]').hasMatch(rawSi);
    final bool hasEnSi = RegExp(r'[\u0D80-\u0DFF]').hasMatch(rawEn);

    // 1. If rawSi or rawEn has "Sinhala (English)"
    final match = RegExp(r'^([\u0D80-\u0DFF\s.,!?\u200c\u200d]+)\s*\(([^)]+)\)$').firstMatch(rawSi.isNotEmpty ? rawSi : rawEn);
    if (match != null) {
      return QuickMessageItem(
        sinhala: match.group(1)!.trim(),
        english: match.group(2)!.trim(),
        category: categoryName.isNotEmpty ? categoryName : 'Communication',
      );
    }

    // 2. If rawSi or rawEn has " / "
    final combined = rawSi.isNotEmpty ? rawSi : rawEn;
    if (combined.contains(' / ')) {
      final parts = combined.split(' / ');
      if (parts.length == 2) {
        final p0Has = RegExp(r'[\u0D80-\u0DFF]').hasMatch(parts[0]);
        final p1Has = RegExp(r'[\u0D80-\u0DFF]').hasMatch(parts[1]);
        if (p0Has && !p1Has) {
          return QuickMessageItem(sinhala: parts[0].trim(), english: parts[1].trim(), category: categoryName);
        } else if (!p0Has && p1Has) {
          return QuickMessageItem(sinhala: parts[1].trim(), english: parts[0].trim(), category: categoryName);
        }
      }
    }

    String effSi = '';
    String effEn = '';

    if (hasSi && !hasEnSi) {
      effSi = rawSi;
      effEn = rawEn;
    } else if (!hasSi && hasEnSi) {
      effSi = rawEn;
      effEn = rawSi;
    } else if (hasSi && hasEnSi) {
      effSi = rawSi.isNotEmpty ? rawSi : rawEn;
      effEn = '';
    } else {
      effEn = rawEn.isNotEmpty ? rawEn : rawSi;
      effSi = '';
    }

    // 3. Search in CommunicationData across all venues
    final allCategories = [
      ...CommunicationData.hospitalCategories,
      ...CommunicationData.bankCategories,
      ...CommunicationData.supermarketCategories,
      ...CommunicationData.restaurantCategories,
    ];

    if (effSi.isEmpty || effEn.isEmpty) {
      for (final cat in allCategories) {
        for (final msg in cat.messages) {
          if (effSi.isEmpty && effEn.isNotEmpty) {
            if (msg.templateEn.trim().toLowerCase() == effEn.toLowerCase()) {
              effSi = msg.templateSi;
              break;
            }
          }
          if (effEn.isEmpty && effSi.isNotEmpty) {
            if (msg.templateSi.trim() == effSi || effSi.contains(msg.templateSi.trim()) || msg.templateSi.trim().contains(effSi)) {
              effEn = msg.templateEn;
              break;
            }
          }
        }
        if (effSi.isNotEmpty && effEn.isNotEmpty) break;
      }
    }


    // 5. Common phrase fallback dictionary
    const commonPhrases = {
      'i am deaf': 'මම බිහිරි කෙනෙක්.',
      'i am deaf.': 'මම බිහිරි කෙනෙක්.',
      'i am deaf / hard of hearing': 'මම බිහිරි කෙනෙක්.',
      'i cannot speak': 'මට කතා කරන්න බැහැ.',
      'i cannot speak.': 'මට කතා කරන්න බැහැ.',
      'please write down your message': 'කරුණාකර ඔබේ පණිවිඩය ලියන්න.',
      'please write down your message.': 'කරුණාකර ඔබේ පණිවිඩය ලියන්න.',
      'please write it down': 'කරුණාකර ඔබේ පණිවිඩය ලියන්න.',
      'please speak slowly and face me': 'කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.',
      'please speak slowly and face me.': 'කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.',
      'please wait a moment': 'කරුණාකර මොහොතක් රැඳී සිටින්න.',
      'please wait a moment.': 'කරුණාකර මොහොතක් රැඳී සිටින්න.',
      'please repeat that': 'කරුණාකර නැවත කියන්න.',
      'please repeat that.': 'කරුණාකර නැවත කියන්න.',
      'i do not understand': 'මට තේරෙන්නේ නැහැ.',
      'i do not understand.': 'මට තේරෙන්නේ නැහැ.',
      'yes': 'ඔව්.',
      'yes.': 'ඔව්.',
      'no': 'නැහැ.',
      'no.': 'නැහැ.',
      'thank you': 'ස්තූතියි.',
      'thank you.': 'ස්තූතියි.',
      'i need help': 'මට උදව්වක් අවශ්‍යයි.',
      'i need help.': 'මට උදව්වක් අවශ්‍යයි.',
      'where is the restroom?': 'වැසිකිළිය කොහෙද?',
      'where is the toilet?': 'වැසිකිළිය කොහෙද?',
      'where is the entrance?': 'ඇතුල්වීමේ දොර කොහෙද?',
      'where is the exit?': 'පිටවීමේ දොර කොහෙද?',
      'where is the pharmacy?': 'ඖෂධ ශාලාව කොහෙද?',
      'where is the opd?': 'බාහිර රෝගී අංශය (OPD) කොහෙද?',
      'i need to see a doctor': 'මට වෛද්‍යවරයකු හමුවීමට අවශ්‍යයි.',
      'i need to see a doctor.': 'මට වෛද්‍යවරයකු හමුවීමට අවශ්‍යයි.',
      'i have an appointment': 'මට වේලාවක් වෙන්කරගෙන ඇත.',
      'i have an appointment.': 'මට වේලාවක් වෙන්කරගෙන ඇත.',
      'i need emergency assistance': 'මට හදිසි වෛද්‍ය ප්‍රතිකාර අවශ්‍යයි.',
      'i need emergency assistance.': 'මට හදිසි වෛද්‍ය ප්‍රතිකාර අවශ්‍යයි.',
      'i need a wheelchair': 'මට රෝද පුටුවක් අවශ්‍යයි.',
      'i need a wheelchair.': 'මට රෝද පුටුවක් අවශ්‍යයි.',
      'where is the billing counter?': 'මුදල් ගෙවන කවුන්ටරය කොහෙද?',
      'how much is this?': 'මෙය කීයද?',
      'how much is this': 'මෙය කීයද?',
      'do you accept card payment?': 'කාඩ්පත් මඟින් ගෙවීම් භාරගන්නවාද?',
      'where is the dairy section?': 'කිරි නිෂ්පාදන අංශය කොහෙද?',
      'do you have fresh bread?': 'නැවුම් පාන් තියෙනවාද?',
      'i want to deposit money': 'මට මුදල් තැන්පත් කිරීමට අවශ්‍යයි.',
      'i want to deposit money.': 'මට මුදල් තැන්පත් කිරීමට අවශ්‍යයි.',
      'i want to withdraw money': 'මට මුදල් ලබා ගැනීමට අවශ්‍යයි.',
      'i want to withdraw money.': 'මට මුදල් ලබා ගැනීමට අවශ්‍යයි.',
      'where is the atm?': 'ස්වයංක්‍රීය ටෙලර් යන්ත්‍රය (ATM) කොහෙද?',
      'where do i get a queue token?': 'පෝලිම් ටෝකන් අංකය ලබාගන්නේ කොහෙන්ද?',
      'which counter should i go to?': 'මම යා යුත්තේ කුමන කවුන්ටරයට ද?',
    };

    if (effSi.isEmpty && effEn.isNotEmpty) {
      final cleanKey = effEn.toLowerCase().replaceAll(RegExp(r'[.,!?]+$'), '').trim();
      commonPhrases.forEach((k, v) {
        if (k.replaceAll(RegExp(r'[.,!?]+$'), '').trim() == cleanKey) {
          effSi = v;
        }
      });
    }

    if (effEn.isEmpty && effSi.isNotEmpty) {
      commonPhrases.forEach((k, v) {
        if (v.trim() == effSi.trim() || effSi.contains(v) || v.contains(effSi)) {
          effEn = k[0].toUpperCase() + k.substring(1);
        }
      });
    }

    if (effSi.isEmpty) {
      effSi = effEn.isNotEmpty ? 'පණිවිඩය: $effEn' : 'මම බිහිරි කෙනෙක්.';
    }
    if (effEn.isEmpty) {
      effEn = hasSi ? 'Live Sinhala Speech Detection' : (effSi.isNotEmpty ? effSi : 'I am deaf.');
    }

    return QuickMessageItem(
      sinhala: effSi,
      english: effEn,
      category: categoryName.isNotEmpty ? categoryName : 'Communication',
    );
  }

  void _showFullscreenCardDisplay({
    required String sinhala,
    required String english,
    required String categoryName,
    int? id,
  }) {
    final resolved = _resolveBilingualPair(
      sinhala: sinhala,
      english: english,
      categoryName: categoryName,
    );
    final effectiveSinhala = resolved.sinhala;
    final effectiveEnglish = resolved.english;

    // Record to history with both resolved Sinhala and English
    _history.insert(
      0,
      QuickMessageItem(
        english: effectiveEnglish,
        sinhala: effectiveSinhala,
        category: categoryName,
      ),
    );
    if (_history.length > 30) _history.removeLast();

    showMessageCard(
      context,
      sinhala: effectiveSinhala,
      english: effectiveEnglish,
      categoryName: categoryName,
      id: id,
    );
  }

  void _showCustomMessageDialog() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note, color: Color(0xFF2563EB), size: 26),
                    SizedBox(width: 8),
                    Text(
                      'Custom Typing',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                )
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Type your own message in Sinhala or English',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. මට වතුර ටිකක් අවශ්‍යයි / I need help...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isEmpty) return;
                Navigator.of(ctx).pop();
                _showFullscreenCardDisplay(
                  sinhala: txt,
                  english: '',
                  categoryName: 'Custom Typing / පණිවිඩය',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedVenueType.themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Display Fullscreen Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualVenueSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        VenueType? filter;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allVenues = [
              ...VenueData.hospitals,
              ...VenueData.banks,
              ...VenueData.restaurants,
              ...VenueData.supermarkets,
            ];
            final list = filter == null ? allVenues : allVenues.where((v) => v.type == filter).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Location Manually',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Text(
                    'Choose a predefined hospital, bank, restaurant, or supermarket in Sri Lanka',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All (15)'),
                          selected: filter == null,
                          onSelected: (_) => setSheetState(() => filter = null),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Hospitals (4)'),
                          selected: filter == VenueType.hospital,
                          selectedColor: const Color(0xFFFEE2E2),
                          onSelected: (_) => setSheetState(() => filter = VenueType.hospital),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Banks (3)'),
                          selected: filter == VenueType.bank,
                          selectedColor: const Color(0xFFDBEAFE),
                          onSelected: (_) => setSheetState(() => filter = VenueType.bank),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Restaurants (3)'),
                          selected: filter == VenueType.restaurant,
                          selectedColor: const Color(0xFFFEF3C7),
                          onSelected: (_) => setSheetState(() => filter = VenueType.restaurant),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Supermarkets (5)'),
                          selected: filter == VenueType.supermarket,
                          selectedColor: const Color(0xFFD1FAE5),
                          onSelected: (_) => setSheetState(() => filter = VenueType.supermarket),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final v = list[idx];
                        final isSelected = _activeVenue?.id == v.id;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: v.type.backgroundColor,
                            child: Icon(v.type.icon, color: v.type.themeColor, size: 20),
                          ),
                          title: Text(
                            v.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? v.type.themeColor : const Color(0xFF1E293B),
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${v.city} • ${v.address}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: v.type.themeColor)
                              : const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _selectVenueItem(v, fromGps: false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Selected: ${v.name}'),
                                backgroundColor: v.type.themeColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceLight,
        foregroundColor: AppTheme.textMain,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 24, color: AppTheme.textMain),
          tooltip: 'Menu / Categories',
          onPressed: () {
            setState(() => _currentBottomNavIndex = 1);
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI Communication Assistant',
              style: TextStyle(
                fontFamily: AppTheme.fontHeading,
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                color: AppTheme.textMain,
                letterSpacing: -0.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hearing, size: 9, color: AppTheme.textMuted),
                SizedBox(width: 3),
                Text(
                  'CommAssist Sri Lanka',
                  style: TextStyle(
                    fontFamily: AppTheme.fontMain,
                    fontSize: 9.5,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('appbar_location_debug_button'),
            icon: const Icon(Icons.track_changes, size: 22, color: AppTheme.textMain),
            tooltip: 'Location Debug Info',
            onPressed: () => _showLocationDebugDialog(context, _venueController),
            onLongPress: () => _simulateGpsDetection(6.9192, 79.8681),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: _venueController,
        builder: (context, _) => _buildCurrentBody(),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceLight,
          border: Border(top: BorderSide(color: AppTheme.borderLight, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomNavigationBar(
                currentIndex: _currentBottomNavIndex,
                onTap: (index) => setState(() => _currentBottomNavIndex = index),
                backgroundColor: AppTheme.surfaceLight,
                selectedItemColor: AppTheme.textMain,
                unselectedItemColor: AppTheme.textDisabled,
                selectedLabelStyle: const TextStyle(
                  fontFamily: AppTheme.fontMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: AppTheme.fontMain,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view),
                    label: 'Categories',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    label: 'History',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.star),
                    label: 'Favorites',
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 2, bottom: 8),
                width: 134,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.textMain,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentBody() {
    switch (_currentBottomNavIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildCategoriesTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildFavoritesTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 0. Auto-switch notification banner with Undo button
                if (_venueController.autoSwitchNotification != null)
                  _buildAutoSwitchNotificationBanner(_venueController),

                // Top Floating Dark GPS Scan Toast (Matching original screenshot)
                _buildGpsScanToast(_venueController),

                // GPS Status Line with settings/permission buttons & debug shortcut
                _buildGpsStatusBar(_venueController),

                const SizedBox(height: 2),

                // 1. CURRENT LOCATION CARD (Matching original screenshot)
                _buildCurrentLocationCard(),

                // 2. INTERACTIVE AREA MAP (Detecting Predefined Locations)
                InteractiveVenueMap(
                  activeVenue: _activeVenue,
                  selectedVenueType: _selectedVenueType,
                  currentLat: _currentLat,
                  currentLon: _currentLon,
                  accuracy: _venueController.lastPosition?.accuracy,
                  isGpsLive: _isGpsDetected,
                  isFollowMode: _venueController.isFollowMode,
                  onUserPan: () => _venueController.setFollowMode(false),
                  onVenueSelected: (venue) {
                    _venueController.selectManualVenue(venue);
                  },
                  onRecenterGps: () {
                    _venueController.setFollowMode(true);
                    _venueController.useGpsAgain();
                  },
                  onOpenDebug: () => _showLocationDebugDialog(context, _venueController),
                  onUseGpsAgain: () {
                    _venueController.setFollowMode(true);
                    _venueController.useGpsAgain();
                  },
                  onOpenManualSelector: _showManualVenueSelector,
                ),

                // 3. GPS DETECTION ACTIVE PANEL (Directly below map in original screenshot)
                _buildGpsDetectionPanel(),

                // 4. PREDEFINED LOCATION MANUAL SELECTOR CHIPS
                _buildVenueTypeSelectorRow(),

                // Showing Messages For Banner (Step 3)
                _buildShowingMessagesBanner(_venueController),

                // Sinhala Live Speech Box (Screen 1: Home)
                SinhalaSpeechBox(
                  themeColor: _selectedVenueType.themeColor,
                  onShowFullscreen: (txt) {
                    _showFullscreenCardDisplay(
                      sinhala: txt,
                      english: '',
                      categoryName: 'Sinhala Live Speech',
                    );
                  },
                ),

                const SizedBox(height: 14),

                // 5. CUSTOM TYPING CARD (Faithful to Mockup)
                _buildCustomTypingCard(),

                const SizedBox(height: 18),

                // 6. AI SUGGESTION & QUICK SEARCH PANEL
                _buildAiSuggestionSection(),
              ],
            ),
          );
  }

  // Auto-switch notification banner with Undo button
  Widget _buildAutoSwitchNotificationBanner(VenueController controller) {
    return Container(
      key: const Key('auto_switch_notification_banner'),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.headerDark,
        borderRadius: AppTheme.borderRadiusBtn,
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.liveGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              controller.autoSwitchNotification ?? '',
              style: const TextStyle(
                fontFamily: AppTheme.fontMain,
                color: AppTheme.textWhite,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            key: const Key('undo_auto_switch_button'),
            onPressed: () => controller.undoAutoSwitch(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.warningAmber,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Undo', style: TextStyle(fontFamily: AppTheme.fontMain, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => controller.dismissNotification(),
          ),
        ],
      ),
    );
  }

  // GPS Status Bar
  Widget _buildGpsStatusBar(VenueController controller) {
    final statusText = controller.gpsStatusText;
    final isError = statusText.toLowerCase().contains('denied') || statusText.toLowerCase().contains('error');
    final isLowAccuracy = statusText.toLowerCase().contains('low');
    final isServiceDisabled = statusText.toLowerCase().contains('turned off') || statusText.toLowerCase().contains('disabled');

    Color indicatorColor = AppTheme.liveGreen;
    if (isError) {
      indicatorColor = AppTheme.dangerRed;
    } else if (isLowAccuracy || statusText.contains('searching')) {
      indicatorColor = AppTheme.warningAmber;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFEF2F2)
            : (isLowAccuracy ? const Color(0xFFFFFBEB) : AppTheme.surfaceLight),
        borderRadius: AppTheme.borderRadiusSm,
        border: Border.all(
          color: isError
              ? AppTheme.hospitalBorder
              : (isLowAccuracy ? AppTheme.restaurantBorder : AppTheme.borderLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: indicatorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontFamily: AppTheme.fontMain,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isError
                    ? const Color(0xFF991B1B)
                    : (isLowAccuracy ? const Color(0xFF92400E) : AppTheme.textSub),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isError) ...[
            TextButton(
              key: const Key('open_app_settings_button'),
              onPressed: () => controller.openAppSettings(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Settings', style: TextStyle(fontFamily: AppTheme.fontMain, fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.dangerRed)),
            ),
          ] else if (isServiceDisabled) ...[
            TextButton(
              key: const Key('open_location_settings_button'),
              onPressed: () => controller.openLocationSettings(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Enable GPS', style: TextStyle(fontFamily: AppTheme.fontMain, fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ),
          ],
          IconButton(
            key: const Key('status_debug_info_button'),
            icon: const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Location Debug Info',
            onPressed: () => _showLocationDebugDialog(context, controller),
          ),
        ],
      ),
    );
  }

  // Showing Messages For Banner (Step 3)
  Widget _buildShowingMessagesBanner(VenueController controller) {
    final venueName = controller.isOutsidePredefined
        ? 'Outside Predefined Venues'
        : (controller.currentVenue?.shortName ?? controller.currentVenue?.name ?? controller.currentVenueType.displayNameEn);
    final sourceText = controller.isGpsDetected ? 'GPS' : 'chosen by you';

    return Container(
      key: const Key('showing_messages_banner'),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: controller.currentVenueType.backgroundColor,
        borderRadius: AppTheme.borderRadiusBtn,
        border: Border.all(
          color: controller.currentVenueType.themeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(controller.currentVenueType.icon, size: 18, color: controller.currentVenueType.themeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing messages for: $venueName ($sourceText)',
              style: const TextStyle(
                fontFamily: AppTheme.fontMain,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            key: const Key('banner_change_category_button'),
            onPressed: () => _showCategoryPicker(context, controller),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: TextStyle(
                fontFamily: AppTheme.fontMain,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: controller.currentVenueType.themeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Floating Dark GPS Scan Toast (Matches original screenshot)
  Widget _buildGpsScanToast(VenueController controller) {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.headerDark,
        borderRadius: AppTheme.borderRadiusBtn,
        boxShadow: AppTheme.toastShadow,
      ),
      child: Row(
        children: [
          // GPS Cyan Radar Spinner matching .gps-radar-spinner in mobile.css
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.cyanRadarTrack,
                width: 2.5,
              ),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: isTest
                    ? Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border(top: BorderSide(color: AppTheme.accentCyan, width: 2.5)),
                        ),
                      )
                    : const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Acquiring GPS satellite coordinates...',
              style: TextStyle(
                fontFamily: AppTheme.fontMain,
                color: AppTheme.textWhite,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. CURRENT LOCATION HERO CARD (Matches original screenshot)
  Widget _buildCurrentLocationCard() {
    final isOutside = _venueController.isOutsidePredefined;

    // Category count string and badge color
    String countBadgeText;
    Color badgeBgColor;
    Color badgeTextColor;
    IconData badgeIcon;

    switch (_selectedVenueType) {
      case VenueType.hospital:
        countBadgeText = '20 SL Hospitals';
        badgeBgColor = AppTheme.hospitalBackground;
        badgeTextColor = AppTheme.hospitalColor;
        badgeIcon = Icons.local_hospital;
        break;
      case VenueType.bank:
        countBadgeText = '12 SL Banks';
        badgeBgColor = AppTheme.bankBackground;
        badgeTextColor = AppTheme.bankColor;
        badgeIcon = Icons.account_balance;
        break;
      case VenueType.restaurant:
        countBadgeText = '10 SL Restaurants';
        badgeBgColor = AppTheme.restaurantBackground;
        badgeTextColor = AppTheme.restaurantColor;
        badgeIcon = Icons.restaurant;
        break;
      case VenueType.supermarket:
        countBadgeText = '10 SL Supermarkets';
        badgeBgColor = AppTheme.supermarketBackground;
        badgeTextColor = AppTheme.supermarketColor;
        badgeIcon = Icons.shopping_cart;
        break;
      case VenueType.other:
        countBadgeText = 'SL Venues';
        badgeBgColor = const Color(0xFFF1F5F9);
        badgeTextColor = AppTheme.textMuted;
        badgeIcon = Icons.place;
        break;
    }

    final venueTitle = isOutside
        ? 'Outside Predefined Venues'
        : (_activeVenue?.name ?? _activeVenue?.shortName ?? 'Detecting Location...');

    final gpsSubText = isOutside
        ? 'Not inside any predefined venue'
        : (_isGpsDetected ? 'Detected via GPS' : 'Selected Manually');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: AppTheme.borderRadiusCard,
        border: Border.all(color: AppTheme.borderLight, width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar: soft category-color rounded square matching original screenshot
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: badgeTextColor.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isOutside ? Icons.explore_off_outlined : Icons.location_on,
                  color: badgeTextColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Location details column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Eyebrow row: CURRENT LOCATION + Category count badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'CURRENT LOCATION',
                            style: AppTheme.textEyebrow,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 10, color: badgeTextColor),
                              const SizedBox(width: 3),
                              Text(
                                countBadgeText,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontMain,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: badgeTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Main Title: Detecting Location... or Venue Name
                    Text(
                      venueTitle,
                      style: AppTheme.textTitleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Bottom row: Detected via GPS + LIVE Badge Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          gpsSubText,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontMain,
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        InkWell(
                          key: const Key('location_card_change_button'),
                          onTap: _showManualVenueSelector,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: AppTheme.liveBadgeDecoration,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isOutside ? AppTheme.warningAmber : AppTheme.liveDot,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontMain,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textMain,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // If outside predefined venues: show category picker
          if (isOutside) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const Text(
              'Outside predefined venues. Choose a category:',
              style: TextStyle(fontFamily: AppTheme.fontMain, fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSub),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOutsideCategoryButton(
                    type: VenueType.hospital,
                    label: 'Hospital',
                    icon: Icons.local_hospital,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildOutsideCategoryButton(
                    type: VenueType.bank,
                    label: 'Bank',
                    icon: Icons.account_balance,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildOutsideCategoryButton(
                    type: VenueType.restaurant,
                    label: 'Restaurant',
                    icon: Icons.restaurant,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildOutsideCategoryButton(
                    type: VenueType.supermarket,
                    label: 'Supermarket',
                    icon: Icons.shopping_cart,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // GPS Detection Active Panel (Directly below map in original screenshot)
  Widget _buildGpsDetectionPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: AppTheme.borderRadiusCard,
        border: Border.all(color: AppTheme.borderLight, width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppTheme.hospitalBackground,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.track_changes,
                color: AppTheme.hospitalColor,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'GPS Detection Active',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontHeading,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a hospital (🔴), bank (🔵), restaurant (🟠), or supermarket (🟢) on the map, or wait for GPS to detect your location to view message categories.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontMain,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutsideCategoryButton({
    required VenueType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedVenueType == type;
    return OutlinedButton.icon(
      key: Key('outside_category_${type.name}'),
      onPressed: () => _venueController.selectManualCategory(type),
      icon: Icon(icon, size: 16, color: isSelected ? AppTheme.textWhite : type.themeColor),
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontMain,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected ? AppTheme.textWhite : AppTheme.textMain,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? type.themeColor : AppTheme.surfaceLight,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        side: BorderSide(color: isSelected ? type.themeColor : AppTheme.borderHover),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // 4. PREDEFINED LOCATION MANUAL SELECTOR CHIPS
  Widget _buildVenueTypeSelectorRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildVenueChip(VenueType.hospital, 'Hospital (4 Cat.)'),
            const SizedBox(width: 8),
            _buildVenueChip(VenueType.supermarket, 'Supermarket (9 Cat.)'),
            const SizedBox(width: 8),
            _buildVenueChip(VenueType.bank, 'Bank (3 Cat.)'),
            const SizedBox(width: 8),
            _buildVenueChip(VenueType.restaurant, 'Restaurant (3 Cat.)'),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueChip(VenueType type, String label) {
    final isSelected = _selectedVenueType == type;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(
        type.icon,
        size: 15,
        color: isSelected ? AppTheme.textWhite : type.themeColor,
      ),
      selectedColor: type.themeColor,
      backgroundColor: AppTheme.surfaceLight,
      labelStyle: TextStyle(
        fontFamily: AppTheme.fontMain,
        color: isSelected ? AppTheme.textWhite : AppTheme.textSub,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? type.themeColor : AppTheme.borderLight,
          width: 1.5,
        ),
      ),
      onSelected: (_) => _switchVenueType(type),
    );
  }

  // 5. CUSTOM TYPING CARD (Faithful to Mockup)
  Widget _buildCustomTypingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderHover, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showCustomMessageDialog,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: AppTheme.textMain,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Typing',
                        style: TextStyle(
                          fontFamily: AppTheme.fontHeading,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.textMain,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Type your own message',
                        style: TextStyle(
                          fontFamily: AppTheme.fontMain,
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 7. AI SUGGESTION & QUICK SEARCH PANEL
  Widget _buildAiSuggestionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: _selectedVenueType.themeColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Phrase Suggestions / යෝජනා',
                  style: TextStyle(
                    fontFamily: AppTheme.fontHeading,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 340,
            child: SuggestionPanel(
              api: _suggestApi,
              category: _mapVenueTypeToCategory(_selectedVenueType),
              onPhraseSelected: (phrase) {
                _showFullscreenCardDisplay(
                  sinhala: phrase.sinhala,
                  english: phrase.english,
                  categoryName: _selectedVenueType.displayNameEn,
                );
              },
              onTypedTextSelected: (typedText) {
                _showFullscreenCardDisplay(
                  sinhala: typedText,
                  english: '',
                  categoryName: 'Custom Words / මගේ වචන',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: CATEGORIES FULL VIEW
  // -------------------------------------------------------------
  Widget _buildCategoriesTab() {
    final themeColor = _selectedVenueType.themeColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sinhala Live Speech Box (Screen 2 / Tab 1: Categories)
          SinhalaSpeechBox(
            themeColor: themeColor,
            onShowFullscreen: (txt) {
              _showFullscreenCardDisplay(
                sinhala: txt,
                english: '',
                categoryName: 'Sinhala Live Speech',
              );
            },
          ),
          const SizedBox(height: 10),

          // Selector chips at top of categories
          _buildVenueTypeSelectorRow(),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(_selectedVenueType.icon, size: 18, color: themeColor),
              const SizedBox(width: 8),
              Text(
                '${_selectedVenueType.displayNameEn} Categories (${_categories.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final cat = _categories[idx];
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategoryDetailScreen(
                        category: cat,
                        venueType: _selectedVenueType,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _selectedVenueType.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(cat.icon, color: themeColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.nameSi,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cat.nameEn,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selectedVenueType.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${cat.count}',
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: HISTORY VIEW
  // -------------------------------------------------------------
  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sinhala Live Speech Box (Screen 3 / Tab 2: History)
        SinhalaSpeechBox(
          themeColor: _selectedVenueType.themeColor,
          onShowFullscreen: (txt) {
            _showFullscreenCardDisplay(
              sinhala: txt,
              english: '',
              categoryName: 'Sinhala Live Speech',
            );
          },
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text(
                    'No message history yet',
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Phrases you tap will appear here for quick access',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          )
        else
          ..._history.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    title: Text(item.sinhala, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(item.english, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                    onTap: () {
                      _showFullscreenCardDisplay(
                        sinhala: item.sinhala,
                        english: item.english,
                        categoryName: item.category,
                      );
                    },
                  ),
                ),
              )),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: FAVORITES VIEW
  // -------------------------------------------------------------
  Widget _buildFavoritesTab() {
    final favList = _favorites.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sinhala Live Speech Box (Screen 4 / Tab 3: Favorites)
        SinhalaSpeechBox(
          themeColor: _selectedVenueType.themeColor,
          onShowFullscreen: (txt) {
            _showFullscreenCardDisplay(
              sinhala: txt,
              english: '',
              categoryName: 'Sinhala Live Speech',
            );
          },
        ),
        const SizedBox(height: 12),
        if (_favorites.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 48, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text(
                    'No favorites saved yet',
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap the star icon on any fullscreen phrase to save it here',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          )
        else
          ...favList.map((phrase) {
            final pair = _resolveBilingualPair(sinhala: phrase, english: '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Color(0xFFF59E0B)),
                  title: Text(pair.sinhala, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text(pair.english, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      setState(() {
                        _favorites.remove(phrase);
                        _favorites.remove(pair.english);
                        _favorites.remove(pair.sinhala);
                      });
                    },
                  ),
                  onTap: () {
                    _showFullscreenCardDisplay(
                      sinhala: pair.sinhala,
                      english: pair.english,
                      categoryName: 'Favorite / ප්‍රියතම',
                    );
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showCategoryPicker(BuildContext context, VenueController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Choose Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select which type of communication messages to display:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryPickerItem(
                    ctx,
                    controller,
                    type: VenueType.hospital,
                    labelSi: 'රෝහල',
                    labelEn: 'Hospital',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCategoryPickerItem(
                    ctx,
                    controller,
                    type: VenueType.bank,
                    labelSi: 'බැංකුව',
                    labelEn: 'Bank',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryPickerItem(
                    ctx,
                    controller,
                    type: VenueType.restaurant,
                    labelSi: 'ආපනශාලාව',
                    labelEn: 'Restaurant',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCategoryPickerItem(
                    ctx,
                    controller,
                    type: VenueType.supermarket,
                    labelSi: 'සුපිරි වෙළඳසැල',
                    labelEn: 'Supermarket',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPickerItem(
    BuildContext ctx,
    VenueController controller, {
    required VenueType type,
    required String labelSi,
    required String labelEn,
  }) {
    final isSelected = controller.currentVenueType == type;
    return InkWell(
      key: Key('category_picker_${type.name}'),
      onTap: () {
        Navigator.of(ctx).pop();
        controller.selectManualCategory(type);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? type.themeColor : type.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? type.themeColor : type.themeColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(type.icon, color: isSelected ? Colors.white : type.themeColor, size: 24),
            const SizedBox(height: 6),
            Text(
              labelSi,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            Text(
              labelEn,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDebugDialog(BuildContext context, VenueController controller) {
    final pos = controller.lastPosition;
    final timeStr = pos?.timestamp != null
        ? '${pos!.timestamp.hour.toString().padLeft(2, '0')}:${pos.timestamp.minute.toString().padLeft(2, '0')}:${pos.timestamp.second.toString().padLeft(2, '0')}'
        : 'No fix yet';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Location Debug Info', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDebugRow('Latitude', pos?.latitude.toStringAsFixed(6) ?? 'N/A'),
              _buildDebugRow('Longitude', pos?.longitude.toStringAsFixed(6) ?? 'N/A'),
              _buildDebugRow('Accuracy', pos != null ? '${pos.accuracy.toStringAsFixed(1)} m' : 'N/A'),
              _buildDebugRow('Speed', pos != null ? '${pos.speed.toStringAsFixed(2)} m/s' : '0.00 m/s'),
              _buildDebugRow('Time of Last Fix', timeStr),
              const Divider(height: 16),
              _buildDebugRow('GPS Status', controller.gpsStatusText),
              _buildDebugRow('Mode', controller.isGpsDetected ? 'GPS Auto-Detection' : 'Manual Choice'),
              _buildDebugRow('Follow Mode', controller.isFollowMode ? 'Active' : 'Paused (User panned)'),
              const Divider(height: 16),
              _buildDebugRow('Matched Venue', controller.currentVenue?.name ?? (controller.isOutsidePredefined ? 'Outside Predefined Venues' : 'None')),
              _buildDebugRow('Venue Distance', controller.lastMatchedDistanceMeters != null ? '${controller.lastMatchedDistanceMeters!.toStringAsFixed(1)} m' : 'N/A'),
              _buildDebugRow('Active Category', controller.currentVenueType.displayNameEn),
              const Divider(height: 16),
              const Text('Last Backend Response:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  controller.lastBackendResponse ?? 'None',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF0F172A)),
                ),
              ),
              if (controller.lastError != null) ...[
                const SizedBox(height: 8),
                const Text('Last Error:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    controller.lastError!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF991B1B)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
