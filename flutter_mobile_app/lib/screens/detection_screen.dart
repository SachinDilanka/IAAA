import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ai/sound_classifier_service.dart';
import '../models/alert_level.dart';

class DetectionScreen extends StatelessWidget {
  const DetectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Live Spectrogram & Acoustic AI Monitor',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'REAL-TIME AUDIO SPECTROGRAM (16 kHz)',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Consumer<SoundClassifierService>(
                  builder: (context, classifier, child) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: classifier.isListening
                          ? const Color(0xFF059669).withValues(alpha: 0.2)
                          : const Color(0xFFDC2626).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: classifier.isListening ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Text(
                      classifier.isListening ? 'LIVE' : 'PAUSED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: classifier.isListening ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Live Audio Spectrogram Bars Widget (Natural Gradient)
            Consumer<SoundClassifierService>(
              builder: (context, classifier, child) {
                final frame = classifier.liveSpectrogramFrame;
                return Container(
                  height: 140,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: frame.map((val) {
                      final normalized = val.clamp(0.05, 1.0);
                      Color barColor;
                      if (normalized > 0.6) {
                        barColor = const Color(0xFFDC2626);
                      } else if (normalized > 0.3) {
                        barColor = const Color(0xFFD97706);
                      } else {
                        barColor = const Color(0xFF059669);
                      }

                      return Container(
                        width: 5,
                        height: 110 * normalized,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            const Text(
              'OFFLINE AI MULTI-BRANCH INFERENCE ENGINE',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  _buildBranchRow("Environmental Sound Branch", "Log-Mel Spectrogram -> 2D CNN (TFLite)"),
                  const Divider(color: Color(0xFF334155)),
                  _buildBranchRow("Sinhala Keyword Spotting (KWS)", "Formant Spectrogram -> 7-Class Emergency KWS CNN"),
                  const Divider(color: Color(0xFF334155)),
                  _buildBranchRow("Priority-Engine Haptic Router", "High (Continuous Pulse) / Medium (2-Pulse) / Low (1-Tap)"),
                  const Divider(color: Color(0xFF334155)),
                  _buildBranchRow("Visual Guidance & Alert System", "High-Contrast Dual Sinhala & English Visual Action Guides"),
                  const Divider(color: Color(0xFF334155)),
                  _buildBranchRow("Wearable Alert Delivery", "Yesido IO39 Bluetooth BLE & Notification Channel Sync"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Sound Test Triggers
            const Text(
              'QUICK SINHALA KEYWORD & SOUND TEST PIPELINE',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  context,
                  label: '🆘 "උදව්" (98%)',
                  color: AlertLevel.high.color,
                  onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                      .simulateDetection('udaw', confidence: 0.98),
                ),
                _buildChip(
                  context,
                  label: '🆘 "බේරගන්න" (97%)',
                  color: AlertLevel.high.color,
                  onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                      .simulateDetection('beeraganna', confidence: 0.97),
                ),
                _buildChip(
                  context,
                  label: '🔥 "ගින්නක්" (97%)',
                  color: AlertLevel.high.color,
                  onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                      .simulateDetection('ginnak', confidence: 0.97),
                ),
                _buildChip(
                  context,
                  label: '⚠️ "අනතුරක්" (96%)',
                  color: AlertLevel.high.color,
                  onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                      .simulateDetection('anathurak', confidence: 0.96),
                ),
                _buildChip(
                  context,
                  label: '⚠️ "කරදරයක්" (92%)',
                  color: AlertLevel.medium.color,
                  onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                      .simulateDetection('karadarayak', confidence: 0.92),
                ),
                _buildChip(
                  context,
                  label: '🔥 Fire Alarm (96%)',
                  color: AlertLevel.high.color,
                  onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                      .simulateDetection('fire_alarm', confidence: 0.96),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchRow(String title, String tech) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tech,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
