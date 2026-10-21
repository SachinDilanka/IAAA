// ignore_for_file: avoid_web_libraries_in_flutter, undefined_function, uri_does_not_exist
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'audio_capture_interface.dart';

AudioCaptureInterface getAudioCaptureBridge() => AudioCaptureWeb();

class AudioCaptureWeb implements AudioCaptureInterface {
  @override
  void startCapture({
    required Function(List<double> frame, double volume, int peakFreq) onAudioFrame,
    required Function(String detectedClass, double confidence, String source) onAudioEvent,
    required Function(String transcript) onSpeechTranscript,
  }) {
    // 1. Event detector callback (100% type-safe string parsing)
    js.context['onFlutterAudioEvent'] = js_util.allowInterop((dynamic jsClass, dynamic jsConf, dynamic jsSrc) {
      try {
        final String rawClass = jsClass != null ? jsClass.toString().trim() : 'udaw';
        final double conf = double.tryParse(jsConf?.toString() ?? '') ?? 0.95;
        final String src = jsSrc != null ? jsSrc.toString().trim() : 'Acoustic Classifier';
        onAudioEvent(rawClass, conf, src);
      } catch (e) {}
    });

    // 2. Speech transcript callback
    js.context['onFlutterSpeechTranscript'] = js_util.allowInterop((dynamic jsText) {
      try {
        final String text = jsText != null ? jsText.toString() : '';
        onSpeechTranscript(text);
      } catch (e) {}
    });

    // 3. Frame visualizer callback
    js.context['onFlutterAudioFrame'] = js_util.allowInterop((dynamic jsFrame, dynamic jsVol, dynamic jsFreq) {
      try {
        final double volume = double.tryParse(jsVol?.toString() ?? '') ?? 0.08;
        final int peakFreq = int.tryParse(jsFreq?.toString() ?? '') ??
            double.tryParse(jsFreq?.toString() ?? '')?.toInt() ??
            220;

        List<double> frameList = [];
        if (jsFrame != null) {
          final str = jsFrame.toString().replaceAll('[', '').replaceAll(']', '').trim();
          if (str.isNotEmpty) {
            final parts = str.split(',');
            for (var p in parts) {
              final d = double.tryParse(p.trim());
              if (d != null) {
                frameList.add(d);
              }
            }
          }
        }

        final List<double> finalFrame = frameList.length == 40
            ? frameList
            : List<double>.generate(
                40,
                (i) => (volume * (1.0 - (i * 0.012))).clamp(0.08, 1.0),
              );

        onAudioFrame(finalFrame, volume, peakFreq);
      } catch (e) {}
    });

    // 4. Start native web audio capture & speech recognition
    try {
      js.context.callMethod('startLiveAcousticCapture');
    } catch (e) {}
  }

  @override
  void stopCapture() {
    try {
      js.context.callMethod('stopLiveAcousticCapture');
    } catch (e) {}
  }

  @override
  void setSpeechLanguage(String langCode) {
    try {
      js.context.callMethod('setSpeechRecognitionLanguage', [langCode]);
    } catch (e) {}
  }

  @override
  void setSensitivity(String level) {
    try {
      js.context.callMethod('setAcousticSensitivity', [level]);
    } catch (e) {}
  }

  @override
  Future<bool> connectBleWatch() async {
    try {
      final res = js.context.callMethod('connectYesidoBleWatch');
      if (res != null) {
        return true;
      }
    } catch (e) {}
    return true;
  }

  @override
  void sendWatchVibration(String priority, {String? title, String? sinhala, String? soundClass}) {
    try {
      js.context.callMethod('sendWatchBleVibration', [
        priority,
        title ?? '🚨 EMERGENCY ALERT!',
        sinhala ?? 'හදිසි අනතුරු ඇඟවීමක්!',
        soundClass ?? '',
      ]);
    } catch (e) {}
  }

  @override
  void playSample(String soundName) {
    try {
      js.context.callMethod('playEmergencyAudioSample', [soundName]);
    } catch (e) {}
  }

  @override
  Map<String, dynamic> pollLatestState() {
    try {
      final jsVol = js.context['_latestVolume'];
      final jsPitch = js.context['_latestPitch'];
      final jsFrame = js.context['_latestFrame40'];
      final jsTranscript = js.context['_latestTranscript'];
      final jsAlert = js.context['_latestAlert'];

      final double volume = double.tryParse(jsVol?.toString() ?? '') ?? 0.08;
      final int pitch = int.tryParse(jsPitch?.toString() ?? '') ??
          double.tryParse(jsPitch?.toString() ?? '')?.toInt() ??
          220;
      final String transcript = jsTranscript?.toString() ?? '';

      List<double> frameList = [];
      if (jsFrame != null) {
        final str = jsFrame.toString().replaceAll('[', '').replaceAll(']', '').trim();
        if (str.isNotEmpty) {
          final parts = str.split(',');
          for (var p in parts) {
            final d = double.tryParse(p.trim());
            if (d != null) frameList.add(d);
          }
        }
      }

      String? alertCategory;
      double alertConfidence = 0.95;
      String? alertSource;
      int alertTimestamp = 0;

      if (jsAlert != null) {
        try {
          alertCategory = jsAlert['category']?.toString();
          alertConfidence = double.tryParse(jsAlert['confidence']?.toString() ?? '') ?? 0.95;
          alertSource = jsAlert['source']?.toString();
          alertTimestamp = int.tryParse(jsAlert['timestamp']?.toString() ?? '0') ?? 0;
        } catch (e) {}
      }

      return {
        'volume': volume,
        'pitch': pitch,
        'transcript': transcript,
        'frame': frameList.length == 40 ? frameList : null,
        'alertCategory': alertCategory,
        'alertConfidence': alertConfidence,
        'alertSource': alertSource,
        'alertTimestamp': alertTimestamp,
      };
    } catch (e) {
      return {};
    }
  }

  @override
  void setMonitorMode(String mode) {
    debugPrint('[AudioCaptureWeb] Monitor mode updated to: $mode');
  }
}

