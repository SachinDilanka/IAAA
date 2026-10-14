import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../l10n/l10n.dart';
import '../app/app_controller.dart';

class GuardianScreen extends StatefulWidget {
  const GuardianScreen({super.key});

  @override
  State<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends State<GuardianScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _initializeFields(AppController controller) {
    if (_initialized || controller.child == null) return;
    _nameController.text = controller.child!.name;
    _ageController.text = '${controller.child!.age}';
    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final child = await context.read<AppController>().updateProfile(
        _nameController.text.trim(),
        int.parse(_ageController.text),
      );
      if (!mounted) return;
      await showConfirmationDialog(
        context,
        title: context.l10n.profileUpdated,
        message: context.l10n.profileUpdatedMessage(child.name),
        kind: ConfirmationKind.updated,
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
    _initializeFields(controller);
    return AppScaffold(
      currentIndex: 4,
      title: context.l10n.parentGuardianArea,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5F3FF), Color(0xFFEEF2FF)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFC4B5FD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_person_rounded,
                    color: Color(0xFF7C3AED),
                    size: 38,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(label: Text(context.l10n.adultsOnly)),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.guardianSetupTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(context.l10n.guardianSetupDescription),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final guidance = _GuidanceCard();
                final profile = _ProfileCard(
                  formKey: _formKey,
                  nameController: _nameController,
                  ageController: _ageController,
                  saving: _saving,
                  onSave: _save,
                );
                if (constraints.maxWidth < 820) {
                  return Column(
                    children: [guidance, const SizedBox(height: 18), profile],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: guidance),
                    const SizedBox(width: 18),
                    Expanded(child: profile),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tips = [
      context.l10n.guidanceOne,
      context.l10n.guidanceTwo,
      context.l10n.guidanceThree,
      context.l10n.guidanceFour,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.guidance,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.formKey,
    required this.nameController,
    required this.ageController,
    required this.saving,
    required this.onSave,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController ageController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.childProfile,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Chip(label: Text(context.l10n.ageRange)),
                ],
              ),
              const SizedBox(height: 8),
              Text(context.l10n.profileDescription),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.l10n.childName,
                  hintText: context.l10n.childNameHint,
                  prefixIcon: const Icon(Icons.child_care_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.l10n.nameRequired
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.childAge,
                  helperText: context.l10n.ageRange,
                  prefixIcon: const Icon(Icons.cake_rounded),
                ),
                validator: (value) {
                  final age = int.tryParse(value ?? '');
                  return age == null || age < 4 || age > 10
                      ? context.l10n.ageInvalid
                      : null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  saving ? context.l10n.saving : context.l10n.saveProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
