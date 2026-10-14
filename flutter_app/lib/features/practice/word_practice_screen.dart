import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/emotion_result.dart';
import '../../core/models/exercise.dart';
import '../../core/widgets/animated_guide.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/loading_error_view.dart';
import '../../l10n/l10n.dart';
import '../app/app_controller.dart';

class WordPracticeScreen extends StatefulWidget {
  const WordPracticeScreen({super.key});

  @override
  State<WordPracticeScreen> createState() => _WordPracticeScreenState();
}

class _WordPracticeScreenState extends State<WordPracticeScreen> {
  int _wordIndex = 0;
  int _visibleSteps = 1;
  bool _saving = false;
  bool _talking = false;
  bool _listening = false;
  bool _analyzing = false;
  String _transcript = '';
  EmotionResult? _emotion;
  CameraController? _camera;

  @override
  void dispose() {
    _camera?.dispose();
    context.read<AppController>().speech.stopListening();
    super.dispose();
  }

  String _instruction(BuildContext context, Exercise exercise) {
    if (context.read<AppController>().isSinhala) {
      return exercise.sinhalaInstruction;
    }
    return context.l10n.buildWord(exercise.sinhalaText);
  }

  void _changeWord(int index) {
    setState(() {
      _wordIndex = index;
      _visibleSteps = 1;
      _transcript = '';
      _emotion = null;
    });
  }

  Future<void> _speak(Exercise exercise) async {
    setState(() => _talking = true);
    final success = await context.read<AppController>().speech.speakSinhala(
      exercise.sinhalaText,
    );
    if (!mounted) return;
    setState(() => _talking = false);
    if (!success) await _showAudioUnavailable();
  }

  Future<void> _reveal(Exercise exercise) async {
    if (_visibleSteps < exercise.steps.length) {
      final newCount = _visibleSteps + 1;
      setState(() => _visibleSteps = newCount);
      final success = await context.read<AppController>().speech.speakSinhala(
        exercise.steps[newCount - 1],
      );
      if (!mounted) return;
      if (!success) await _showAudioUnavailable();
      if (newCount == exercise.steps.length) await _recordCompletion(exercise);
    }
  }

  Future<void> _showAudioUnavailable() => showConfirmationDialog(
    context,
    title: context.l10n.audioUnavailableTitle,
    message: context.l10n.audioUnavailableMessage,
    kind: ConfirmationKind.error,
  );

  Future<void> _recordCompletion(Exercise exercise) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AppController>().completeExercise(
        exercise,
        emotion: _emotion?.emotion ?? 'happy',
      );
      if (!mounted) return;
      await showConfirmationDialog(
        context,
        title: context.l10n.activityAdded,
        message: context.l10n.wordAddedMessage(exercise.sinhalaText),
        kind: ConfirmationKind.added,
      );
    } catch (_) {
      if (mounted) {
        await showConfirmationDialog(
          context,
          title: context.l10n.errorTitle,
          message: context.l10n.saveError,
          kind: ConfirmationKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleListening(Exercise exercise) async {
    final speech = context.read<AppController>().speech;
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

  bool _matches(String target) {
    final normalizedTarget = target
        .replaceAll(RegExp(r'[\s.,!?।]'), '')
        .toLowerCase();
    final normalizedSpeech = _transcript
        .replaceAll(RegExp(r'[\s.,!?।]'), '')
        .toLowerCase();
    return normalizedSpeech.isNotEmpty &&
        normalizedSpeech.contains(normalizedTarget);
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
      final bytes = await image.readAsBytes();
      final result = await api.analyzeEmotion(bytes);
      if (mounted) setState(() => _emotion = result);
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
    final controller = context.watch<AppController>();
    final exercises = controller.words;
    return AppScaffold(
      currentIndex: 2,
      title: context.l10n.wordPractice,
      child: controller.isLoading && exercises.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : controller.loadError != null && exercises.isEmpty
          ? LoadingErrorView(onRetry: controller.reload)
          : exercises.isEmpty
          ? LoadingErrorView(onRetry: controller.reload)
          : _buildPractice(context, exercises),
    );
  }

  Widget _buildPractice(BuildContext context, List<Exercise> exercises) {
    if (_wordIndex >= exercises.length) _wordIndex = 0;
    final exercise = exercises[_wordIndex];
    final complete = _visibleSteps >= exercise.steps.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_wordIndex + 1) / exercises.length,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${_wordIndex + 1} / ${exercises.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final guide = AnimatedGuide(
                message: _instruction(context, exercise),
                isTalking: _talking,
              );
              final builder = _WordBuilder(
                exercise: exercise,
                visibleSteps: _visibleSteps,
                complete: complete,
                saving: _saving,
                onReveal: () => _reveal(exercise),
                onSpeak: () => _speak(exercise),
                onPrevious: _wordIndex == 0
                    ? null
                    : () => _changeWord(_wordIndex - 1),
                onNext: _wordIndex == exercises.length - 1
                    ? null
                    : () => _changeWord(_wordIndex + 1),
              );
              final interaction = _CameraSpeechPanel(
                exercise: exercise,
                camera: _camera,
                listening: _listening,
                analyzing: _analyzing,
                transcript: _transcript,
                matches: _matches(exercise.sinhalaText),
                emotion: _emotion,
                emotionLabel: _emotion == null
                    ? null
                    : _emotionLabel(context, _emotion!.emotion),
                emotionFeedback: _emotion == null
                    ? null
                    : _emotionFeedback(context, _emotion!.emotion),
                onStartCamera: _startCamera,
                onStopCamera: _stopCamera,
                onAnalyze: _analyze,
                onListen: () => _toggleListening(exercise),
              );
              if (constraints.maxWidth >= 1080) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 270, child: guide),
                    const SizedBox(width: 18),
                    Expanded(child: builder),
                    const SizedBox(width: 18),
                    SizedBox(width: 360, child: interaction),
                  ],
                );
              }
              if (constraints.maxWidth >= 700) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 260, child: guide),
                        const SizedBox(width: 18),
                        Expanded(child: builder),
                      ],
                    ),
                    const SizedBox(height: 18),
                    interaction,
                  ],
                );
              }
              return Column(
                children: [
                  guide,
                  const SizedBox(height: 18),
                  builder,
                  const SizedBox(height: 18),
                  interaction,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WordBuilder extends StatelessWidget {
  const _WordBuilder({
    required this.exercise,
    required this.visibleSteps,
    required this.complete,
    required this.saving,
    required this.onReveal,
    required this.onSpeak,
    required this.onPrevious,
    required this.onNext,
  });
  final Exercise exercise;
  final int visibleSteps;
  final bool complete;
  final bool saving;
  final VoidCallback onReveal;
  final VoidCallback onSpeak;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Text(exercise.emoji, style: const TextStyle(fontSize: 58)),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: exercise.steps
                  .take(visibleSteps)
                  .map(
                    (step) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFA855F7),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        step,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B21A8),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (complete) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(context.l10n.completeWord),
                    Text(
                      exercise.sinhalaText,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    Text(
                      context.l10n.wordComplete,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (!complete)
                  FilledButton.icon(
                    onPressed: saving ? null : onReveal,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.addNextSound),
                  ),
                OutlinedButton.icon(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(context.l10n.listenToWord),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrevious,
                    child: Text(context.l10n.previous),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onNext,
                    child: Text(context.l10n.next),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraSpeechPanel extends StatelessWidget {
  const _CameraSpeechPanel({
    required this.exercise,
    required this.camera,
    required this.listening,
    required this.analyzing,
    required this.transcript,
    required this.matches,
    required this.emotion,
    required this.emotionLabel,
    required this.emotionFeedback,
    required this.onStartCamera,
    required this.onStopCamera,
    required this.onAnalyze,
    required this.onListen,
  });
  final Exercise exercise;
  final CameraController? camera;
  final bool listening;
  final bool analyzing;
  final String transcript;
  final bool matches;
  final EmotionResult? emotion;
  final String? emotionLabel;
  final String? emotionFeedback;
  final VoidCallback onStartCamera;
  final VoidCallback onStopCamera;
  final VoidCallback onAnalyze;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final ready = camera?.value.isInitialized ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.cameraTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ready
                    ? CameraPreview(camera!)
                    : ColoredBox(
                        color: const Color(0xFF172033),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_rounded,
                                  color: Colors.white,
                                  size: 48,
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
            const SizedBox(height: 10),
            Text(
              context.l10n.privacyNote,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!ready)
              FilledButton.icon(
                onPressed: onStartCamera,
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(context.l10n.startCamera),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onStopCamera,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(context.l10n.stopCamera),
                  ),
                  FilledButton.icon(
                    onPressed: analyzing ? null : onAnalyze,
                    icon: analyzing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.face_retouching_natural),
                    label: Text(
                      analyzing
                          ? context.l10n.analyzing
                          : context.l10n.analyzeExpression,
                    ),
                  ),
                ],
              ),
            if (emotion != null) ...[
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
                      '$emotionLabel · ${(emotion!.confidence * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(emotionFeedback!, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
            const Divider(height: 30),
            Text(
              context.l10n.speechRecognition,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.sayTarget(exercise.sinhalaText),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6D28D9),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.recognizedSpeech,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    transcript.isEmpty
                        ? context.l10n.speechPlaceholder
                        : transcript,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            if (transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  matches
                      ? context.l10n.targetRecognized
                      : context.l10n.tryTargetAgain,
                  style: TextStyle(
                    color: matches
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onListen,
              icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(
                listening
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
