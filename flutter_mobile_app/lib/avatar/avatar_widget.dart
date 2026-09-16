import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'avatar_controller.dart';
import 'avatar_3d_canvas.dart';
import '../models/alert_level.dart';
import '../models/detection_event.dart';

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AvatarController>(
      builder: (context, avatar, child) {
        Color borderAccentColor = const Color(0xFF00E5FF);
        Color bannerBg = const Color(0xFF141A26);
        final DetectionEvent? event = avatar.currentEvent;

        if (avatar.state == AvatarState.listening) {
          borderAccentColor = const Color(0xFF00E5FF);
          bannerBg = const Color(0xFF00E5FF).withOpacity(0.08);
        } else if (avatar.state == AvatarState.highAlert) {
          borderAccentColor = AlertLevel.high.color;
          bannerBg = AlertLevel.high.color.withOpacity(0.16);
        } else if (avatar.state == AvatarState.mediumAlert) {
          borderAccentColor = AlertLevel.medium.color;
          bannerBg = AlertLevel.medium.color.withOpacity(0.14);
        } else if (avatar.state == AvatarState.lowAlert) {
          borderAccentColor = AlertLevel.low.color;
          bannerBg = AlertLevel.low.color.withOpacity(0.12);
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141A26),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderAccentColor.withOpacity(0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: borderAccentColor.withOpacity(0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section with 3D Status Indicator & Gesture Hint
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: borderAccentColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: borderAccentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "REAL-TIME 3D HUMAN AI AVATAR",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            "Interactive 360° Moving Human Model",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: borderAccentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderAccentColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "Drag 3D Model",
                          style: TextStyle(
                            color: borderAccentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ==========================================
              // REAL MOVING 3D HUMAN AVATAR CANVAS (UNOBSTRUCTED)
              // ==========================================
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Avatar3DCanvas(
                  controller: avatar,
                  height: 320,
                ),
              ),
              const SizedBox(height: 12),

              // ==========================================
              // DEDICATED DETECTED SOUND & PRIORITY CARD (BELOW 3D AVATAR - NOT OVERLAPPING)
              // ==========================================
              if (event != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: event.priority.color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: event.priority.color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: event.priority.color.withOpacity(0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: event.priority.color.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(event.priority.icon, color: event.priority.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    event.titleEnglish,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: event.priority.color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${event.priority.name} (${event.priority.sinhalaLabel})',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              event.titleSinhala,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Dual Sinhala & English Guidance Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bannerBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderAccentColor.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      avatar.sinhalaMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      avatar.englishMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
