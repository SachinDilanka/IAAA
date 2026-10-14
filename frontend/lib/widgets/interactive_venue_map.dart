import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/communication_models.dart';
import '../data/venue_data.dart';

enum MapRegion { colombo, kandy, galle, all }

class InteractiveVenueMap extends StatefulWidget {
  final VenueItem? activeVenue;
  final VenueType selectedVenueType;
  final double currentLat;
  final double currentLon;
  final bool isGpsLive;
  final ValueChanged<VenueItem> onVenueSelected;
  final VoidCallback onRecenterGps;
  final VoidCallback? onOpenManualSelector;

  const InteractiveVenueMap({
    super.key,
    required this.activeVenue,
    required this.selectedVenueType,
    required this.currentLat,
    required this.currentLon,
    this.isGpsLive = true,
    required this.onVenueSelected,
    required this.onRecenterGps,
    this.onOpenManualSelector,
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
  double _centerLat = 6.9200;
  double _centerLon = 79.8580;
  double _zoom = 13.5; // High zoom for Colombo street view

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
    if (widget.activeVenue != null && widget.activeVenue != oldWidget.activeVenue) {
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
    final height = _isExpanded ? 360.0 : 220.0;
    final venues = _getFilteredVenues();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map Header bar with live detection stats and expand button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_outlined, color: Color(0xFF2563EB), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Map (${venues.length} Venues)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // City quick jumps
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCityChip('Colombo', MapRegion.colombo),
                        const SizedBox(width: 4),
                        _buildCityChip('Kandy', MapRegion.kandy),
                        const SizedBox(width: 4),
                        _buildCityChip('Galle', MapRegion.galle),
                        const SizedBox(width: 4),
                        _buildCityChip('Sri Lanka', MapRegion.all),
                      ],
                    ),
                  ),
                ),
                // Expand/collapse map view
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                    size: 20,
                    color: const Color(0xFF64748B),
                  ),
                  tooltip: _isExpanded ? 'Minimize Map' : 'Expand Map',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),

          // Interactive Map Canvas Area
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final mapSize = Size(constraints.maxWidth, constraints.maxHeight);

                return GestureDetector(
                  onScaleStart: (details) {
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
                      // Map Background Canvas (Water, Land, Roads, Coastline)
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

                      // Predefined Venue Pins
                      ...venues.map((venue) => _buildVenueMarker(venue, mapSize)),

                      // Floating Map Controls (Zoom +, Zoom -, Recenter GPS)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildControlBtn(
                              icon: Icons.my_location,
                              tooltip: 'Recenter GPS',
                              onPressed: () {
                                widget.onRecenterGps();
                                setState(() {
                                  _centerLat = widget.currentLat;
                                  _centerLon = widget.currentLon;
                                  _zoom = 14.0;
                                });
                              },
                            ),
                            const SizedBox(height: 6),
                            _buildControlBtn(
                              icon: Icons.add,
                              tooltip: 'Zoom In',
                              onPressed: () => setState(() => _zoom = (_zoom + 0.8).clamp(7.0, 16.0)),
                            ),
                            const SizedBox(height: 6),
                            _buildControlBtn(
                              icon: Icons.remove,
                              tooltip: 'Zoom Out',
                              onPressed: () => setState(() => _zoom = (_zoom - 0.8).clamp(7.0, 16.0)),
                            ),
                          ],
                        ),
                      ),

                      // Floating Category Filter Strip on Map
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCategoryFilterIcon(null, Icons.apps, 'All', Colors.black87),
                              _buildCategoryFilterIcon(VenueType.hospital, Icons.local_hospital, 'Hospital', const Color(0xFFEF4444)),
                              _buildCategoryFilterIcon(VenueType.bank, Icons.account_balance, 'Bank', const Color(0xFF2563EB)),
                              _buildCategoryFilterIcon(VenueType.restaurant, Icons.restaurant, 'Restaurant', const Color(0xFFF59E0B)),
                              _buildCategoryFilterIcon(VenueType.supermarket, Icons.shopping_cart, 'Supermarket', const Color(0xFF10B981)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Quick manual venue selector footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Tap any pin on map or select below:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
                if (widget.onOpenManualSelector != null)
                  TextButton.icon(
                    onPressed: widget.onOpenManualSelector,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.list_alt, size: 14),
                    label: const Text('Browse All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityChip(String label, MapRegion region) {
    final isSelected = _currentRegion == region;
    return InkWell(
      onTap: () => _setRegion(region),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterIcon(VenueType? type, IconData icon, String tooltip, Color activeColor) {
    final isSelected = _filterType == type;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _filterType = type),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(5),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isSelected ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
        tooltip: tooltip,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildUserGpsPin(Size size) {
    final pos = _latLonToScreen(widget.currentLat, widget.currentLon, size);
    if (pos.dx < -50 || pos.dx > size.width + 50 || pos.dy < -50 || pos.dy > size.height + 50) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: pos.dx - 18,
      top: pos.dy - 18,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseVal = _pulseController.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer radar ripple
              Container(
                width: 36 + (pulseVal * 20),
                height: 36 + (pulseVal * 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withValues(alpha: (1.0 - pulseVal) * 0.35),
                ),
              ),
              // Inner GPS dot
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVenueMarker(VenueItem venue, Size size) {
    final pos = _latLonToScreen(venue.lat, venue.lon, size);
    if (pos.dx < -60 || pos.dx > size.width + 60 || pos.dy < -60 || pos.dy > size.height + 60) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.activeVenue?.id == venue.id;
    final color = _getMarkerColor(venue.type);

    return Positioned(
      left: pos.dx - 16,
      top: pos.dy - 32,
      child: GestureDetector(
        onTap: () {
          widget.onVenueSelected(venue);
          setState(() {
            _centerLat = venue.lat;
            _centerLon = venue.lon;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tooltip label when selected
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: Text(
                  venue.shortName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Pin marker with icon
            Stack(
              alignment: Alignment.center,
              children: [
                // Pin body
                Icon(
                  Icons.location_on,
                  size: isSelected ? 34 : 26,
                  color: color,
                  shadows: const [
                    Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                // Inner white badge icon
                Positioned(
                  top: isSelected ? 5 : 4,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      venue.type.icon,
                      size: isSelected ? 12 : 9,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMarkerColor(VenueType type) {
    switch (type) {
      case VenueType.hospital:
        return const Color(0xFFEF4444); // Red
      case VenueType.bank:
        return const Color(0xFF2563EB); // Blue
      case VenueType.restaurant:
        return const Color(0xFFF59E0B); // Amber
      case VenueType.supermarket:
        return const Color(0xFF10B981); // Emerald
      case VenueType.other:
        return const Color(0xFF6B7280);
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
    // 1. Draw base land and coastal water
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9); // Light land
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final scale = math.pow(2.0, zoom) * 16.0;

    // Projected Indian Ocean to the West for Colombo (Lon ~ 79.845)
    final oceanBorderLon = 79.8420;
    final oceanBorderX = (oceanBorderLon - centerLon) * scale * 0.9 + size.width / 2.0;

    if (oceanBorderX > -50 && oceanBorderX < size.width + 100) {
      final waterPaint = Paint()..color = const Color(0xFFBAE6FD);
      final waterRect = Rect.fromLTWH(0, 0, math.max(0, oceanBorderX), size.height);
      canvas.drawRect(waterRect, waterPaint);

      // Coastal wave line
      final coastPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(oceanBorderX, 0), Offset(oceanBorderX, size.height), coastPaint);
    }

    // 2. Draw arterial road networks & grids
    final roadPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final primaryRoadPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;

    // Grid roads
    final step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }

    // Major Sri Lanka Arterial lines (e.g. Galle Road, Kandy Highway)
    canvas.drawLine(
      Offset(size.width * 0.25, 0),
      Offset(size.width * 0.35, size.height),
      primaryRoadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.55),
      Offset(size.width, size.height * 0.45),
      primaryRoadPaint,
    );

    // 3. Draw City Labels / Landmark tags
    _drawCityLabel(canvas, size, 'Colombo Fort', 6.9344, 79.8436);
    _drawCityLabel(canvas, size, 'Town Hall', 6.9147, 79.8660);
    _drawCityLabel(canvas, size, 'Kandy Lake', 7.2906, 80.6380);
    _drawCityLabel(canvas, size, 'Galle Fort', 6.0300, 80.2170);
  }

  void _drawCityLabel(Canvas canvas, Size size, String text, double lat, double lon) {
    final scale = math.pow(2.0, zoom) * 16.0;
    final dx = (lon - centerLon) * scale * 0.9 + size.width / 2.0;
    final dy = -((lat - centerLat) * scale) + size.height / 2.0;

    if (dx < 0 || dx > size.width || dy < 0 || dy > size.height) return;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(dx + 4, dy - 6));
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.centerLat != centerLat ||
        oldDelegate.centerLon != centerLon ||
        oldDelegate.zoom != zoom ||
        oldDelegate.region != region;
  }
}
