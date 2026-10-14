import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

enum ConfirmationKind { added, updated, deleted, error }

Future<void> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  ConfirmationKind kind = ConfirmationKind.updated,
}) {
  final color = switch (kind) {
    ConfirmationKind.added => const Color(0xFF16A34A),
    ConfirmationKind.updated => const Color(0xFF7C3AED),
    ConfirmationKind.deleted => const Color(0xFFE11D48),
    ConfirmationKind.error => const Color(0xFFDC2626),
  };
  final icon = switch (kind) {
    ConfirmationKind.added => Icons.star_rounded,
    ConfirmationKind.updated => Icons.check_rounded,
    ConfirmationKind.deleted => Icons.delete_outline_rounded,
    ConfirmationKind.error => Icons.error_outline_rounded,
  };

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.ok),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
