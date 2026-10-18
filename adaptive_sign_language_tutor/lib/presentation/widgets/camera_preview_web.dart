import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

const _viewType = 'mediapipe-camera-preview';
bool _registered = false;

Widget buildCameraPreview() {
  if (!_registered) {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final video = html.document.getElementById('mediapipe-video')
                as html.VideoElement? ??
            (html.VideoElement()
              ..id = 'mediapipe-video'
              ..autoplay = true
              ..muted = true
              ..setAttribute('playsinline', ''));
        video
          ..style.display = 'block'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'fill'
          ..style.transform = 'scaleX(-1)';
        return video;
      },
    );
    _registered = true;
  }

  return const HtmlElementView(viewType: _viewType);
}
