import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/communication_models.dart';
import '../data/communication_data.dart';
import '../data/venue_data.dart';
import '../services/api_service.dart';
import '../services/suggest_api.dart';
import '../widgets/suggestion_panel.dart';
import '../widgets/interactive_venue_map.dart';
import '../config/app_config.dart';
import 'category_detail_screen.dart';

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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late final SuggestApi _suggestApi;

  // Selected state
  VenueType _selectedVenueType = VenueType.hospital;
  VenueItem? _activeVenue;
  List<CommunicationCategory> _categories = CommunicationData.hospitalCategories;
  bool _isLoading = false;
  int _currentBottomNavIndex = 0;
  bool _isGpsDetected = true;

  // Current GPS coordinates (Default: Colombo Medical/Central Area)
  double _currentLat = 6.9192;
  double _currentLon = 79.8681;

  // Recent & favorites tracking
  final List<QuickMessageItem> _history = [];
  final Set<String> _favorites = {};

  static const Map<VenueType, List<QuickMessageItem>> _quickMessagesByVenue = {
    VenueType.hospital: [
      QuickMessageItem(
        english: 'I have an appointment',
        sinhala: 'මට වෛද්‍යවරයා හමුවීමට වේලාවක් ඇත.',
        category: 'Registration & Admission',
      ),
      QuickMessageItem(
        english: 'I need to see a doctor',
        sinhala: 'මට වෛද්‍යවරයකු හමුවීමට අවශ්‍යයි.',
        category: 'Registration & Admission',
      ),
      QuickMessageItem(
        english: 'I need emergency assistance',
        sinhala: 'මට හදිසි වෛද්‍ය ප්‍රතිකාර අවශ්‍යයි.',
        category: 'Emergency & Urgent Help',
      ),
      QuickMessageItem(
        english: 'Where is the pharmacy?',
        sinhala: 'රෝහල් ඖෂධාගාරය කොහේද?',
        category: 'Pharmacy & Medication',
      ),
      QuickMessageItem(
        english: 'Where is the restroom?',
        sinhala: 'වැසිකිළිය කොහේද?',
        category: 'Emergency & Urgent Help',
      ),
      QuickMessageItem(
        english: 'I need a wheelchair',
        sinhala: 'මට රෝද පුටුවක් අවශ්‍යයි.',
        category: 'Emergency & Urgent Help',
      ),
    ],
    VenueType.supermarket: [
      QuickMessageItem(
        english: 'Where is the dairy section?',
        sinhala: 'කිරි නිෂ්පාදන අංශය කොහෙද?',
        category: 'Finding products',
      ),
      QuickMessageItem(
        english: 'How much is this?',
        sinhala: 'මෙය කීයද?',
        category: 'Prices and offers',
      ),
      QuickMessageItem(
        english: 'Can you help me reach this?',
        sinhala: 'මට මෙය අරන් දෙන්න පුළුවන්ද?',
        category: 'Getting help and facilities',
      ),
      QuickMessageItem(
        english: 'Where is the billing counter?',
        sinhala: 'මුදල් ගෙවන කවුන්ටරය කොහෙද?',
        category: 'Payments and checkout',
      ),
      QuickMessageItem(
        english: 'Do you have fresh bread?',
        sinhala: 'නැවුම් පාන් තියෙනවාද?',
        category: 'Finding products',
      ),
      QuickMessageItem(
        english: 'Do you accept card payment?',
        sinhala: 'කාඩ්පත් මඟින් ගෙවීම් භාරගන්නවාද?',
        category: 'Payments and checkout',
      ),
    ],
    VenueType.bank: [
      QuickMessageItem(
        english: 'I want to deposit money',
        sinhala: 'මට මුදල් තැන්පත් කිරීමට අවශ්‍යයි.',
        category: 'Deposits & Withdrawals',
      ),
      QuickMessageItem(
        english: 'Where is the ATM?',
        sinhala: 'ATM යන්ත්‍රය කොහේද?',
        category: 'Cards & ATM Services',
      ),
      QuickMessageItem(
        english: 'I need to open an account',
        sinhala: 'මට ගිණුමක් විවෘත කිරීමට අවශ්‍යයි.',
        category: 'Deposits & Withdrawals',
      ),
      QuickMessageItem(
        english: 'What is the token number?',
        sinhala: 'මගේ ටෝකන් අංකය කුමක්ද?',
        category: 'Basic communication',
      ),
      QuickMessageItem(
        english: 'I need to speak to the manager',
        sinhala: 'මට කළමනාකරු හමුවීමට අවශ්‍යයි.',
        category: 'Basic communication',
      ),
      QuickMessageItem(
        english: 'Where is the cash counter?',
        sinhala: 'මුදල් කවුන්ටරය කොහේද?',
        category: 'Deposits & Withdrawals',
      ),
    ],
    VenueType.restaurant: [
      QuickMessageItem(
        english: 'Table for two please',
        sinhala: 'දෙදෙනෙකුට මේසයක් දෙන්න.',
        category: 'Arrival and seating',
      ),
      QuickMessageItem(
        english: 'Can I see the menu?',
        sinhala: 'කෑම මෙනුව බලන්න පුළුවන්ද?',
        category: 'Menu and ordering',
      ),
      QuickMessageItem(
        english: 'Is this vegetarian?',
        sinhala: 'මෙය නිර්මාංශ ආහාරයක්ද?',
        category: 'Menu and ordering',
      ),
      QuickMessageItem(
        english: 'Could we have the bill?',
        sinhala: 'කරුණාකර බිල ගෙනැවිත් දෙන්න.',
        category: 'Menu and ordering',
      ),
      QuickMessageItem(
        english: 'Where is the washroom?',
        sinhala: 'අත් සෝදන ස්ථානය / වැසිකිළිය කොහේද?',
        category: 'Basic communication',
      ),
      QuickMessageItem(
        english: 'Water please',
        sinhala: 'කරුණාකර වතුර ටිකක් දෙන්න.',
        category: 'Menu and ordering',
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _suggestApi = SuggestApi(baseUrl: AppConfig.suggestApiBaseUrl);
    _activeVenue = VenueData.hospitals.first;
    _categories = CommunicationData.hospitalCategories;
  }

  @override
  void dispose() {
    _suggestApi.dispose();
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
    setState(() {
      _selectedVenueType = type;
      _isGpsDetected = false;
      switch (type) {
        case VenueType.supermarket:
          _activeVenue = VenueData.supermarkets.first;
          _categories = CommunicationData.supermarketCategories;
          break;
        case VenueType.hospital:
          _activeVenue = VenueData.hospitals.first;
          _categories = CommunicationData.hospitalCategories;
          break;
        case VenueType.bank:
          _activeVenue = VenueData.banks.first;
          _categories = CommunicationData.bankCategories;
          break;
        case VenueType.restaurant:
          _activeVenue = VenueData.restaurants.first;
          _categories = CommunicationData.restaurantCategories;
          break;
        case VenueType.other:
          _activeVenue = null;
          _categories = [];
          break;
      }
    });
  }

  void _selectVenueItem(VenueItem item, {bool fromGps = false}) {
    setState(() {
      _activeVenue = item;
      _selectedVenueType = item.type;
      _categories = CommunicationData.getCategoriesForVenue(item.type);
      _isGpsDetected = fromGps;
      if (fromGps) {
        _currentLat = item.lat;
        _currentLon = item.lon;
      }
    });
  }

  Future<void> _simulateGpsDetection(double lat, double lon) async {
    setState(() => _isLoading = true);
    final result = await _apiService.detectLocation(lat, lon);
    setState(() {
      _isLoading = false;
      _currentLat = lat;
      _currentLon = lon;
      _isGpsDetected = true;

      final slug = result['detected_slug']?.toString() ?? 'hospital';
      if (slug == 'hospital') {
        _selectedVenueType = VenueType.hospital;
        _categories = CommunicationData.hospitalCategories;
        _activeVenue = VenueData.hospitals.firstWhere(
          (h) => h.name == result['poi_name'],
          orElse: () => VenueData.hospitals.first,
        );
      } else if (slug == 'supermarket') {
        _selectedVenueType = VenueType.supermarket;
        _categories = CommunicationData.supermarketCategories;
        _activeVenue = VenueData.supermarkets.firstWhere(
          (s) => s.name == result['poi_name'],
          orElse: () => VenueData.supermarkets.first,
        );
      } else if (slug == 'bank') {
        _selectedVenueType = VenueType.bank;
        _categories = CommunicationData.bankCategories;
        _activeVenue = VenueData.banks.firstWhere(
          (b) => b.name == result['poi_name'],
          orElse: () => VenueData.banks.first,
        );
      } else if (slug == 'restaurant') {
        _selectedVenueType = VenueType.restaurant;
        _categories = CommunicationData.restaurantCategories;
        _activeVenue = VenueData.restaurants.firstWhere(
          (r) => r.name == result['poi_name'],
          orElse: () => VenueData.restaurants.first,
        );
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS Detected: ${_activeVenue?.name ?? _selectedVenueType.displayNameEn}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: _selectedVenueType.themeColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showFullscreenCardDisplay({
    required String sinhala,
    required String english,
    required String categoryName,
    int? id,
  }) {
    // Record to history
    _history.insert(
      0,
      QuickMessageItem(english: english, sinhala: sinhala, category: categoryName),
    );
    if (_history.length > 30) _history.removeLast();

    final isFav = _favorites.contains(english.isNotEmpty ? english : sinhala);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog.fullscreen(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          size: 30,
                          color: isFav ? const Color(0xFFF59E0B) : Colors.grey,
                        ),
                        onPressed: () {
                          final key = english.isNotEmpty ? english : sinhala;
                          setState(() {
                            if (_favorites.contains(key)) {
                              _favorites.remove(key);
                            } else {
                              _favorites.add(key);
                            }
                          });
                          setDialogState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 32, color: Colors.black87),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: _selectedVenueType.backgroundColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _selectedVenueType.themeColor.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedVenueType.themeColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            id != null ? '#$id  $categoryName' : categoryName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          sinhala,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            height: 1.3,
                          ),
                        ),
                        if (english.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const Divider(color: Colors.black12),
                          const SizedBox(height: 14),
                          Text(
                            english,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Show this screen to the staff member / කාර්ය මණ්ඩලයට පෙන්වන්න',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      final copyText = english.isNotEmpty ? '$sinhala / $english' : sinhala;
                      Clipboard.setData(ClipboardData(text: copyText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message copied to clipboard!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedVenueType.themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text(
                      'Copy Text / පිටපත් කරන්න',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.grid_view_rounded, size: 22, color: Color(0xFF334155)),
          tooltip: 'Menu / Categories',
          onPressed: () {
            setState(() => _currentBottomNavIndex = 1);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'AI Communication Assistant',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hearing, size: 10, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                const Text(
                  'CommAssist Sri Lanka',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, size: 22, color: Color(0xFF2563EB)),
            tooltip: 'Detect via GPS',
            onPressed: () => _simulateGpsDetection(6.9192, 79.8681),
          ),
        ],
      ),
      body: _buildCurrentBody(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentBottomNavIndex,
          onTap: (index) => setState(() => _currentBottomNavIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
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
              icon: Icon(Icons.star_border),
              activeIcon: Icon(Icons.star),
              label: 'Favorites',
            ),
          ],
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
    final messages = _quickMessagesByVenue[_selectedVenueType] ?? [];

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // 1. CURRENT LOCATION CARD (Faithful to Mockup)
                _buildCurrentLocationCard(),

                // 2. INTERACTIVE AREA MAP (Detecting Predefined Locations)
                InteractiveVenueMap(
                  activeVenue: _activeVenue,
                  selectedVenueType: _selectedVenueType,
                  currentLat: _currentLat,
                  currentLon: _currentLon,
                  isGpsLive: _isGpsDetected,
                  onVenueSelected: (venue) {
                    _selectVenueItem(venue, fromGps: false);
                  },
                  onRecenterGps: () {
                    _simulateGpsDetection(6.9192, 79.8681);
                  },
                  onOpenManualSelector: _showManualVenueSelector,
                ),

                // 3. PREDEFINED LOCATION MANUAL SELECTOR CHIPS
                _buildVenueTypeSelectorRow(),

                // 4. "SELECT A MESSAGE" GRID (Faithful to Mockup)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select a Message',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '${_selectedVenueType.displayNameEn} Phrases',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedVenueType.themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildMessageGrid(messages),

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

  // 1. CURRENT LOCATION CARD
  Widget _buildCurrentLocationCard() {
    final venueName = _selectedVenueType.displayNameEn;
    final specificName = _activeVenue?.shortName ?? _activeVenue?.name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Location Pin Icon Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE4E6), // Light rose/pink as in screenshot
              border: Border.all(color: const Color(0xFFFDA4AF), width: 1.5),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFFE11D48), // Pink/Red pin as in screenshot
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Location texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT LOCATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  venueName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (specificName != null)
                  Text(
                    specificName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Text(
                  _isGpsDetected ? 'Detected via GPS' : 'Selected Manually',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // LIVE Badge & Switch Place Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Live green dot
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334155),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _showManualVenueSelector,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. PREDEFINED LOCATION MANUAL SELECTOR CHIPS
  Widget _buildVenueTypeSelectorRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        color: isSelected ? Colors.white : type.themeColor,
      ),
      selectedColor: type.themeColor,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF334155),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? type.themeColor : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      onSelected: (_) => _switchVenueType(type),
    );
  }

  // 4. "SELECT A MESSAGE" GRID (Faithful to Mockup)
  Widget _buildMessageGrid(List<QuickMessageItem> messages) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: messages.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
        ),
        itemBuilder: (ctx, idx) {
          final msg = messages[idx];
          return InkWell(
            onTap: () {
              _showFullscreenCardDisplay(
                sinhala: msg.sinhala,
                english: msg.english,
                categoryName: msg.category,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  msg.english,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 5. CUSTOM TYPING CARD (Faithful to Mockup)
  Widget _buildCustomTypingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                    color: Color(0xFF0F172A),
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
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Type your own message',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 6. AI SUGGESTION & QUICK SEARCH PANEL
  Widget _buildAiSuggestionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
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
    if (_history.isEmpty) {
      return const Center(
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final item = _history[idx];
        return Card(
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
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 3: FAVORITES VIEW
  // -------------------------------------------------------------
  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return const Center(
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
      );
    }

    final favList = _favorites.toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: favList.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (ctx, idx) {
        final phrase = favList[idx];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: const Icon(Icons.star, color: Color(0xFFF59E0B)),
            title: Text(phrase, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () {
                setState(() => _favorites.remove(phrase));
              },
            ),
            onTap: () {
              _showFullscreenCardDisplay(
                sinhala: phrase,
                english: '',
                categoryName: 'Favorite / ප්‍රියතම',
              );
            },
          ),
        );
      },
    );
  }
}
