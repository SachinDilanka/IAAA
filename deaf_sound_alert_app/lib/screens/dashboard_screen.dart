import 'package:flutter/material.dart';
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
                        'Listening for 8 Sinhala Keywords & 6 Environmental Sounds offline',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),

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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (provider.isListening) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: provider.currentTranscript.isNotEmpty
                                ? const Color(0xFF00E5FF)
                                : Colors.cyanAccent.withValues(alpha: 0.35),
                            width: provider.currentTranscript.isNotEmpty ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            if (provider.currentTranscript.isNotEmpty)
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: provider.currentTranscript.isNotEmpty
                                    ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                                    : Colors.white10,
                              ),
                              child: Icon(
                                Icons.record_voice_over_rounded,
                                color: provider.currentTranscript.isNotEmpty
                                    ? const Color(0xFF00E5FF)
                                    : Colors.cyanAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF3B30),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'LIVE SPEECH',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Voice to Text',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    provider.currentTranscript.isNotEmpty
                                        ? provider.currentTranscript
                                        : 'Listening for speech… Say "udaw", "beeraganna", "ginnak", "anathurak", "karadarayak", "balagena", "ehata wenna", or "parissamin".',
                                    style: TextStyle(
                                      color: provider.currentTranscript.isNotEmpty ? Colors.white : Colors.white60,
                                      fontWeight: provider.currentTranscript.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (provider.sttStatus.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      provider.sttStatus,
                                      style: TextStyle(
                                        color: provider.sttStatus.contains('not available') ||
                                                provider.sttStatus.contains('error')
                                            ? Colors.orangeAccent
                                            : Colors.cyanAccent.withValues(alpha: 0.75),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
