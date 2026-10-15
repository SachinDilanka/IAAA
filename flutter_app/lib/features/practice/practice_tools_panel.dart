import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/emotion_result.dart';
import '../../core/models/exercise.dart';
import '../../core/services/speech_service.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../l10n/l10n.dart';
import '../app/app_controller.dart';

class PracticeToolsPanel extends StatefulWidget {
  const PracticeToolsPanel({
    super.key,
    required this.exercise,
    this.onEmotionChanged,
  });

  final Exercise exercise;
  final ValueChanged<String>? onEmotionChanged;

  @override
  State<PracticeToolsPanel> createState() => _PracticeToolsPanelState();
}

class _PracticeToolsPanelState extends State<PracticeToolsPanel> {
  CameraController? _camera;
  bool _listening = false;
  bool _analyzing = false;
  String _transcript = '';
  EmotionResult? _emotion;
  SpeechService? _speech;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speech = context.read<AppController>().speech;
  }

  @override
  void didUpdateWidget(covariant PracticeToolsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      _speech?.stopListening();
      setState(() {
        _listening = false;
        _transcript = '';
        _emotion = null;
      });
      widget.onEmotionChanged?.call('happy');
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _speech?.stopListening();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    final speech = _speech ?? context.read<AppController>().speech;
    if (_listening) {
      await speech.stopListening();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await speech.startListening((words, isFinal) {
      if (!mounted) return;
      setState(() {
        _transcript = words;
        if (isFinal) _listening = false;
      });
    });
    if (!mounted) return;
    if (!available) {
      await showConfirmationDialog(
        context,
        title: context.l10n.errorTitle,
        message: context.l10n.speechUnavailable,
        kind: ConfirmationKind.error,
      );
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera found');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      if (mounted) {
        await showConfirmationDialog(
          context,
          title: context.l10n.errorTitle,
          message: context.l10n.cameraPermissionError,
          kind: ConfirmationKind.error,
        );
      }
    }
  }

  Future<void> _stopCamera() async {
    final camera = _camera;
    setState(() => _camera = null);
    await camera?.dispose();
  }

  Future<void> _analyze() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _analyzing) return;
    final api = context.read<AppController>().api;
    setState(() => _analyzing = true);
    try {
      final image = await camera.takePicture();
      final result = await api.analyzeEmotion(await image.readAsBytes());
      if (!mounted) return;
      setState(() => _emotion = result);
      widget.onEmotionChanged?.call(result.emotion);
    } catch (_) {
      if (mounted) {
        await showConfirmationDialog(
          context,
          title: context.l10n.errorTitle,
          message: context.l10n.loadError,
          kind: ConfirmationKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  bool get _matches {
    final target = widget.exercise.sinhalaText
        .replaceAll(RegExp(r'[\s.,!?।]'), '')
        .toLowerCase();
    final speech = _transcript
        .replaceAll(RegExp(r'[\s.,!?।]'), '')
        .toLowerCase();
    return speech.isNotEmpty && speech.contains(target);
  }

  String _emotionLabel(BuildContext context, String emotion) =>
      switch (emotion) {
        'happy' => context.l10n.happy,
        'surprise' => context.l10n.surprise,
        'sad' => context.l10n.sad,
        'fear' => context.l10n.fear,
        'angry' => context.l10n.angry,
        'disgust' => context.l10n.disgust,
        _ => context.l10n.neutral,
      };

  String _emotionFeedback(BuildContext context, String emotion) =>
      switch (emotion) {
        'happy' => context.l10n.emotionHappyFeedback,
        'surprise' => context.l10n.emotionSurpriseFeedback,
        'neutral' => context.l10n.emotionNeutralFeedback,
        _ => context.l10n.emotionSupportFeedback,
      };

  @override
  Widget build(BuildContext context) {
    final ready = _camera?.value.isInitialized ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(
              icon: Icons.videocam_rounded,
              title: context.l10n.cameraTitle,
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ready
                    ? CameraPreview(_camera!)
                    : ColoredBox(
                        color: const Color(0xFF172033),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_rounded,
                                  color: Color(0xFF93C5FD),
                                  size: 46,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  context.l10n.cameraPrompt,
                                  style: const TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              context.l10n.privacyNote,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!ready)
              FilledButton.icon(
                onPressed: _startCamera,
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(context.l10n.startCamera),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _stopCamera,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(context.l10n.stopCamera),
                  ),
                  FilledButton.icon(
                    onPressed: _analyzing ? null : _analyze,
                    icon: _analyzing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.face_retouching_natural),
                    label: Text(
                      _analyzing
                          ? context.l10n.analyzing
                          : context.l10n.analyzeExpression,
                    ),
                  ),
                ],
              ),
            if (_emotion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_emotionLabel(context, _emotion!.emotion)} · ${(_emotion!.confidence * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _emotionFeedback(context, _emotion!.emotion),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 30),
            _SectionTitle(
              icon: Icons.mic_rounded,
              title: context.l10n.speechRecognition,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.sayTarget(widget.exercise.sinhalaText),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 78),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.recognizedSpeech,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    _transcript.isEmpty
                        ? context.l10n.speechPlaceholder
                        : _transcript,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            if (_transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _matches
                      ? context.l10n.targetRecognized
                      : context.l10n.tryTargetAgain,
                  style: TextStyle(
                    color: _matches
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _toggleListening,
              icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(
                _listening
                    ? context.l10n.stopListening
                    : context.l10n.startListening,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}
