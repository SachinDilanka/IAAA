import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
    final classifier = Provider.of<SoundClassifierService>(context);
    final watch = Provider.of<SmartwatchService>(context);
    final activeAlert = classifier.activeAlert;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Ultra Deep Slate
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827), // Slate 900
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hearing_rounded, color: Color(0xFF60A5FA), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SoundAlert AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFFF8FAFC),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Deaf & Hard-of-Hearing Emergency Assist',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              onTap: () => watch.connectWatchViaBle(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: watch.isDeviceConnected
                      ? const Color(0xFF059669).withValues(alpha: 0.25)
                      : const Color(0xFFD97706).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: watch.isDeviceConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      watch.isDeviceConnected ? Icons.watch_rounded : Icons.bluetooth_searching_rounded,
                      color: watch.isDeviceConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      watch.isDeviceConnected ? 'Watch ✓' : 'Connect',
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
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ACTIVE EMERGENCY ALERT BANNER (High-Contrast for Deaf Users)
              if (activeAlert != null) ...[
                _buildActiveAlertBanner(context, activeAlert, classifier),
                const SizedBox(height: 16),
              ],

              // 2. LIVE MIC TOGGLE & LANGUAGE SELECTOR CARD
              _buildMicControlCard(context, classifier),
              const SizedBox(height: 16),

              // 3. PROMINENT LIVE SPEECH TRANSCRIPT CARD
              _buildLiveTranscriptCard(context, classifier),
              const SizedBox(height: 16),

              // 4. LIVE 40-BAND SPECTROGRAM WAVE VISUALIZER
              _buildVisualizerCard(context, classifier),
              const SizedBox(height: 22),

              // 5. 8 SINHALA EMERGENCY KEYWORDS GRID
              const Text(
                'SINHALA VOICE KEYWORDS (8 TARGET CLASSES)',
                style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Deaf Assist Live Recognition: Speak words to trigger instant alert',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const SizedBox(height: 10),
              _buildSinhalaKeywordsGrid(context, classifier),
              const SizedBox(height: 22),

              // 6. 4 ENVIRONMENTAL EMERGENCY SOUNDS GRID
              const Text(
                'ENVIRONMENTAL SOUND CLASSIFICATION (4 CLASSES)',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Acoustic AI Neural Classifier for sirens, horns, crying & barking',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const SizedBox(height: 10),
              _buildEnvironmentalSoundsGrid(context, classifier),
              const SizedBox(height: 24),

              // 7. RECENT DETECTION HISTORY LOG
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT DETECTION HISTORY',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${classifier.lastEvent != null ? 1 : 0} Events',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildHistoryCard(context, classifier),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildActiveAlertBanner(
    BuildContext context,
    DetectionEvent event,
    SoundClassifierService classifier,
  ) {
    Color bannerBg;
    Color borderCol;
    IconData icon;

    switch (event.priority) {
      case AlertLevel.high:
        bannerBg = const Color(0xFF7F1D1D); // Red 900
        borderCol = const Color(0xFFEF4444);
        icon = Icons.warning_amber_rounded;
        break;
      case AlertLevel.medium:
        bannerBg = const Color(0xFF78350F); // Amber 900
        borderCol = const Color(0xFFF59E0B);
        icon = Icons.error_outline_rounded;
        break;
      case AlertLevel.low:
      default:
        bannerBg = const Color(0xFF064E3B); // Emerald 900
        borderCol = const Color(0xFF10B981);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: borderCol.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  event.titleSinhala,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                onPressed: () => classifier.dismissActiveAlert(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${event.titleEnglish} • Class: ${event.rawClass}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              event.avatarGuidanceSinhala,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: borderCol,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('DISMISS / ACKNOWLEDGE ALERT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () => classifier.dismissActiveAlert(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicControlCard(BuildContext context, SoundClassifierService classifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: classifier.isListening
                  ? const Color(0xFF059669).withValues(alpha: 0.25)
                  : const Color(0xFFDC2626).withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              classifier.isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: classifier.isListening ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      classifier.isListening ? 'MICROPHONE ACTIVE' : 'MICROPHONE PAUSED',
                      style: TextStyle(
                        color: classifier.isListening ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (classifier.isListening)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Continuous Voice & Ambient Monitoring',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: classifier.isListening,
            activeColor: const Color(0xFF10B981),
            onChanged: (val) {
              if (val) {
                classifier.startListening();
              } else {
                classifier.stopListening();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTranscriptCard(BuildContext context, SoundClassifierService classifier) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE SPEECH-TO-TEXT TRANSCRIPT',
                    style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'REALTIME VOICE',
                  style: TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            classifier.liveSpeechTranscript,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerCard(BuildContext context, SoundClassifierService classifier) {
    final frame = classifier.liveSpectrogramFrame;

    return Container(
      height: 110,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ACOUSTIC WAVEFORM (16,000 HZ)',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                'Vol: ${(classifier.currentRmsVolume * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: frame.map((val) {
                final normalized = val.clamp(0.05, 1.0);
                Color barColor;
                if (normalized > 0.6) {
                  barColor = const Color(0xFFEF4444);
                } else if (normalized > 0.3) {
                  barColor = const Color(0xFFF59E0B);
                } else {
                  barColor = const Color(0xFF10B981);
                }

                return Container(
                  width: 4,
                  height: 65 * normalized,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinhalaKeywordsGrid(BuildContext context, SoundClassifierService classifier) {
    final keywords = [
      {'sinhala': 'උදව් කරන්න!', 'singlish': 'udaw', 'code': 'udaw'},
      {'sinhala': 'බේරගන්න!', 'singlish': 'beeraganna', 'code': 'beeraganna'},
      {'sinhala': 'ගින්නක්!', 'singlish': 'ginnak', 'code': 'ginnak'},
      {'sinhala': 'අනතුරක්!', 'singlish': 'anathurak', 'code': 'anathurak'},
      {'sinhala': 'කරදරයක්!', 'singlish': 'karadarayak', 'code': 'karadarayak'},
      {'sinhala': 'බලාගෙන!', 'singlish': 'balagena', 'code': 'balagena'},
      {'sinhala': 'පරිස්සමින්!', 'singlish': 'parissamin', 'code': 'parissamin'},
      {'sinhala': 'එහාට වෙන්න!', 'singlish': 'ehata_wenna', 'code': 'ehata_wenna'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: keywords.length,
      itemBuilder: (context, index) {
        final kw = keywords[index];
        final sinhala = kw['sinhala']!;
        final singlish = kw['singlish']!;
        final code = kw['code']!;

        return InkWell(
          onTap: () => classifier.simulateDetection(code, confidence: 0.98, isLive: false),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sinhala,
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  singlish,
                  style: const TextStyle(
                    color: Color(0xFF60A5FA),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentalSoundsGrid(BuildContext context, SoundClassifierService classifier) {
    final envs = [
      {'title': '🚑 Siren (ගිලන් රථ)', 'code': 'ambulance_siren'},
      {'title': '🚗 Horn (වාහන)', 'code': 'vehicle_horn'},
      {'title': '👶 Baby Cry (ළදරු)', 'code': 'baby_crying'},
      {'title': '🐕 Dog Bark (බල්ලා)', 'code': 'dog_barking'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: envs.length,
      itemBuilder: (context, index) {
        final env = envs[index];
        final title = env['title']!;
        final code = env['code']!;

        return InkWell(
          onTap: () => classifier.simulateDetection(code, confidence: 0.98, isLive: false),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, SoundClassifierService classifier) {
    final event = classifier.lastEvent;

    if (event == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Text(
          'No sound events detected yet. Enable microphone or speak Sinhala emergency keywords.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      );
    }

    final timeStr = DateFormat('hh:mm:ss a').format(event.timestamp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.titleSinhala,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${event.titleEnglish} • $timeStr',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(event.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
