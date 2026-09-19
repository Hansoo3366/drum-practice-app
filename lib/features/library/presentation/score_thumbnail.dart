import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/icons/app_icons.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/library/domain/score_type.dart';
import 'package:pdfrx/pdfrx.dart';

/// Renders the first PDF page as a compact cover, with type-icon fallback.
class ScoreThumbnail extends ConsumerStatefulWidget {
  const ScoreThumbnail({
    required this.song,
    this.width = 52,
    this.height = 64,
    super.key,
  });

  final Song song;
  final double width;
  final double height;

  @override
  ConsumerState<ScoreThumbnail> createState() => _ScoreThumbnailState();
}

class _ScoreThumbnailState extends ConsumerState<ScoreThumbnail> {
  ui.Image? _image;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ScoreThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.sourcePath != widget.song.sourcePath ||
        oldWidget.song.scoreType != widget.song.scoreType) {
      _image?.dispose();
      _image = null;
      _failed = false;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final song = widget.song;
    if (ScoreType.fromKey(song.scoreType) != ScoreType.pdf) {
      return;
    }
    if (!song.offlineAvailable) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    try {
      await pdfrxFlutterInitialize();
      final file = await ref
          .read(songFileStorageProvider)
          .resolve(song.sourcePath);
      if (!await file.exists()) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      final doc = await PdfDocument.openFile(file.path);
      try {
        if (doc.pages.isEmpty) {
          if (mounted) setState(() => _failed = true);
          return;
        }
        final page = doc.pages.first;
        final fullWidth = widget.width * 2.5;
        final fullHeight = fullWidth * page.height / page.width;
        final rendered = await page.render(
          fullWidth: fullWidth,
          fullHeight: fullHeight,
        );
        if (rendered == null) {
          if (mounted) setState(() => _failed = true);
          return;
        }
        try {
          final image = await rendered.createImage(
            pixelSizeThreshold: (widget.width * 3).round(),
          );
          if (!mounted) {
            image.dispose();
            return;
          }
          setState(() {
            _image?.dispose();
            _image = image;
            _failed = false;
          });
        } finally {
          rendered.dispose();
        }
      } finally {
        await doc.dispose();
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      child: _image != null
          ? RawImage(
              image: _image,
              fit: BoxFit.cover,
              width: widget.width,
              height: widget.height,
            )
          : _FallbackCover(song: widget.song, failed: _failed),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.song, required this.failed});

  final Song song;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final isMusicXml = ScoreType.fromKey(song.scoreType) == ScoreType.musicXml;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isMusicXml ? Icons.music_note_rounded : AppIcons.scorePdf,
          size: 18,
          color: failed && !isMusicXml
              ? AppColors.stageMuted
              : AppColors.accent,
        ),
        const SizedBox(height: 4),
        Text(
          isMusicXml ? 'XML' : 'PDF',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
