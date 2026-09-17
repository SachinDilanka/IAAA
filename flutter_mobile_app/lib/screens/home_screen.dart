import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ai/sound_classifier_service.dart';
import '../wearable/smartwatch_service.dart';
import '../models/alert_level.dart';
import '../models/detection_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final classifier = Provider.of<SoundClassifierService>(context, listen: false);
      if (!classifier.isListening) {
        classifier.startListening();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hearing_rounded, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AcousticAware DEAF AI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                Text(
                  'Offline Sound & Sinhala Voice Detection',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Watch BLE Connect & Vibration Test Actions
          Consumer<SmartwatchService>(
            builder: (context, watch, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        watch.testWatchVibration(priority: AlertLevel.high);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.vibration_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "⚡ Strong Emergency Vibration Sent to Yesido IO39!",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vibration_rounded, color: Color(0xFFEF4444), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              watch.isTestingVibration ? "Vibrating..." : "Test Watch",
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        watch.connectWatchViaBle();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: watch.isDeviceConnected
                              ? const Color(0xFF059669).withValues(alpha: 0.18)
                              : const Color(0xFFD97706).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: watch.isDeviceConnected
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              watch.isDeviceConnected ? Icons.watch_rounded : Icons.bluetooth_searching_rounded,
                              color: watch.isDeviceConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              watch.isDeviceConnected ? 'Yesido IO39 ✓' : 'Connect Watch',
                              style: TextStyle(
                                color: watch.isDeviceConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final classifier = Provider.of<SoundClassifierService>(context, listen: false);
          if (!classifier.isListening) {
            classifier.startListening();
          }
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. LIVE MICROPHONE ACOUSTIC & SPEECH RECOGNITION MONITOR
                _buildLiveMicrophoneAcousticCard(context),
                const SizedBox(height: 16),

                // 2. SMARTWATCH VIBRATION PATTERNS
                _buildVibrationPatternCard(context),
                const SizedBox(height: 20),

                // 3. LAST DETECTED SOUND
                const Text(
                  'LAST DETECTED SOUND',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Consumer2<SoundClassifierService, SmartwatchService>(
                  builder: (context, classifier, watch, child) {
                    final event = classifier.lastEvent;
                    if (event == null) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Standby: Speak Sinhala keywords (e.g. "උදව්", "ගින්නක්", "අනතුරක්") or trigger an emergency test sound below.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141E2D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: event.priority.color.withValues(alpha: 0.55), width: 1.8),
                        boxShadow: [
                          BoxShadow(color: event.priority.color.withValues(alpha: 0.15), blurRadius: 14, spreadRadius: 1),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            // Emoji icon with glow
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: event.priority.color.withValues(alpha: 0.12),
                                border: Border.all(color: event.priority.color.withValues(alpha: 0.35)),
                                boxShadow: [
                                  BoxShadow(color: event.priority.color.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: 1),
                                ],
                              ),
                              child: Center(child: Text(_soundEmoji(event.rawClass), style: const TextStyle(fontSize: 26))),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.titleSinhala,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      shadows: [Shadow(color: event.priority.color.withValues(alpha: 0.5), blurRadius: 8)],
                                      fontFamilyFallback: const ['Noto Sans Sinhala', 'Arial', 'sans-serif'],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.titleEnglish,
                                    style: TextStyle(color: event.priority.color, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: const Color(0xFF64748B), size: 11),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${event.timestamp.hour.toString().padLeft(2,'0')}:${event.timestamp.minute.toString().padLeft(2,'0')}:${event.timestamp.second.toString().padLeft(2,'0')}',
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(
                                        watch.isDeviceConnected ? Icons.watch_rounded : Icons.vibration_rounded,
                                        size: 11,
                                        color: const Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        watch.isDeviceConnected ? 'Watch Notified' : 'Haptic Sent',
                                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Confidence badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: event.priority.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: event.priority.color.withValues(alpha: 0.45)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${(event.confidence * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(color: event.priority.color, fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  Text('conf', style: TextStyle(color: event.priority.color.withValues(alpha: 0.7), fontSize: 9)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 5. CORE SINHALA EMERGENCY KEYWORDS
                const Text(
                  '🔴 CORE SINHALA EMERGENCY KEYWORDS (RESEARCH DATASET)',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap any keyword to instantly test recognition, audio synthesis, and watch vibration:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildTestChip(
                      context,
                      label: '🆘 udaw ("උදව්")',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('udaw', confidence: 0.99),
                    ),
                    _buildTestChip(
                      context,
                      label: '🆘 beeraganna ("බේරගන්න")',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('beeraganna', confidence: 0.98),
                    ),
                    _buildTestChip(
                      context,
                      label: '🔥 ginnak ("ගින්නක්")',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('ginnak', confidence: 0.98),
                    ),
                    _buildTestChip(
                      context,
                      label: '⚠️ anathurak ("අනතුරක්")',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('anathurak', confidence: 0.99),
                    ),
                    _buildTestChip(
                      context,
                      label: '🛑 nawaththanna ("නවත්තන්න")',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('nawaththanna', confidence: 0.97),
                    ),
                    _buildTestChip(
                      context,
                      label: '⚠️ karadarayak ("කරදරයක්")',
                      color: AlertLevel.medium.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('karadarayak', confidence: 0.96),
                    ),
                    _buildTestChip(
                      context,
                      label: '👁️ balagena ("බලාගෙන")',
                      color: AlertLevel.medium.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('balagena', confidence: 0.97),
                    ),
                    _buildTestChip(
                      context,
                      label: '⚠️ parissamin ("පරිස්සමින්")',
                      color: AlertLevel.medium.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('parissamin', confidence: 0.97),
                    ),
                    _buildTestChip(
                      context,
                      label: '🏃 ehata_wenna ("එහාට වෙන්න")',
                      color: AlertLevel.medium.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('ehata_wenna', confidence: 0.97),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. ENVIRONMENTAL ACOUSTIC SOUNDS
                const Text(
                  '🚨 ENVIRONMENTAL ACOUSTIC SOUNDS (RESEARCH DATASET)',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap any sound to simulate live microphone acoustic frequency matching:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildTestChip(
                      context,
                      label: '🚑 Ambulance Siren',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('ambulance', confidence: 0.98),
                    ),
                    _buildTestChip(
                      context,
                      label: '🔥 Fire Alarm / Firetruck',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('firetruck', confidence: 0.98),
                    ),
                    _buildTestChip(
                      context,
                      label: '🚗 Vehicle Horn',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('vehicle horns', confidence: 0.97),
                    ),
                    _buildTestChip(
                      context,
                      label: '😱 Distress Screaming',
                      color: AlertLevel.high.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('screaming', confidence: 0.96),
                    ),
                    _buildTestChip(
                      context,
                      label: '👶 Baby Crying',
                      color: AlertLevel.medium.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('baby crying', confidence: 0.95),
                    ),
                    _buildTestChip(
                      context,
                      label: '🐕 Dog Barking',
                      color: AlertLevel.low.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('dog_bark', confidence: 0.94),
                    ),
                    _buildTestChip(
                      context,
                      label: '🛣️ Road Noise',
                      color: AlertLevel.low.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('road', confidence: 0.92),
                    ),
                    _buildTestChip(
                      context,
                      label: '🚦 Traffic Movement',
                      color: AlertLevel.low.color,
                      onTap: () => Provider.of<SoundClassifierService>(context, listen: false)
                          .simulateDetection('traffic', confidence: 0.92),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  /// Live Microphone & Speech Recognition Card with Language Toggle & Dancing Spectrum Visualizer
  Widget _buildLiveMicrophoneAcousticCard(BuildContext context) {
    return Consumer<SoundClassifierService>(
      builder: (context, classifier, child) {
        final isListening = classifier.isListening;
        final vol = classifier.currentRmsVolume;
        final pitch = classifier.currentPitchHz;
        final transcript = classifier.liveSpeechTranscript;
        final frame = classifier.liveSpectrogramFrame;
        final currentLang = classifier.speechLanguage;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isListening ? const Color(0xFF2563EB) : const Color(0xFF334155),
              width: 1.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Master Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isListening
                              ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                              : const Color(0xFF334155).withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                          color: isListening ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isListening ? "LIVE MICROPHONE ACTIVE" : "MICROPHONE STANDBY",
                            style: TextStyle(
                              color: isListening ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            isListening
                                ? "Real-time acoustic AI & keyword listener"
                                : "Tap Start to activate live microphone monitor",
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (isListening) {
                        classifier.stopListening();
                      } else {
                        classifier.startListening();
                      }
                    },
                    icon: Icon(
                      isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isListening ? "Stop Mic" : "Start Mic",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isListening ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Speech Recognition Language Switcher Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.language_rounded, color: Color(0xFF94A3B8), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      "Voice Language:",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    // Sinhala Option
                    InkWell(
                      onTap: () => classifier.setSpeechLanguage('si-LK'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentLang == 'si-LK'
                              ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: currentLang == 'si-LK' ? const Color(0xFF3B82F6) : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          "සිංහල (si-LK)",
                          style: TextStyle(
                            color: currentLang == 'si-LK' ? const Color(0xFF60A5FA) : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // English / Phonetic Option
                    InkWell(
                      onTap: () => classifier.setSpeechLanguage('en-US'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentLang == 'en-US'
                              ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: currentLang == 'en-US' ? const Color(0xFF3B82F6) : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          "English / Phonetic",
                          style: TextStyle(
                            color: currentLang == 'en-US' ? const Color(0xFF60A5FA) : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Microphone Sensitivity Selector (Normal / High / Ultra)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: Color(0xFF94A3B8), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      "Mic Sensitivity:",
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    // Ultra Option
                    InkWell(
                      onTap: () => classifier.setSensitivity('ultra'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: classifier.sensitivity == 'ultra'
                              ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: classifier.sensitivity == 'ultra' ? const Color(0xFFEF4444) : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          "Ultra (Whisper)",
                          style: TextStyle(
                            color: classifier.sensitivity == 'ultra' ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // High Option
                    InkWell(
                      onTap: () => classifier.setSensitivity('high'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: classifier.sensitivity == 'high'
                              ? const Color(0xFF059669).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: classifier.sensitivity == 'high' ? const Color(0xFF10B981) : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          "High (Normal)",
                          style: TextStyle(
                            color: classifier.sensitivity == 'high' ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Balanced Option
                    InkWell(
                      onTap: () => classifier.setSensitivity('balanced'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: classifier.sensitivity == 'balanced'
                              ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: classifier.sensitivity == 'balanced' ? const Color(0xFF3B82F6) : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          "Balanced",
                          style: TextStyle(
                            color: classifier.sensitivity == 'balanced' ? const Color(0xFF60A5FA) : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic 40-Band Audio Visualizer (Tall, undulating bars with gradient colors)
              Container(
                height: 96,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: frame.map((val) {
                    final normalized = val.clamp(0.08, 1.0);
                    // Lively minimum height of 14px so bars are always tall, dancing, and visible
                    final barHeight = (14.0 + (68.0 * normalized)).clamp(14.0, 80.0);

                    Color barColor;
                    if (normalized > 0.60) {
                      barColor = const Color(0xFFDC2626); // Emergency Crimson
                    } else if (normalized > 0.28) {
                      barColor = const Color(0xFFD97706); // Warning Amber
                    } else {
                      barColor = const Color(0xFF059669); // Emerald Green
                    }

                    return Flexible(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Live Volume Meter & Pitch Readout
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Mic Audio Level", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            Text(
                              "${(vol * 100).toStringAsFixed(0)}% • ${(20.0 + vol * 60.0).toStringAsFixed(0)} dB",
                              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: vol.clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFF0F172A),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              vol > 0.60
                                  ? const Color(0xFFDC2626)
                                  : vol > 0.28
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF10B981),
                            ),
                            minHeight: 7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "$pitch Hz",
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live Voice Speech Transcript Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isListening ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isListening ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "LIVE VOICE TRANSCRIPT:",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      transcript,
                      style: const TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamilyFallback: ['Noto Sans Sinhala', 'Arial', 'sans-serif'],
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

  Widget _buildVibrationPatternCard(BuildContext context) {
    return Consumer<SmartwatchService>(
      builder: (context, watch, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.vibration_rounded, color: Color(0xFF3B82F6), size: 18),
                      SizedBox(width: 8),
                      Text(
                        "YESIDO IO39 TACTILE VIBRATION PATTERNS",
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => watch.testWatchVibration(priority: AlertLevel.high),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Test Strong Vibe",
                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildVibrationRow(
                "🔴 High Urgency",
                "Continuous Pulse (1500ms x 4)",
                AlertLevel.high.color,
                onTap: () => watch.testWatchVibration(priority: AlertLevel.high),
              ),
              const Divider(color: Color(0xFF334155), height: 12),
              _buildVibrationRow(
                "🟡 Medium Urgency",
                "Double Warning Pulse (600ms x 2)",
                AlertLevel.medium.color,
                onTap: () => watch.testWatchVibration(priority: AlertLevel.medium),
              ),
              const Divider(color: Color(0xFF334155), height: 12),
              _buildVibrationRow(
                "🟢 Low Urgency",
                "Single Gentle Tap (250ms)",
                AlertLevel.low.color,
                onTap: () => watch.testWatchVibration(priority: AlertLevel.low),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVibrationRow(String priority, String pattern, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              priority,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Row(
              children: [
                Text(
                  pattern,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(width: 6),
                Icon(Icons.play_circle_fill_rounded, color: color, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Sound category → emoji mapping ─────────────────────────────────────────
  String _soundEmoji(String rawClass) {
    const map = {
      'ambulance': '🚑', 'ambulance_siren': '🚑',
      'firetruck': '🔥', 'fire_alarm': '🔥', 'ginnak': '🔥',
      'vehicle horns': '📯', 'vehicle_horn': '📯',
      'baby crying': '👶', 'baby_crying': '👶',
      'dog_bark': '🐕', 'dog_barking': '🐕',
      'road': '🛣️', 'traffic': '🚦',
      'screaming': '😱',
      'udaw': '🆘', 'beeraganna': '🆘',
      'anathurak': '⚠️', 'karadarayak': '⚠️',
      'balagena': '👁️', 'parissamin': '🛡️',
      'ehata_wenna': '🏃', 'nawaththanna': '🛑',
    };
    return map[rawClass] ?? '🔔';
  }



              child: Column(
                children: [
                  // Emoji + Glow Halo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 5),
                        BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 60, spreadRadius: 15),
                      ],
                      border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sinhala title — BIG & BOLD
                  Text(
                    event.titleSinhala,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                      height: 1.2,
                      shadows: [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 12)],
                      fontFamilyFallback: const ['Noto Sans Sinhala', 'Arial', 'sans-serif'],
                    ),
                  ),
                  const SizedBox(height: 5),

                  // English title
                  Text(
                    event.titleEnglish,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Confidence bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'AI Confidence',
                            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: color.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '${conf.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          children: [
                            // Background track
                            Container(height: 10, color: const Color(0xFF1E293B)),
                            // Glowing fill
                            FractionallySizedBox(
                              widthFactor: (event.confidence).clamp(0.0, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      color.withValues(alpha: 0.6),
                                      color,
                                    ],
                                  ),
                                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Guidance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.avatarGuidanceSinhala,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFamilyFallback: const ['Noto Sans Sinhala', 'Arial', 'sans-serif'],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          event.avatarGuidanceEnglish,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Watch / haptic status strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: watch.isDeviceConnected
                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                            : color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          watch.isDeviceConnected ? Icons.watch_rounded : Icons.vibration_rounded,
                          color: watch.isDeviceConnected ? const Color(0xFF10B981) : color,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: watch.isDeviceConnected ? const Color(0xFF10B981) : color,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            watch.isDeviceConnected
                                ? 'Smartwatch Sync: Vibration & Notification dispatched to Yesido IO39'
                                : 'Phone Haptic: Strong emergency vibration active',
                            style: TextStyle(
                              color: watch.isDeviceConnected
                                  ? const Color(0xFF10B981)
                                  : color.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Time
                        Text(
                          '${event.timestamp.hour.toString().padLeft(2,'0')}:${event.timestamp.minute.toString().padLeft(2,'0')}:${event.timestamp.second.toString().padLeft(2,'0')}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestChip(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        onTap();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.notifications_active, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚡ ALERT DETECTED: $label (Vibration & Watch Notification Sent)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: color,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamilyFallback: const ['Noto Sans Sinhala', 'Arial', 'sans-serif'],
          ),
        ),
      ),
    );
  }
}
