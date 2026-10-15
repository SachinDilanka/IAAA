import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/exercise.dart';
import '../../core/widgets/animated_guide.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/loading_error_view.dart';
import '../../l10n/l10n.dart';
import '../app/app_controller.dart';
import 'practice_tools_panel.dart';

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
  String _detectedEmotion = 'happy';

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
      _detectedEmotion = 'happy';
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
        emotion: _detectedEmotion,
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
              final interaction = PracticeToolsPanel(
                exercise: exercise,
                onEmotionChanged: (emotion) => _detectedEmotion = emotion,
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
