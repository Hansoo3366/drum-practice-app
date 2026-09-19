import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';

Future<String?> showCreateMusicXmlSheet(
  BuildContext context, {
  String? folderId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _CreateMusicXmlSheet(folderId: folderId),
  );
}

class _CreateMusicXmlSheet extends ConsumerStatefulWidget {
  const _CreateMusicXmlSheet({this.folderId});

  final String? folderId;

  @override
  ConsumerState<_CreateMusicXmlSheet> createState() =>
      _CreateMusicXmlSheetState();
}

class _CreateMusicXmlSheetState extends ConsumerState<_CreateMusicXmlSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _tempoController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _tempoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    final tempoText = _tempoController.text.trim();

    try {
      final tempo = tempoText.isEmpty ? null : int.parse(tempoText);
      final songId = await ref
          .read(musicXmlImportServiceProvider)
          .createBlank(
            title: _titleController.text,
            artist: _artistController.text,
            defaultTempo: tempo,
            folderId: widget.folderId,
          );
      if (mounted) {
        Navigator.of(context).pop(songId);
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.createFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: sheetContentPadding(
        context,
        horizontal: 24,
        top: 20,
        bottom: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.songTitle,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  return value == null || value.trim().isEmpty
                      ? l10n.songTitleRequired
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _artistController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.artist,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tempoController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.tempo,
                  hintText: l10n.bpmHintRange,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  final tempo = int.tryParse(value);
                  return tempo == null || tempo < 40 || tempo > 240
                      ? l10n.bpmRangeError
                      : null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.create),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
