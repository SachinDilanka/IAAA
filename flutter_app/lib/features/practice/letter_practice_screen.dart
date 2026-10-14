import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/exercise.dart';
import '../../core/widgets/animated_guide.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/loading_error_view.dart';
import '../app/app_controller.dart';
import '../../l10n/l10n.dart';

class LetterPracticeScreen extends StatefulWidget {
  const LetterPracticeScreen({super.key});

  @override
  State<LetterPracticeScreen> createState() => _LetterPracticeScreenState();
}

class _LetterPracticeScreenState extends State<LetterPracticeScreen> {
  int _index = 0;
  bool _saving = false;
  bool _talking = false;

  String _instruction(BuildContext context, Exercise exercise) {
    if (context.read<AppController>().isSinhala) {
      return exercise.sinhalaInstruction;
    }
    return '${context.l10n.sayTarget(exercise.sinhalaText)}. ${context.l10n.openMouth}';
  }

  Future<void> _speak(Exercise exercise) async {
    setState(() => _talking = true);
    final success = await context.read<AppController>().speech.speakSinhala(
      exercise.sinhalaText,
    );
    if (!mounted) return;
    setState(() => _talking = false);
    if (!success) {
      await showConfirmationDialog(
        context,
        title: context.l10n.audioUnavailableTitle,
        message: context.l10n.audioUnavailableMessage,
        kind: ConfirmationKind.error,
      );
    }
  }

  Future<void> _complete(Exercise exercise) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AppController>().completeExercise(exercise);
      if (!mounted) return;
      await showConfirmationDialog(
        context,
        title: context.l10n.activityAdded,
        message: context.l10n.letterAddedMessage(exercise.sinhalaText),
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
    final exercises = controller.letters;
    return AppScaffold(
      currentIndex: 1,
      title: context.l10n.letterPractice,
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
    if (_index >= exercises.length) _index = 0;
    final exercise = exercises[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_index + 1) / exercises.length,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${_index + 1} / ${exercises.length}',
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
              final activity = _LetterActivity(
                exercise: exercise,
                saving: _saving,
                onSpeak: () => _speak(exercise),
                onComplete: () => _complete(exercise),
                onPrevious: _index == 0 ? null : () => setState(() => _index--),
                onNext: _index == exercises.length - 1
                    ? null
                    : () => setState(() => _index++),
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  children: [guide, const SizedBox(height: 18), activity],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 310, child: guide),
                  const SizedBox(width: 22),
                  Expanded(child: activity),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LetterActivity extends StatelessWidget {
  const _LetterActivity({
    required this.exercise,
    required this.saving,
    required this.onSpeak,
    required this.onComplete,
    required this.onPrevious,
    required this.onNext,
  });

  final Exercise exercise;
  final bool saving;
  final VoidCallback onSpeak;
  final VoidCallback onComplete;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 280),
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF9C3), Color(0xFFFED7AA)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                exercise.sinhalaText,
                style: const TextStyle(
                  fontSize: 128,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: Text(context.l10n.listenToSound),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : onComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.record_voice_over_rounded),
                  label: Text(context.l10n.iSaidIt),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(context.l10n.previous),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNext,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(context.l10n.next),
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
