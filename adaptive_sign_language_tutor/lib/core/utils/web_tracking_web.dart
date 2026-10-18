// lib/core/utils/web_tracking_web.dart
import 'dart:html' as html;
import 'dart:js' as js;

class WebTrackingHelper {
  static html.EventListener? _listener;

  static void registerHandTrackingListener(Function(String) onData) {
    _listener = (html.Event event) {
      final customEvent = event as html.CustomEvent;
      final detail = customEvent.detail;
      if (detail != null) {
        onData(detail as String);
      }
    };
    html.window.addEventListener('onHandTracked', _listener!);
  }

  static void unregisterHandTrackingListener() {
    if (_listener != null) {
      html.window.removeEventListener('onHandTracked', _listener!);
      _listener = null;
    }
  }

  static void initMediaPipe() {
    if (js.context.hasProperty('initMediaPipeWeb')) {
      js.context.callMethod('initMediaPipeWeb', []);
    }
  }

  static void stopMediaPipe() {
    if (js.context.hasProperty('stopMediaPipeWeb')) {
      js.context.callMethod('stopMediaPipeWeb', []);
    }
  }
}
