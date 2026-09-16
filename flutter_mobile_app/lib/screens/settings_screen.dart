import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../wearable/smartwatch_service.dart';
import '../ai/sound_classifier_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _confidenceThreshold = 0.70;
  bool _hapticEnabled = true;
  bool _sinhalaGuidanceEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'System & Wearable Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Yesido IO39 Wearable Settings Card
          const Text(
            'WEARABLE & ALERT ROUTING',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Consumer<SmartwatchService>(
            builder: (context, watch, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: watch.isDeviceConnected
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          watch.isDeviceConnected ? Icons.watch_rounded : Icons.phone_android_rounded,
                          color: watch.isDeviceConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                watch.isDeviceConnected ? watch.deviceName : "Standalone Smartphone Mode",
                                style: const TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                watch.connectionStatusText,
                                style: TextStyle(
                                  color: watch.isDeviceConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: watch.isDeviceConnected,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            watch.setConnection(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Smartwatch Pathway',
                                style: TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                watch.connectMode == SmartwatchConnectMode.notificationMirror
                                    ? 'Level 1: Android Notification Shade Mirroring'
                                    : 'Level 2: Direct BLE GATT Commands',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: watch.connectMode == SmartwatchConnectMode.directBLE,
                          activeThumbColor: const Color(0xFF2563EB),
                          onChanged: watch.isDeviceConnected
                              ? (val) {
                                  watch.toggleMode();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // AI Sensitivity Settings Card
          const Text(
            'AI MODEL & LISTENING CONFIGURATION',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Minimum Confidence Threshold',
                      style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(_confidenceThreshold * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _confidenceThreshold,
                  min: 0.50,
                  max: 0.95,
                  divisions: 9,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) {
                    setState(() {
                      _confidenceThreshold = val;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      Consumer<SoundClassifierService>(
                        builder: (context, classifier, child) {
                          return SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto-Detect Sounds while Listening', style: TextStyle(color: Color(0xFFF8FAFC))),
                            subtitle: const Text('Simulate real-time emergency sound detections', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            value: classifier.autoDetectWhileListening,
                            activeThumbColor: const Color(0xFF2563EB),
                            onChanged: (val) => classifier.setAutoDetectWhileListening(val),
                          );
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Phone Haptic Urgency Language', style: TextStyle(color: Color(0xFFF8FAFC))),
                        subtitle: const Text('Vibrate phone with priority patterns', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        value: _hapticEnabled,
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _hapticEnabled = val),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Visual Sinhala Guidance Action Text', style: TextStyle(color: Color(0xFFF8FAFC))),
                        subtitle: const Text('Display Sinhala emergency instruction text on screen', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        value: _sinhalaGuidanceEnabled,
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: (val) => setState(() => _sinhalaGuidanceEnabled = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
