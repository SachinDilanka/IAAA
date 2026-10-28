import 'package:flutter/material.dart';
import '../controllers/venue_controller.dart';

/// App-level inherited notifier providing single source of truth
/// for venue, category, and GPS state.
class VenueProvider extends InheritedNotifier<VenueController> {
  const VenueProvider({
    super.key,
    required VenueController controller,
    required super.child,
  }) : super(notifier: controller);

  static VenueController of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<VenueProvider>();
    assert(provider != null, 'No VenueProvider found in context');
    return provider!.notifier!;
  }

  static VenueController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VenueProvider>()?.notifier;
  }
}
