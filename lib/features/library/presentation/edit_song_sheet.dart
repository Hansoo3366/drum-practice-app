import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/library/data/audio_attachment_service.dart';
import 'package:page_a_diddle/features/library/data/audio_picker.dart';
import 'package:page_a_diddle/features/library/data/folder_repository.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/folder_colors.dart';
import 'package:page_a_diddle/features/library/domain/label_name.dart';

Future<void> showEditSongSheet(BuildContext context, {required Song song}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _EditSongSheet(song: song),
  );
}

class _EditSongSheet extends ConsumerStatefulWidget {
  const _EditSongSheet({required this.song});

  final Song song;

  @override
  ConsumerState<_EditSongSheet> createState() => _EditSongSheetState();
}

class _EditSongSheetState extends ConsumerState<_EditSongSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _tempoController;
  late final TextEditingController _noteController;
  late final TextEditingController _labelController;
  late String? _audioName;
  late String? _folderId;
  late List<String> _labelNames;
  bool _isSaving = false;
  bool _isPickingAudio = false;
  var _labelsReady = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _tempoController = TextEditingController(
      text: widget.song.defaultTempo?.toString(),
    );
    _noteController = TextEditingController(text: widget.song.note);
    _labelController = TextEditingController();
    _audioName = widget.song.audioName;
    _folderId = widget.song.folderId;
    _labelNames = const [];
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    final labels = await ref
        .read(labelRepositoryProvider)
        .labelsForSong(widget.song.id);
    if (!mounted) return;
    setState(() {
      _labelNames = labels.map((label) => label.name).toList();
      _labelsReady = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _tempoController.dispose();
    _noteController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _addLabelFromField() {
    final name = normalizeLabelName(_labelController.text);
    if (name.isEmpty) return;
    setState(() {
      if (!_labelNames.contains(name)) {
        _labelNames = [..._labelNames, name];
      }
      _labelController.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    final tempoText = _tempoController.text.trim();

    try {
      await ref
          .read(songRepositoryProvider)
          .updateMetadata(
            id: widget.song.id,
            title: _titleController.text,
            artist: _artistController.text,
            defaultTempo: tempoText.isEmpty ? null : int.parse(tempoText),
            note: _noteController.text,
            folderId: _folderId,
            clearFolder: _folderId == null,
          );
      await ref
          .read(labelRepositoryProvider)
          .setSongLabels(songId: widget.song.id, labelNames: _labelNames);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      }
    }
  }

  Future<void> _pickAudio() async {
    if (_isPickingAudio) {
      return;
    }
    setState(() => _isPickingAudio = true);

    try {
      final file = await ref.read(audioPickerProvider).pick();
      if (file == null) {
        return;
      }
      final name = await ref
          .read(audioAttachmentServiceProvider)
          .attach(songId: widget.song.id, file: file);
      if (mounted) {
        setState(() => _audioName = name);
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.audioAttachFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingAudio = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];

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
                l10n.songInfo,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
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
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                // ignore: deprecated_member_use
                value: _folderId,
                decoration: InputDecoration(
                  labelText: l10n.folder,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.noFolder),
                  ),
                  for (final folder in folders)
                    DropdownMenuItem<String?>(
                      value: folder.id,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: FolderColors.toColor(folder.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(child: Text(folder.name)),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _folderId = value),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.labels,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (!_labelsReady)
                const LinearProgressIndicator()
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in _labelNames)
                      InputChip(
                        label: Text('#$name'),
                        onDeleted: () {
                          setState(() {
                            _labelNames = _labelNames
                                .where((item) => item != name)
                                .toList();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _labelController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.addLabel,
                          hintText: l10n.labelHint,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addLabelFromField(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addLabelFromField,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.ink,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.audio_file_outlined),
                  title: Text(
                    _audioName ?? l10n.audio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    onPressed: _isPickingAudio ? null : _pickAudio,
                    child: Text(
                      _audioName == null ? l10n.connect : l10n.change,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                minLines: 3,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: l10n.memo,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? l10n.saving : l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
