import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_layout.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/session/jam_session_store.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_controller.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_instrument_ui.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_qr_scan_screen.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_session_error_l10n.dart';

class JamHubScreen extends ConsumerStatefulWidget {
  const JamHubScreen({this.setlistId, super.key});

  final String? setlistId;

  @override
  ConsumerState<JamHubScreen> createState() => _JamHubScreenState();
}

class _JamHubScreenState extends ConsumerState<JamHubScreen> {
  bool _busy = false;
  bool _discovering = false;
  List<JamNearbyRoom> _nearbyRooms = const [];
  String? _nearbyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_discoverNearbyRooms());
    });
  }

  void _setBusy(bool value) {
    if (mounted && _busy != value) {
      setState(() => _busy = value);
    }
  }

  Future<void> _discoverNearbyRooms() async {
    if (_discovering) return;
    final l10n = context.l10n;
    setState(() => _discovering = true);
    try {
      final rooms = await ref.read(jamSessionStoreProvider).discoverRooms();
      if (mounted) {
        setState(() {
          _nearbyRooms = rooms;
          _nearbyError = null;
        });
      }
    } on JamSessionException catch (error) {
      if (mounted) {
        setState(() {
          _nearbyRooms = const [];
          _nearbyError = jamSessionErrorMessage(l10n, error);
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _nearbyRooms = const [];
          _nearbyError = l10n.jamNetworkUnavailable;
        });
      }
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _create(BuildContext context) async {
    final l10n = context.l10n;
    final values = await _showJamFields(
      context,
      title: l10n.jam,
      confirmLabel: l10n.create,
      includeSessionTitle: true,
    );
    if (values == null) {
      return;
    }
    _setBusy(true);
    try {
      final active = await ref
          .read(activeJamProvider.notifier)
          .create(
            title: values.sessionTitle ?? '',
            displayName: values.displayName,
            instrument: values.instrument,
            customInstrument: values.customInstrument,
            setlistId: widget.setlistId,
          );
      if (context.mounted) {
        unawaited(context.push('/jam/s/${active.sessionId}'));
      }
    } on JamSessionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jamSessionErrorMessage(l10n, error))),
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _join(BuildContext context, {String? code}) async {
    final l10n = context.l10n;
    final values = await _showJamFields(
      context,
      title: l10n.join,
      confirmLabel: l10n.join,
      includeCode: code == null,
      initialCode: code,
    );
    if (values == null) {
      return;
    }
    _setBusy(true);
    try {
      final active = await ref
          .read(activeJamProvider.notifier)
          .join(
            code: values.code ?? code ?? '',
            displayName: values.displayName,
            instrument: values.instrument,
            customInstrument: values.customInstrument,
          );
      if (context.mounted) {
        unawaited(context.push('/jam/s/${active.sessionId}'));
      }
    } on JamSessionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jamSessionErrorMessage(l10n, error))),
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _scan(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const JamQrScanScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!context.mounted || code == null) {
      return;
    }
    await _join(context, code: code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = ref.watch(activeJamProvider);
    final activeSession = active == null
        ? null
        : ref.watch(jamSessionProvider(active.sessionId)).asData?.value;
    final nearbyRooms = _nearbyRooms
        .where((room) => room.code != activeSession?.code)
        .toList(growable: false);

    return Theme(
      data: AppTheme.stage,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          return Scaffold(
            appBar: AppBar(title: Text(l10n.jam)),
            body: AppScreen(
              maxWidth: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (active != null) ...[
                    Material(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: AppColors.accent,
                        ),
                        title: Text(
                          l10n.activeJams,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          l10n.tapToGoBack,
                          style: textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => unawaited(
                          context.push('/jam/s/${active.sessionId}'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.nearbyJams,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _discovering
                            ? null
                            : () => unawaited(_discoverNearbyRooms()),
                        icon: _discovering
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_find_rounded),
                        label: Text(l10n.findNearbyJams),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_nearbyError case final error?) ...[
                    Material(
                      color: AppColors.stageElevated,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                error,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_nearbyError == null &&
                      nearbyRooms.isEmpty &&
                      !_discovering)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.noNearbyJams,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final room in nearbyRooms)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: AppColors.stageElevated,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minVerticalPadding: 4,
                            leading: const Icon(
                              Icons.groups_outlined,
                              color: AppColors.accent,
                            ),
                            title: Text(
                              room.title?.isNotEmpty == true
                                  ? room.title!
                                  : l10n.jam,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(room.code),
                            ),
                            trailing: Text(
                              '${room.participantCount ?? 1} ${l10n.participants}',
                              style: textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onTap: () =>
                                unawaited(_join(context, code: room.code)),
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.jamTagline,
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.canvas,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(height: 3, width: 40, color: AppColors.accent),
                  const SizedBox(height: 14),
                  Text(
                    l10n.jamHubHint,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            unawaited(_create(context));
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.canvas,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(_busy ? l10n.loading : l10n.createJam),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => unawaited(_join(context)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.canvas,
                            side: const BorderSide(
                              color: AppColors.stageOutline,
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(_busy ? l10n.loading : l10n.joinWithCode),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => unawaited(_scan(context)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.canvas,
                            side: const BorderSide(
                              color: AppColors.stageOutline,
                            ),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: Text(l10n.scanQr),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JamFields {
  const _JamFields({
    required this.displayName,
    required this.instrument,
    this.customInstrument,
    this.sessionTitle,
    this.code,
  });

  final String displayName;
  final JamInstrument instrument;
  final String? customInstrument;
  final String? sessionTitle;
  final String? code;
}

Future<_JamFields?> _showJamFields(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  bool includeSessionTitle = false,
  bool includeCode = false,
  String? initialCode,
}) {
  final l10n = context.l10n;
  final nameController = TextEditingController();
  final titleController = TextEditingController();
  final codeController = TextEditingController(text: initialCode ?? '');
  final customInstrumentController = TextEditingController();
  var selectedInstrument = JamInstrument.drums;
  var otherError = false;

  return showDialog<_JamFields>(
    context: context,
    builder: (dialogContext) {
      return Theme(
        data: AppTheme.stage,
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.stageElevated,
              title: Text(
                title,
                style: const TextStyle(
                  color: AppColors.canvas,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: AppColors.canvas,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.stagePanel,
                        hintText: l10n.name,
                      ),
                    ),
                    if (includeSessionTitle) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          color: AppColors.canvas,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.stagePanel,
                          hintText: l10n.jamName,
                        ),
                      ),
                    ],
                    if (includeCode) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          color: AppColors.canvas,
                          fontFamily: AppFonts.mono,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.stagePanel,
                          hintText: l10n.code,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.jamPart,
                        style: const TextStyle(
                          color: AppColors.stageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.75,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final instrument in JamInstrument.values)
                          _JamInstrumentChoice(
                            instrument: instrument,
                            label: jamInstrumentLabel(l10n, instrument),
                            selected: selectedInstrument == instrument,
                            onTap: () => setState(() {
                              selectedInstrument = instrument;
                              otherError = false;
                            }),
                          ),
                      ],
                    ),
                    if (selectedInstrument == JamInstrument.other) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customInstrumentController,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(
                          color: AppColors.canvas,
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: (_) {
                          if (otherError) {
                            setState(() => otherError = false);
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.stagePanel,
                          hintText: l10n.jamPartOtherHint,
                          errorText: otherError ? l10n.enterOtherPart : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.stageMuted,
                  ),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final custom = selectedInstrument == JamInstrument.other
                        ? normalizeJamCustomInstrument(
                            customInstrumentController.text,
                          )
                        : null;
                    if (selectedInstrument == JamInstrument.other &&
                        custom == null) {
                      setState(() => otherError = true);
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      _JamFields(
                        displayName: nameController.text,
                        instrument: selectedInstrument,
                        customInstrument: custom,
                        sessionTitle: includeSessionTitle
                            ? titleController.text
                            : null,
                        code: includeCode ? codeController.text : initialCode,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.canvas,
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ),
      );
    },
  ).whenComplete(() {
    nameController.dispose();
    titleController.dispose();
    codeController.dispose();
    customInstrumentController.dispose();
  });
}

class _JamInstrumentChoice extends StatelessWidget {
  const _JamInstrumentChoice({
    required this.instrument,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final JamInstrument instrument;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.18)
          : AppColors.stagePanel,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                jamInstrumentIcon(instrument),
                size: 18,
                color: selected ? AppColors.accent : AppColors.stageMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.canvas : AppColors.stageMuted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
