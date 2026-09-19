import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/library/data/pdf_import_service.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:path/path.dart' as path;

Future<String?> showImportScoreSheet(
  BuildContext context, {
  required PickedLocalFile file,
  StorageProvider sourceProvider = StorageProvider.local,
  String? folderId,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ImportScoreSheet(
      file: file,
      sourceProvider: sourceProvider,
      folderId: folderId,
    ),
  );
}

class _ImportScoreSheet extends ConsumerStatefulWidget {
  const _ImportScoreSheet({
    required this.file,
    required this.sourceProvider,
    this.folderId,
  });

  final PickedLocalFile file;
  final StorageProvider sourceProvider;
  final String? folderId;

  @override
  ConsumerState<_ImportScoreSheet> createState() => _ImportScoreSheetState();
}

class _ImportScoreSheetState extends ConsumerState<_ImportScoreSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final _artistController = TextEditingController();
  final _tempoController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: path.basenameWithoutExtension(widget.file.name),
    );
  }

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
      final songId = await ref
          .read(pdfImportServiceProvider)
          .importPdf(
            file: widget.file,
            title: _titleController.text,
            artist: _artistController.text,
            defaultTempo: tempoText.isEmpty ? null : int.parse(tempoText),
            sourceProvider: widget.sourceProvider,
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
        ).showSnackBar(SnackBar(content: Text(context.l10n.importFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.importPdfScore,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                widget.file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: _artistController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.artist,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
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
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_rounded),
                  label: Text(_isSaving ? l10n.importing : l10n.import),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
