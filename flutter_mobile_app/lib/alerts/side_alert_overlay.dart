import 'package:flutter/material.dart';
import '../models/detection_event.dart';
import '../ai/sound_classifier_service.dart';
import '../wearable/smartwatch_service.dart';

/// A sleek, modern, user-friendly floating side overlay alert for real-time sound detections.
/// Slides in smoothly from the right side without blocking center content.
class SideAlertOverlay extends StatefulWidget {
  final DetectionEvent event;
  final SoundClassifierService classifier;
  final SmartwatchService watch;

  const SideAlertOverlay({
    super.key,
    required this.event,
    required this.classifier,
    required this.watch,
  });


  @override
  State<SideAlertOverlay> createState() => _SideAlertOverlayState();
}

class _SideAlertOverlayState extends State<SideAlertOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    // 7-second duration matching the service's auto-dismiss timer
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.35, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.08, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.08, curve: Curves.easeIn),
      ),
    );

    // Progress bar runs from 1.0 down to 0.0 over 7 seconds
    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.linear,
      ),
    );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant SideAlertOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) {
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _dismiss() {
    widget.classifier.dismissActiveAlert();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final color = event.priority.color;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrWide = screenWidth > 640;

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismiss(),
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: isDesktopOrWide ? 400 : double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: const Color(0xF00F172A), // Deep Slate Obsidian Glass
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(-2, 6),
                ),
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Left Vertical Color Indicator Bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4.5,
                    color: color,
                  ),
                ),

                // Main Content Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Urgency Pill + Confidence + Close Button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  event.priority.icon,
                                  color: color,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${event.priority.name} EMERGENCY',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(event.confidence * 100).toStringAsFixed(0)}% MATCH',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Quick Close button
                          InkWell(
                            onTap: _dismiss,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Sound Detection Info Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Glow Icon Backdrop
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              event.priority.icon,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.titleEnglish,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  event.titleSinhala,
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansSinhala',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Guidance Snippet
                      if (event.avatarGuidanceEnglish.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.avatarGuidanceEnglish,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11.5,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Hardware / Smartwatch Delivery Route Footer
                      Row(
                        children: [
                          Icon(
                            widget.watch.isDeviceConnected
                                ? Icons.watch_rounded
                                : Icons.phonelink_ring_rounded,
                            color: widget.watch.isDeviceConnected
                                ? const Color(0xFF10B981)
                                : color,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.watch.isDeviceConnected
                                  ? 'Dispatched to Yesido IO39 Smartwatch'
                                  : 'Tactile Haptic Pulse Dispatched to Phone',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Swipe to dismiss →',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Countdown Linear Progress Bar at bottom
                Positioned(
                  left: 4.5,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 2.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          color.withValues(alpha: 0.8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
