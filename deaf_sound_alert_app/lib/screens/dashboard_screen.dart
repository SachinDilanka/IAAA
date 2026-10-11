import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/detected_sound.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/alert_banner.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Smartwatch Connection Status Bar
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: provider.isSmartwatchConnected
                      ? const Color(0xFF1B382B)
                      : const Color(0xFF2C2417),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: provider.isSmartwatchConnected
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF9500),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.watch_rounded,
                      color: provider.isSmartwatchConnected
                          ? const Color(0xFF34C759)
                          : const Color(0xFFFF9500),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.isSmartwatchConnected
                                ? 'Yesido IO 39 Watch Connected'
                                : 'Smartwatch Disconnected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            provider.isSmartwatchConnected
                                ? 'Alerts syncing via Bluetooth & Notifications'
                                : 'Tap Smartwatch tab to pair device',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: provider.isSmartwatchConnected
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF9500),
                      ),
                    ),
                  ],
                ),
              ),

              if (provider.isListening) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: provider.currentTranscript.isNotEmpty
                          ? const Color(0xFF00E5FF)
                          : Colors.cyanAccent.withValues(alpha: 0.4),
                      width: provider.currentTranscript.isNotEmpty ? 2 : 1,
                    ),
                    boxShadow: provider.currentTranscript.isNotEmpty
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded, color: Colors.cyanAccent, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          provider.currentTranscript.isNotEmpty
                              ? 'Live Speech: "${provider.currentTranscript}"'
                              : 'Speak Sinhala keywords (Udaw, Ginnak...) or play sounds into mic',
                          style: TextStyle(
                            color: provider.currentTranscript.isNotEmpty ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: provider.currentTranscript.isNotEmpty ? 15 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (provider.lastDetectedSound != null)
                AlertBanner(
                  sound: provider.lastDetectedSound!,
                  onDismiss: provider.dismissLastSound,
                )
              else
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.hearing_rounded, size: 48, color: Colors.cyanAccent),
                      SizedBox(height: 12),
                      Text(
                        'Ready to Detect Sounds',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Works offline: say Sinhala keywords (උදව්, ගින්නක්...) or play alert sounds',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              // Detection status line. Kept visible on purpose: it is the
              // only way to tell whether the mic is reaching the detector,
              // whether a rate is locked, and what the model is actually
              // hearing. It is compact and user-readable.
              _DetectionStatus(state: provider.detectorDiagnostics),

              // Mic Waveform & Main Listening Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    WaveformVisualizer(
                      samples: provider.currentWaveform,
                      isListening: provider.isListening,
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: provider.toggleListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isListening
                              ? const Color(0xFFFF3B30)
                              : const Color(0xFF007AFF),
                          boxShadow: [
                            BoxShadow(
                              color: (provider.isListening
                                      ? const Color(0xFFFF3B30)
                                      : const Color(0xFF007AFF))
                                  .withOpacity(0.5),
                              blurRadius: 25,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              provider.isListening ? Icons.mic : Icons.mic_off,
                              size: 44,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              provider.isListening ? 'STOP' : 'START',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Test Simulation Section (14 Sounds)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TEST SOUND TRIGGER (SIMULATOR)',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap any sound to test visual banner, phone vibration & Yesido IO 39 watch alert:',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.soundConfigs.map((config) {
                        return ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: config.priority.color,
                            radius: 6,
                          ),
                          label: Text(
                            config.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: Colors.white10,
                          side: BorderSide(color: config.priority.color.withOpacity(0.5)),
                          onPressed: () => provider.simulateSound(config.key),
                        );
                      }).toList(),
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

/// One-line status of the detection chain: build id, mode, mic source,
/// whether real sound is present, and what the model currently hears. Each
/// field isolates a single failure point, so a problem on a real device can
/// be identified from a screenshot.
class _DetectionStatus extends StatelessWidget {
  final String state;
  const _DetectionStatus({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        state,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.lightGreenAccent,
          fontFamily: 'monospace',
          fontSize: 8,
          height: 1.25,
        ),
      ),
    );
  }
}
