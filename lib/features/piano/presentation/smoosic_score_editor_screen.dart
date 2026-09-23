import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_data.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/score_export_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Flutter host for the Smoosic piano editor.
///
/// The editor stays inside a WebView because Smoosic owns the notation UI and
/// its layout/selection model. Flutter remains responsible for app routing,
/// local score storage, version sidecars, and the MusicXML boundary.
class SmoosicScoreEditorScreen extends ConsumerStatefulWidget {
  const SmoosicScoreEditorScreen({this.songId, super.key});

  final String? songId;

  @override
  ConsumerState<SmoosicScoreEditorScreen> createState() =>
      _SmoosicScoreEditorScreenState();
}

class _SmoosicScoreEditorScreenState
    extends ConsumerState<SmoosicScoreEditorScreen> {
  static const _editorAsset = 'assets/smoosic/release/html/piano_editor.html';

  late final WebViewController _controller;
  bool _pageReady = false;
  bool _saveRequested = false;
  bool _saving = false;
  bool _exporting = false;
  ScoreExportKind? _pendingExportKind;
  String? _loadedInitialXml;
  String? _pendingInitialXml;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'SmoosicBridge',
        onMessageReceived: _handleBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (!mounted) return;
            _showMessage(error.description);
          },
        ),
      );
    unawaited(_controller.loadFlutterAsset(_editorAsset));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scoreState = widget.songId == null
        ? null
        : ref.watch(digitalScoreDataProvider(widget.songId!));

    String title = 'Piano editor';
    String? initialXml;
    Widget? overlay;

    if (scoreState == null) {
      initialXml = _blankMusicXml();
    } else {
      scoreState.when(
        loading: () {
          overlay = _EditorOverlay(message: l10n.loading);
        },
        error: (error, _) {
          overlay = _EditorOverlay(
            message: error.toString(),
            actionLabel: l10n.retry,
            onAction: () =>
                ref.invalidate(digitalScoreDataProvider(widget.songId!)),
          );
        },
        data: (data) {
          title = data.song.title;
          initialXml = _musicXmlFor(data);
        },
      );
    }

    final queuedXml = initialXml;
    if (queuedXml != null) {
      _queueInitialScore(queuedXml);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l10n.save,
            onPressed: _pageReady && !_saving ? _requestSave : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
          PopupMenuButton<ScoreExportKind>(
            enabled: _pageReady && !_saving && !_exporting,
            tooltip: 'Export score',
            onSelected: _requestExport,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ScoreExportKind.musicXml,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.music_note_outlined),
                  title: Text('MusicXML'),
                ),
              ),
              PopupMenuItem(
                value: ScoreExportKind.pdf,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller),
          if (overlay case final overlay?) overlay,
        ],
      ),
    );
  }

  void _queueInitialScore(String xml) {
    _pendingInitialXml = xml;
    if (!_pageReady || _loadedInitialXml == xml) return;
    _loadedInitialXml = xml;
    final payload = base64Encode(utf8.encode(xml));
    unawaited(
      _controller.runJavaScript(
        'window.smoosicHost.loadMusicXml(${jsonEncode(payload)});',
      ),
    );
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) return;
      payload = Map<String, dynamic>.from(decoded);
    } on Object {
      return;
    }

    switch (payload['type']) {
      case 'ready':
        if (mounted) {
          setState(() => _pageReady = true);
        } else {
          _pageReady = true;
        }
        final initialXml = _pendingInitialXml;
        if (initialXml != null && _loadedInitialXml != initialXml) {
          _queueInitialScore(initialXml);
        }
      case 'musicXml':
        final value = payload['value'];
        if (_saveRequested && value is String) {
          _saveRequested = false;
          unawaited(_saveMusicXml(value));
        } else if (_pendingExportKind case final kind?) {
          _pendingExportKind = null;
          if (value is String) {
            unawaited(_exportMusicXml(value, kind));
          }
        }
      case 'error':
        _showMessage(
          payload['message']?.toString() ?? 'Smoosic failed to load.',
        );
    }
  }

  void _requestSave() {
    if (!_pageReady || _saving) return;
    _saveRequested = true;
    unawaited(
      _controller.runJavaScript('window.smoosicHost.exportMusicXml();'),
    );
  }

  void _requestExport(ScoreExportKind kind) {
    if (!_pageReady || _saving || _exporting) return;
    _pendingExportKind = kind;
    unawaited(
      _controller.runJavaScript('window.smoosicHost.exportMusicXml();'),
    );
  }

  Future<void> _exportMusicXml(String encodedXml, ScoreExportKind kind) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final score = const MusicXmlCodec().decodeXml(
        utf8.decode(base64Decode(encodedXml)),
      );
      final data = widget.songId == null
          ? null
          : await ref.read(digitalScoreDataProvider(widget.songId!).future);
      final exported = await const ScoreExportService().encode(
        written: score,
        title: data?.song.title ?? score.title ?? 'Piano score',
        sequence: data?.sequence ?? PlaybackSequence.empty,
        arrangement: data?.arrangement ?? ArrangementProfile.off,
        kind: kind,
      );
      final savedPath = await FilePicker.saveFile(
        dialogTitle: exported.fileName,
        fileName: exported.fileName,
        type: FileType.custom,
        allowedExtensions: [exported.extension],
        bytes: exported.bytes,
      );
      if (mounted && savedPath != null) _showMessage(context.l10n.done);
    } on Object catch (error) {
      if (mounted) _showMessage('${context.l10n.saveFailed}: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveMusicXml(String encodedXml) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final xml = utf8.decode(base64Decode(encodedXml));
      final score = const MusicXmlCodec().decodeXml(xml);
      final songId = widget.songId;

      if (songId == null) {
        final title = await _askNewScoreTitle();
        if (title == null || !mounted) return;
        final createdId = await ref
            .read(musicXmlImportServiceProvider)
            .importMusicXml(
              file: PickedLocalFile(
                name: 'score.musicxml',
                bytes: Uint8List.fromList(utf8.encode(xml)),
              ),
              title: title,
              sourceProvider: StorageProvider.local,
            );
        if (mounted) context.go('/score/$createdId');
        return;
      }

      final data = await ref.read(digitalScoreDataProvider(songId).future);
      await ref
          .read(digitalScoreEditorServiceProvider)
          .save(
            songId: songId,
            relativePath: data.song.sourcePath,
            score: score,
            sequence: data.sequence,
            arrangement: data.arrangement,
            versionId: data.versionCatalog.activeId,
          );
      ref.invalidate(digitalScoreDataProvider(songId));
      if (mounted) _showMessage(context.l10n.scoreSaved);
    } on Object catch (error) {
      if (mounted) _showMessage('${context.l10n.saveFailed}: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askNewScoreTitle() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.createScore),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.songTitle,
            hintText: context.l10n.songTitleRequired,
          ),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    final normalized = title?.trim();
    if (normalized == null || normalized.isEmpty) {
      if (mounted) _showMessage(context.l10n.songTitleRequired);
      return null;
    }
    return normalized;
  }

  String _musicXmlFor(DigitalScoreData data) {
    final score = data.activeVersionScore ?? data.score;
    return utf8.decode(
      const MusicXmlCodec().encode(score, MusicXmlFileFormat.musicXml),
    );
  }

  String _blankMusicXml() {
    return utf8.decode(
      const MusicXmlCodec().encode(
        blankPianoScore(title: 'New piano score'),
        MusicXmlFileFormat.musicXml,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditorOverlay extends StatelessWidget {
  const _EditorOverlay({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onAction == null)
                const CircularProgressIndicator()
              else
                const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (onAction != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
