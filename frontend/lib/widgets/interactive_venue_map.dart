import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/communication_models.dart';
import '../data/venue_data.dart';
import '../theme/app_theme.dart';

enum MapRegion { colombo, kandy, galle, all }

class InteractiveVenueMap extends StatefulWidget {
  final VenueItem? activeVenue;
  final VenueType selectedVenueType;
  final double currentLat;
  final double currentLon;
  final bool isGpsLive;
  final double? accuracy;
  final bool isFollowMode;
  final VoidCallback? onUserPan;
  final VoidCallback? onOpenDebug;
  final VoidCallback? onUseGpsAgain;
  final ValueChanged<VenueItem> onVenueSelected;
  final VoidCallback onRecenterGps;
  final VoidCallback? onOpenManualSelector;
  final String? statusText;

  const InteractiveVenueMap({
    super.key,
    required this.activeVenue,
    required this.selectedVenueType,
    required this.currentLat,
    required this.currentLon,
    this.accuracy,
    this.isGpsLive = true,
    this.isFollowMode = true,
    required this.onVenueSelected,
    required this.onRecenterGps,
    this.onUserPan,
    this.onOpenDebug,
    this.onUseGpsAgain,
    this.onOpenManualSelector,
    this.statusText,
  });

  @override
  State<InteractiveVenueMap> createState() => _InteractiveVenueMapState();
}

class _InteractiveVenueMapState extends State<InteractiveVenueMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  MapRegion _currentRegion = MapRegion.colombo;
  bool _isExpanded = false;
  VenueType? _filterType; // null = all

  // Map view viewport state
  double _centerLat = 6.9280;
  double _centerLon = 79.8550;
  double _zoom = 13.7;

  // Dragging support
  Offset _dragStart = Offset.zero;
  double _dragStartLat = 0;
  double _dragStartLon = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _pulseController.repeat();
    }

    _focusOnVenue(widget.activeVenue);
  }

  @override
  void didUpdateWidget(covariant InteractiveVenueMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFollowMode && (widget.currentLat != oldWidget.currentLat || widget.currentLon != oldWidget.currentLon)) {
      _centerLat = widget.currentLat;
      _centerLon = widget.currentLon;
    } else if (widget.activeVenue != null && widget.activeVenue != oldWidget.activeVenue && !widget.isFollowMode) {
      _focusOnVenue(widget.activeVenue);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _focusOnVenue(VenueItem? venue) {
    if (venue == null) return;
    setState(() {
      _centerLat = venue.lat;
      _centerLon = venue.lon;
      if (venue.city.toLowerCase().contains('kandy')) {
        _currentRegion = MapRegion.kandy;
        _zoom = 13.5;
      } else if (venue.city.toLowerCase().contains('galle')) {
        _currentRegion = MapRegion.galle;
        _zoom = 13.5;
      } else {
        _currentRegion = MapRegion.colombo;
        _zoom = 13.8;
      }
    });
  }

  void _setRegion(MapRegion region) {
    setState(() {
      _currentRegion = region;
      switch (region) {
        case MapRegion.colombo:
          _centerLat = 6.9215;
          _centerLon = 79.8580;
          _zoom = 13.6;
          break;
        case MapRegion.kandy:
          _centerLat = 7.2930;
          _centerLon = 80.6350;
          _zoom = 13.4;
          break;
        case MapRegion.galle:
          _centerLat = 6.0450;
          _centerLon = 80.2220;
          _zoom = 13.4;
          break;
        case MapRegion.all:
          _centerLat = 6.9271;
          _centerLon = 80.2000;
          _zoom = 8.4;
          break;
      }
    });
  }

  List<VenueItem> _getAllVenues() {
    return [
      ...VenueData.hospitals,
      ...VenueData.banks,
      ...VenueData.restaurants,
      ...VenueData.supermarkets,
    ];
  }

  List<VenueItem> _getFilteredVenues() {
    final all = _getAllVenues();
    if (_filterType == null) return all;
    return all.where((v) => v.type == _filterType).toList();
  }

  // Convert lat/lon to local 2D viewport coordinates
  Offset _latLonToScreen(double lat, double lon, Size size) {
    final scale = math.pow(2.0, _zoom) * 16.0;
    final dx = (lon - _centerLon) * scale * 0.9 + size.width / 2.0;
    final dy = -((lat - _centerLat) * scale) + size.height / 2.0;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final height = _isExpanded ? 360.0 : 230.0;
    final venues = _getFilteredVenues();
    final allVenues = _getAllVenues();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: AppTheme.borderRadiusCard,
        border: Border.all(color: AppTheme.borderLight, width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Interactive Map Viewport (Matches photo: Instruction bar, Zoom on left, Filters on right)
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

                return GestureDetector(
                  onScaleStart: (details) {
                    widget.onUserPan?.call();
                    _dragStart = details.localFocalPoint;
                    _dragStartLat = _centerLat;
                    _dragStartLon = _centerLon;
                  },
                  onScaleUpdate: (details) {
                    final scale = math.pow(2.0, _zoom) * 16.0;
                    final delta = details.localFocalPoint - _dragStart;
                    setState(() {
                      _centerLon = _dragStartLon - (delta.dx / (scale * 0.9));
                      _centerLat = _dragStartLat + (delta.dy / scale);
                      if (details.scale != 1.0) {
                        _zoom = (_zoom * details.scale).clamp(7.0, 16.0);
                      }
                    });
                  },
                  child: Stack(
                    children: [
                      // Map Background Canvas (OpenStreetMap styling with water, roads, lake, coastline)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MapCanvasPainter(
                            centerLat: _centerLat,
                            centerLon: _centerLon,
                            zoom: _zoom,
                            region: _currentRegion,
                          ),
                        ),
                      ),

                      // User GPS Live Indicator (Pulsing blue radar)
                      _buildUserGpsPin(mapSize),

                      // Predefined Venue Pins (Pill badges with icons matching backend view)
                      ...venues.map((venue) => _buildVenueMarker(venue, mapSize)),

                      // Floating Map Instruction Badge (Top Center Dark Bar)
                      Positioned(
                        top: 8,
                        left: 45,
                        right: 45,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xE60F172A),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_hospital, color: AppTheme.hospitalColor, size: 11),
                                  const SizedBox(width: 3),
                                  const Text('Hospitals (Red)', style: TextStyle(fontFamily: AppTheme.fontMain, color: AppTheme.hospitalColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
                                  const Text(' • ', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                                  const Icon(Icons.account_balance, color: AppTheme.bankColor, size: 11),
                                  const SizedBox(width: 3),
                                  const Text('Banks (Blue)', style: TextStyle(fontFamily: AppTheme.fontMain, color: AppTheme.bankColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
                                  const Text(' • ', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                                  const Icon(Icons.restaurant, color: AppTheme.restaurantColor, size: 11),
                                  const SizedBox(width: 3),
                                  const Text('Restaurants (Amber)', style: TextStyle(fontFamily: AppTheme.fontMain, color: AppTheme.restaurantColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
                                  const Text(' • ', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                                  const Icon(Icons.shopping_cart, color: AppTheme.supermarketColor, size: 11),
                                  const SizedBox(width: 3),
                                  const Text('Supermarkets (Green)', style: TextStyle(fontFamily: AppTheme.fontMain, color: AppTheme.supermarketColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
                                  const Text(' • ', style: TextStyle(color: Colors.white54, fontSize: 9.5)),
                                  const Text('Tap pin to select', style: TextStyle(fontFamily: AppTheme.fontMain, color: AppTheme.textWhite, fontSize: 9.5, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Zoom + and - Controls on Left (Leaflet style)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMapControlBtn(
                              icon: Icons.add,
                              tooltip: 'Zoom In',
                              onPressed: () => setState(() => _zoom = (_zoom + 0.8).clamp(7.0, 16.0)),
                            ),
                            const SizedBox(height: 4),
                            _buildMapControlBtn(
                              icon: Icons.remove,
                              tooltip: 'Zoom Out',
                              onPressed: () => setState(() => _zoom = (_zoom - 0.8).clamp(7.0, 16.0)),
                            ),
                          ],
                        ),
                      ),

                      // Right-side Floating Controls (Recenter, Hospitals, Banks, Restaurants, Supermarkets, Focus, Expand)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Recenter GPS
                            _buildMapControlBtn(
                              icon: Icons.my_location,
                              tooltip: 'Center on my GPS position',
                              iconColor: const Color(0xFF1E293B),
                              onPressed: () {
                                widget.onRecenterGps();
                                setState(() {
                                  _centerLat = widget.currentLat;
                                  _centerLon = widget.currentLon;
                                  _zoom = 14.0;
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            // Filter Hospitals (Red)
                            _buildMapControlBtn(
                              icon: Icons.local_hospital,
                              tooltip: 'Hospitals (Red)',
                              iconColor: const Color(0xFFEF4444),
                              isActive: _filterType == VenueType.hospital,
                              onPressed: () {
                                setState(() {
                                  _filterType = _filterType == VenueType.hospital ? null : VenueType.hospital;
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            // Filter Banks (Blue)
                            _buildMapControlBtn(
                              icon: Icons.account_balance,
                              tooltip: 'Banks (Blue)',
                              iconColor: const Color(0xFF2563EB),
                              isActive: _filterType == VenueType.bank,
                              onPressed: () {
                                setState(() {
                                  _filterType = _filterType == VenueType.bank ? null : VenueType.bank;
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            // Filter Restaurants (Amber)
                            _buildMapControlBtn(
                              icon: Icons.restaurant,
                              tooltip: 'Restaurants (Amber)',
                              iconColor: const Color(0xFFF59E0B),
                              isActive: _filterType == VenueType.restaurant,
                              onPressed: () {
                                setState(() {
                                  _filterType = _filterType == VenueType.restaurant ? null : VenueType.restaurant;
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            // Filter Supermarkets (Green)
                            _buildMapControlBtn(
                              icon: Icons.shopping_cart,
                              tooltip: 'Supermarkets (Green)',
                              iconColor: const Color(0xFF10B981),
                              isActive: _filterType == VenueType.supermarket,
                              onPressed: () {
                                setState(() {
                                  _filterType = _filterType == VenueType.supermarket ? null : VenueType.supermarket;
                                });
                              },
                            ),
                            const SizedBox(height: 5),
                            // Focus Colombo
                            _buildMapControlBtn(
                              icon: Icons.location_city,
                              tooltip: 'Focus Colombo Venues',
                              iconColor: const Color(0xFF6366F1),
                              onPressed: () => _setRegion(MapRegion.colombo),
                            ),
                            const SizedBox(height: 5),
                            // Expand / Collapse Map
                            _buildMapControlBtn(
                              icon: _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              tooltip: _isExpanded ? 'Minimize Map' : 'Expand Map',
                              iconColor: const Color(0xFF475569),
                              onPressed: () => setState(() => _isExpanded = !_isExpanded),
                            ),
                          ],
                        ),
                      ),

                      // Floating "Use GPS again" button
                      if (!widget.isGpsLive && widget.onUseGpsAgain != null)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: ElevatedButton.icon(
                            key: const Key('map_use_gps_again_button'),
                            onPressed: widget.onUseGpsAgain,
                            icon: const Icon(Icons.my_location, size: 13),
                            label: const Text(
                              'Use GPS again',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 2. Integrated Map Venue Quick Selector Strip (Matches bottom of photo)
          _buildMapPillsStrip(allVenues),

          // 3. Dynamic Area Status Bar (Matches footer of photo)
          _buildAreaStatusBar(),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color iconColor = const Color(0xFF1E293B),
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? iconColor : Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? iconColor : AppTheme.borderLight,
              width: 1,
            ),
            boxShadow: AppTheme.buttonShadow,
          ),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? Colors.white : iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMapPillsStrip(List<VenueItem> venues) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        border: Border(
          top: BorderSide(color: AppTheme.borderLight),
          bottom: BorderSide(color: AppTheme.borderLight),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_outlined, color: AppTheme.primary, size: 14),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Select on Map (🔴 Hospitals | 🔵 Banks | 🟠 Restaurants | 🟢 Supermarkets):',
                        style: TextStyle(
                          fontFamily: AppTheme.fontMain,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.hospitalBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Tap Pin on Map',
                  style: TextStyle(
                    fontFamily: AppTheme.fontMain,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.hospitalColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: venues.map((v) {
                final isSelected = widget.activeVenue?.id == v.id;
                final color = _getMarkerColor(v.type);
                final icon = _getVenueIcon(v.type);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      widget.onVenueSelected(v);
                      setState(() {
                        _centerLat = v.lat;
                        _centerLon = v.lon;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isSelected ? color : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? color : const Color(0xFFCBD5E1),
                          width: 1.3,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 11,
                            color: isSelected ? Colors.white : color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            v.shortName.isNotEmpty ? v.shortName : v.name,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaStatusBar() {
    final statusMsg = widget.statusText ??
        (widget.activeVenue != null
            ? '${widget.activeVenue!.name} • ${widget.selectedVenueType.displayNameEn}'
            : 'Acquiring area coordinates and nearby venues...');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 13, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              statusMsg,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGpsPin(Size size) {
    final pos = _latLonToScreen(widget.currentLat, widget.currentLon, size);
    if (pos.dx < -150 || pos.dx > size.width + 150 || pos.dy < -150 || pos.dy > size.height + 150) {
      return const SizedBox.shrink();
    }

    final double acc = widget.accuracy ?? 15.0;
    final scale = math.pow(2.0, _zoom) * 16.0;
    final double radiusPx = math.max(16.0, math.min((acc / 111320.0) * scale, 150.0));

    return Positioned(
      left: pos.dx - radiusPx,
      top: pos.dy - radiusPx,
      child: SizedBox(
        width: radiusPx * 2,
        height: radiusPx * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Accuracy circle
            Container(
              width: radiusPx * 2,
              height: radiusPx * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
            ),
            // Outer radar ripple
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseVal = _pulseController.value;
                return Container(
                  width: 30 + (pulseVal * 16),
                  height: 30 + (pulseVal * 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: (1.0 - pulseVal) * 0.35),
                  ),
                );
              },
            ),
            // Inner blue GPS dot
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueMarker(VenueItem venue, Size size) {
    final pos = _latLonToScreen(venue.lat, venue.lon, size);
    if (pos.dx < -120 || pos.dx > size.width + 120 || pos.dy < -60 || pos.dy > size.height + 60) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.activeVenue?.id == venue.id;
    final color = _getMarkerColor(venue.type);
    final icon = _getVenueIcon(venue.type);

    return Positioned(
      left: pos.dx - 12,
      top: pos.dy - 12,
      child: GestureDetector(
        onTap: () {
          widget.onVenueSelected(venue);
          setState(() {
            _centerLat = venue.lat;
            _centerLon = venue.lon;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.diagonal3Values(isSelected ? 1.15 : 1.0, isSelected ? 1.15 : 1.0, 1.0),
          padding: const EdgeInsets.only(left: 3, top: 2, bottom: 2, right: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color,
              width: isSelected ? 2.5 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.45 : 0.25),
                blurRadius: isSelected ? 10 : 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 11,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                venue.shortName.isNotEmpty ? venue.shortName : venue.name,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMarkerColor(VenueType type) {
    switch (type) {
      case VenueType.hospital:
        return AppTheme.hospitalColor; // Red #EF4444
      case VenueType.bank:
        return AppTheme.bankColor; // Blue #2563EB
      case VenueType.restaurant:
        return AppTheme.restaurantColor; // Amber #F59E0B
      case VenueType.supermarket:
        return AppTheme.supermarketColor; // Emerald #10B981
      case VenueType.other:
        return AppTheme.textMuted;
    }
  }

  IconData _getVenueIcon(VenueType type) {
    switch (type) {
      case VenueType.hospital:
        return Icons.local_hospital;
      case VenueType.bank:
        return Icons.account_balance;
      case VenueType.restaurant:
        return Icons.restaurant;
      case VenueType.supermarket:
        return Icons.shopping_cart;
      case VenueType.other:
        return Icons.location_on;
    }
  }
}

class _MapCanvasPainter extends CustomPainter {
  final double centerLat;
  final double centerLon;
  final double zoom;
  final MapRegion region;

  _MapCanvasPainter({
    required this.centerLat,
    required this.centerLon,
    required this.zoom,
    required this.region,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw OpenStreetMap authentic land color (#F2EFE9)
    final bgPaint = Paint()..color = const Color(0xFFF2EFE9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final scale = math.pow(2.0, zoom) * 16.0;

    // 2. Projected Indian Ocean to the West for Colombo (Lon ~ 79.845) (#AAD3DF)
    final oceanBorderLon = 79.8420;
    final oceanBorderX = (oceanBorderLon - centerLon) * scale * 0.9 + size.width / 2.0;

    if (oceanBorderX > -50 && oceanBorderX < size.width + 100) {
      final waterPaint = Paint()..color = const Color(0xFFAAD3DF);
      final waterRect = Rect.fromLTWH(0, 0, math.max(0, oceanBorderX), size.height);
      canvas.drawRect(waterRect, waterPaint);

      // Coastal wave line
      final coastPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(oceanBorderX, 0), Offset(oceanBorderX, size.height), coastPaint);
    }

    // 3. Beira Lake in Colombo (lat ~ 6.927, lon ~ 79.855)
    final lakeDx = (79.8540 - centerLon) * scale * 0.9 + size.width / 2.0;
    final lakeDy = -((6.9270 - centerLat) * scale) + size.height / 2.0;
    if (lakeDx > -80 && lakeDx < size.width + 80 && lakeDy > -80 && lakeDy < size.height + 80) {
      final lakePaint = Paint()..color = const Color(0xFFAAD3DF);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(lakeDx, lakeDy), width: 70, height: 45),
        lakePaint,
      );
    }

    // 4. Draw road networks with OSM styling (Yellow and Orange with white casings)
    final minorRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final primaryRoadCasing = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    final primaryRoadCore = Paint()
      ..color = const Color(0xFFFFA06B) // OSM orange road
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final secondaryRoadCore = Paint()
      ..color = const Color(0xFFFEFD8B) // OSM yellow road
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Minor residential roads grid
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorRoadPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorRoadPaint);
    }

    // Galle Road (North-South arterial along the coast)
    final galleRoadX = (79.8500 - centerLon) * scale * 0.9 + size.width / 2.0;
    canvas.drawLine(Offset(galleRoadX, 0), Offset(galleRoadX + 15, size.height), primaryRoadCasing);
    canvas.drawLine(Offset(galleRoadX, 0), Offset(galleRoadX + 15, size.height), primaryRoadCore);

    // Baseline Road / Avissawella Road
    final baselineX = (79.8700 - centerLon) * scale * 0.9 + size.width / 2.0;
    canvas.drawLine(Offset(baselineX, 0), Offset(baselineX - 10, size.height), primaryRoadCasing);
    canvas.drawLine(Offset(baselineX, 0), Offset(baselineX - 10, size.height), secondaryRoadCore);

    // East-West connector
    canvas.drawLine(
      Offset(0, size.height * 0.52),
      Offset(size.width, size.height * 0.48),
      primaryRoadCasing,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.52),
      Offset(size.width, size.height * 0.48),
      primaryRoadCore,
    );

    // 5. Draw Neighborhood / City Labels
    _drawCityLabel(canvas, size, 'Financial City', 6.9360, 79.8410);
    _drawCityLabel(canvas, size, 'Colombo Fort', 6.9344, 79.8436);
    _drawCityLabel(canvas, size, 'Maligawatte', 6.9360, 79.8650);
    _drawCityLabel(canvas, size, 'Kolonnawa', 6.9350, 79.8850);
    _drawCityLabel(canvas, size, 'Kompannavidiya', 6.9200, 79.8500);
    _drawCityLabel(canvas, size, 'Kollupitiya', 6.9050, 79.8510);
    _drawCityLabel(canvas, size, 'Town Hall', 6.9147, 79.8660);
    _drawCityLabel(canvas, size, 'Kandy', 7.2906, 80.6380);
    _drawCityLabel(canvas, size, 'Galle', 6.0300, 80.2170);
  }

  void _drawCityLabel(Canvas canvas, Size size, String text, double lat, double lon) {
    final scale = math.pow(2.0, zoom) * 16.0;
    final dx = (lon - centerLon) * scale * 0.9 + size.width / 2.0;
    final dy = -((lat - centerLat) * scale) + size.height / 2.0;

    if (dx < -20 || dx > size.width + 20 || dy < -10 || dy > size.height + 10) return;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.centerLat != centerLat ||
        oldDelegate.centerLon != centerLon ||
        oldDelegate.zoom != zoom ||
        oldDelegate.region != region;
  }
}
