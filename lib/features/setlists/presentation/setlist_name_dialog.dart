import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';

Future<String?> showSetlistNameDialog(
  BuildContext context, {
  String? title,
  String? confirmLabel,
  String? initialName,
}) {
  final l10n = AppLocalizations.of(context);
  final resolvedTitle = title ?? l10n.setlist;
  final resolvedConfirm = confirmLabel ?? l10n.save;
  final controller = TextEditingController(text: initialName ?? '');

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(resolvedTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: l10n.name),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(resolvedConfirm),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
