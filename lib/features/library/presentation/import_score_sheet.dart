import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/library/data/pdf_import_service.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:path/path.dart' as path;

enum ScoreImportKind { pdf, musicXml }

Future<String?> showImportScoreSheet(
  BuildContext context, {
  required PickedLocalFile file,
  StorageProvider sourceProvider = StorageProvider.local,
  String? folderId,
  ScoreImportKind kind = ScoreImportKind.pdf,
  String? initialTitle,
  String? initialArtist,
  int? initialTempo,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ImportScoreSheet(
      file: file,
      sourceProvider: sourceProvider,
      folderId: folderId,
      kind: kind,
      initialTitle: initialTitle,
      initialArtist: initialArtist,
      initialTempo: initialTempo,
    ),
  );
}

class _ImportScoreSheet extends ConsumerStatefulWidget {
  const _ImportScoreSheet({
    required this.file,
    required this.sourceProvider,
    required this.kind,
    this.folderId,
    this.initialTitle,
    this.initialArtist,
    this.initialTempo,
  });

  final PickedLocalFile file;
  final StorageProvider sourceProvider;
  final String? folderId;
  final ScoreImportKind kind;
  final String? initialTitle;
  final String? initialArtist;
  final int? initialTempo;

  @override
  ConsumerState<_ImportScoreSheet> createState() => _ImportScoreSheetState();
}

class _ImportScoreSheetState extends ConsumerState<_ImportScoreSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final _artistController = TextEditingController();
  final _tempoController = TextEditingController();
  bool _isSaving = false;

  // Why the last try failed, said in the sheet: a snackbar would lie over
  // the button the user has to press again.
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text:
          widget.initialTitle ??
          path.basenameWithoutExtension(widget.file.name),
    );
    _artistController.text = widget.initialArtist ?? '';
    _tempoController.text = widget.initialTempo?.toString() ?? '';
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

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final tempoText = _tempoController.text.trim();

    try {
      final tempo = tempoText.isEmpty ? null : int.parse(tempoText);
      final songId = switch (widget.kind) {
        ScoreImportKind.pdf =>
          await ref
              .read(pdfImportServiceProvider)
              .importPdf(
                file: widget.file,
                title: _titleController.text,
                artist: _artistController.text,
                defaultTempo: tempo,
                sourceProvider: widget.sourceProvider,
                folderId: widget.folderId,
              ),
        ScoreImportKind.musicXml =>
          await ref
              .read(musicXmlImportServiceProvider)
              .importMusicXml(
                file: widget.file,
                title: _titleController.text,
                artist: _artistController.text,
                defaultTempo: tempo,
                sourceProvider: widget.sourceProvider,
                folderId: widget.folderId,
              ),
      };

      if (mounted) {
        Navigator.of(context).pop(songId);
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = error.message;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        final message = context.l10n.importFailed;
        setState(() {
          _isSaving = false;
          _error = message;
        });
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
                widget.kind == ScoreImportKind.pdf
                    ? l10n.importPdfScore
                    : l10n.importMusicXml,
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
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
