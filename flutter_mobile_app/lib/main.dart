import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ai/sound_classifier_service.dart';
import 'avatar/avatar_controller.dart';
import 'wearable/smartwatch_service.dart';
import 'storage/history_database.dart';
import 'models/detection_event.dart';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'screens/home_screen.dart';
import 'screens/detection_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final historyDb = HistoryDatabase();
  await historyDb.loadHistory();

  final avatarController = AvatarController();
  final soundClassifierService = SoundClassifierService();
  soundClassifierService.attachAvatarController(avatarController);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: avatarController),
        ChangeNotifierProvider.value(value: soundClassifierService),
        ChangeNotifierProvider.value(value: SmartwatchService()),
        ChangeNotifierProvider.value(value: historyDb),
      ],
      child: const SoundAlertApp(),
    ),
  );
}

class SoundAlertApp extends StatelessWidget {
  const SoundAlertApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcousticAware DEAF AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Natural Deep Slate 900
        primaryColor: const Color(0xFF2563EB), // Natural Cobalt Blue
        cardColor: const Color(0xFF1E293B), // Natural Slate 800
        dividerColor: const Color(0xFF334155), // Natural Slate 700
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF059669),
          surface: Color(0xFF1E293B),
          error: Color(0xFFDC2626),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const NavigationHostScreen(),
    );
  }
}

/// Mobile Embedded Web Container: Runs the exact Web Audio & Neural AI Engine natively on Android
class MobileWebContainerScreen extends StatefulWidget {
  const MobileWebContainerScreen({Key? key}) : super(key: key);

  @override
  State<MobileWebContainerScreen> createState() => _MobileWebContainerScreenState();
}

class _MobileWebContainerScreenState extends State<MobileWebContainerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initMobileEngine();
  }

  Future<void> _initMobileEngine() async {
    try {
      await [
        Permission.microphone,
        Permission.notification,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0B0E14))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              debugPrint('[MobileWebContainer] Error: ${error.description}');
            },
          ),
        );

      if (_controller.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(false);
        (_controller.platform as AndroidWebViewController).setOnPlatformPermissionRequest(
          (request) {
            request.grant();
          },
        );
      }

      await _controller.loadFlutterAsset('assets/web_app/index.html');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return const NavigationHostScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    SizedBox(height: 16),
                    Text(
                      'Loading AcousticAware AI Engine...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NavigationHostScreen extends StatefulWidget {
  const NavigationHostScreen({Key? key}) : super(key: key);

  @override
  State<NavigationHostScreen> createState() => _NavigationHostScreenState();
}

class _NavigationHostScreenState extends State<NavigationHostScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    DetectionScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          
          // UNMISSABLE GLOBAL FLOATING IN-APP EMERGENCY ALERT BANNER (OVERLAY OVER ALL TABS)
          Consumer2<SoundClassifierService, SmartwatchService>(
            builder: (context, classifier, watch, child) {
              final activeAlert = classifier.activeAlert;
              if (activeAlert == null) return const SizedBox.shrink();

              return Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.transparent,
                    child: _buildGlobalAlertFloatingBanner(context, activeAlert, classifier, watch),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF2563EB).withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF3B82F6)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_rounded),
            selectedIcon: Icon(Icons.graphic_eq_rounded, color: Color(0xFF3B82F6)),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF3B82F6)),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF3B82F6)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalAlertFloatingBanner(
    BuildContext context,
    DetectionEvent event,
    SoundClassifierService classifier,
    SmartwatchService watch,
  ) {
    final color = event.priority.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.black, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '🚨 ${event.priority.name} EMERGENCY NOTIFICATION',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () => classifier.dismissActiveAlert(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Alert Content
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.priority.icon, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.titleEnglish,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.titleSinhala,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(event.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Guidance Message
          Text(
            event.avatarGuidanceEnglish,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),

          // Delivery Route Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(
                  watch.isDeviceConnected ? Icons.watch_rounded : Icons.phone_android_rounded,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    watch.isDeviceConnected
                        ? '⌚ Smartwatch Sync: Vibration & Notification dispatched to Yesido IO39'
                        : '📱 In-App Screen Alert Mode Active (Phone Haptic Vibrations Sent)',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
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
