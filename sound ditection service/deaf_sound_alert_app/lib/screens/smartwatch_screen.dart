import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SmartwatchScreen extends StatefulWidget {
  const SmartwatchScreen({super.key});

  @override
  State<SmartwatchScreen> createState() => _SmartwatchScreenState();
}

class _SmartwatchScreenState extends State<SmartwatchScreen> {
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Watch Connection Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: provider.isSmartwatchConnected
                        ? [const Color(0xFF1B382B), const Color(0xFF0F261C)]
                        : [const Color(0xFF2C1B1B), const Color(0xFF1F1212)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: provider.isSmartwatchConnected
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.watch_rounded,
                      size: 64,
                      color: provider.isSmartwatchConnected
                          ? const Color(0xFF34C759)
                          : const Color(0xFFFF3B30),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.connectedWatchName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider.isSmartwatchConnected
                          ? 'STATUS: ACTIVE BLE & NOTIFICATION SYNC'
                          : 'STATUS: DISCONNECTED',
                      style: TextStyle(
                        color: provider.isSmartwatchConnected
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isScanning
                          ? null
                          : () async {
                              setState(() => _isScanning = true);
                              if (provider.isSmartwatchConnected) {
                                await provider.disconnectSmartwatch();
                              } else {
                                await provider.pairSmartwatch();
                              }
                              setState(() => _isScanning = false);
                            },
                      icon: Icon(_isScanning
                          ? Icons.sync
                          : (provider.isSmartwatchConnected
                              ? Icons.bluetooth_disabled
                              : Icons.bluetooth_searching)),
                      label: Text(_isScanning
                          ? 'Scanning Yesido IO 39...'
                          : (provider.isSmartwatchConnected
                              ? 'Disconnect Watch'
                              : 'Connect Yesido IO 39')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: provider.isSmartwatchConnected
                            ? Colors.redAccent
                            : const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Notification Sync Information
              const Text(
                'YESIDO IO 39 SMARTWATCH INTEGRATION',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.vibration, color: Colors.amberAccent),
                      title: Text('Vibration Motor Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Yesido IO 39 watch motor vibrates immediately on High/Medium sound detection.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ),
                    Divider(color: Colors.white10),
                    ListTile(
                      leading: Icon(Icons.notifications_active, color: Colors.greenAccent),
                      title: Text('Visual Watch Display Banner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Pushes notification title & sound priority level to the watch screen.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Test Notification Trigger
              OutlinedButton.icon(
                onPressed: () => provider.simulateSound('sinhala_udaw_'),
                icon: const Icon(Icons.send_rounded, color: Colors.cyanAccent),
                label: const Text(
                  'Send Test Notification to Yesido IO 39',
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.cyanAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
