import 'package:flutter/material.dart';
import '../models/communication_models.dart';
import '../data/communication_data.dart';
import '../data/venue_data.dart';
import '../services/api_service.dart';
import 'category_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  VenueType _selectedVenueType = VenueType.supermarket;
  VenueItem? _activeVenue;
  List<CommunicationCategory> _categories = CommunicationData.supermarketCategories;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _activeVenue = VenueData.supermarkets.first;
    _categories = CommunicationData.supermarketCategories;
  }

  void _switchVenueType(VenueType type) {
    setState(() {
      _selectedVenueType = type;
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

  void _selectVenueItem(VenueItem item) {
    setState(() {
      _activeVenue = item;
      _selectedVenueType = item.type;
      _categories = CommunicationData.getCategoriesForVenue(item.type);
    });
  }

  Future<void> _simulateGpsDetection(double lat, double lon) async {
    setState(() => _isLoading = true);
    final result = await _apiService.detectLocation(lat, lon);
    setState(() {
      _isLoading = false;
      final slug = result['detected_slug']?.toString() ?? 'supermarket';
      if (slug == 'supermarket') {
        _selectedVenueType = VenueType.supermarket;
        _categories = CommunicationData.supermarketCategories;
      } else if (slug == 'hospital') {
        _selectedVenueType = VenueType.hospital;
        _categories = CommunicationData.hospitalCategories;
      } else if (slug == 'bank') {
        _selectedVenueType = VenueType.bank;
        _categories = CommunicationData.bankCategories;
      } else if (slug == 'restaurant') {
        _selectedVenueType = VenueType.restaurant;
        _categories = CommunicationData.restaurantCategories;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detected: ${_selectedVenueType.displayNameEn} (${result['poi_name'] ?? 'Venue'})'),
          backgroundColor: _selectedVenueType.themeColor,
        ),
      );
    }
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
                const Text(
                  'Custom Message / පණිවිඩය',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                )
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type your message in Sinhala or English...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final txt = textController.text.trim();
                if (txt.isEmpty) return;
                Navigator.of(ctx).pop();
                showDialog(
                  context: context,
                  builder: (dCtx) => Dialog.fullscreen(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 32),
                              onPressed: () => Navigator.of(dCtx).pop(),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: _selectedVenueType.backgroundColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: _selectedVenueType.themeColor, width: 2),
                            ),
                            child: Text(
                              txt,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedVenueType.themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Display Fullscreen Card', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _selectedVenueType.themeColor;
    final totalMessages = _categories.fold<int>(0, (sum, c) => sum + c.count);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hearing_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'CommAssist Sri Lanka',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_outlined, size: 26),
            tooltip: 'Type Custom Message',
            onPressed: _showCustomMessageDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Venue Type Selector Bar (GPS Simulation chips)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildVenueChip(VenueType.supermarket, 'Supermarket (9 Cat.)'),
                          const SizedBox(width: 8),
                          _buildVenueChip(VenueType.hospital, 'Hospital (4 Cat.)'),
                          const SizedBox(width: 8),
                          _buildVenueChip(VenueType.bank, 'Bank (3 Cat.)'),
                          const SizedBox(width: 8),
                          _buildVenueChip(VenueType.restaurant, 'Restaurant (3 Cat.)'),
                        ],
                      ),
                    ),
                  ),

                  // Detected Location Status Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _selectedVenueType.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_selectedVenueType.icon, color: themeColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _activeVenue?.name ?? _selectedVenueType.displayNameEn,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeVenue?.address ?? '${_selectedVenueType.displayNameSi} - Sri Lanka',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _selectedVenueType.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_categories.length} Categories',
                                style: TextStyle(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalMessages Suggested Phrases',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Sri Lanka Outlets Quick Switcher Pills
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Nearby Outlets / ආසන්න ස්ථාන (${_selectedVenueType.displayNameEn})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _getCurrentVenueList().length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final v = _getCurrentVenueList()[idx];
                        final isSelected = _activeVenue?.id == v.id;
                        return ChoiceChip(
                          label: Text(v.shortName),
                          selected: isSelected,
                          onSelected: (_) => _selectVenueItem(v),
                          selectedColor: themeColor.withOpacity(0.18),
                          labelStyle: TextStyle(
                            color: isSelected ? themeColor : const Color(0xFF334155),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? themeColor : const Color(0xFFCBD5E1),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Categories Section Heading
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(_selectedVenueType.icon, size: 18, color: themeColor),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedVenueType.displayNameEn} Criteria / කාණ්ඩ',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Categories List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                                color: Colors.black.withOpacity(0.02),
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
            ),
    );
  }

  List<VenueItem> _getCurrentVenueList() {
    switch (_selectedVenueType) {
      case VenueType.supermarket:
        return VenueData.supermarkets;
      case VenueType.hospital:
        return VenueData.hospitals;
      case VenueType.bank:
        return VenueData.banks;
      case VenueType.restaurant:
        return VenueData.restaurants;
      case VenueType.other:
        return [];
    }
  }

  Widget _buildVenueChip(VenueType type, String label) {
    final isSelected = _selectedVenueType == type;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(type.icon, size: 16, color: isSelected ? Colors.white : type.themeColor),
      backgroundColor: type.backgroundColor,
      selectedColor: type.themeColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : type.themeColor,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? type.themeColor : Colors.transparent),
      ),
      onSelected: (_) => _switchVenueType(type),
    );
  }
}
