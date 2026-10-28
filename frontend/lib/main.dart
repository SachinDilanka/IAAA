import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'controllers/venue_controller.dart';
import 'providers/venue_provider.dart';
import 'services/location_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final locationService = LocationService();
  final venueController = VenueController(
    locationService: locationService,
  );
  venueController.initLocation();

  runApp(CommAssistApp(venueController: venueController));
}

class CommAssistApp extends StatefulWidget {
  final VenueController? venueController;

  const CommAssistApp({super.key, this.venueController});

  @override
  State<CommAssistApp> createState() => _CommAssistAppState();
}

class _CommAssistAppState extends State<CommAssistApp> {
  late final VenueController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.venueController != null) {
      _controller = widget.venueController!;
    } else {
      _controller = VenueController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VenueProvider(
      controller: _controller,
      child: MaterialApp(
        title: 'CommAssist Sri Lanka',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF10B981),
            brightness: Brightness.light,
          ),
          fontFamily: 'Roboto',
        ),
        home: HomeScreen(controller: _controller),
      ),
    );
  }
}
