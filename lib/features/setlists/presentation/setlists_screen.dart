import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_empty_state.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_controller.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_name_dialog.dart';

class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = await showSetlistNameDialog(
      context,
      title: l10n.newSetlist,
      confirmLabel: l10n.create,
    );
    if (name == null || name.isEmpty) {
      return;
    }

    try {
      final id = await ref.read(setlistRepositoryProvider).createSetlist(name);
      if (context.mounted) {
        await context.push('/setlists/$id');
      }
    } on Object catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.createFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final setlists = ref.watch(setlistsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSetlists)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        tooltip: l10n.newSetlist,
        child: const Icon(Icons.add_rounded),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: setlists.when(
            data: (items) => items.isEmpty
                ? _EmptySetlists(onCreate: () => _create(context, ref))
                : _SetlistList(items: items),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text(l10n.loadFailed)),
          ),
        ),
      ),
    );
  }
}

class _SetlistList extends StatelessWidget {
  const _SetlistList({required this.items});

  final List<Setlist> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final setlist = items[index];
        return Material(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/setlists/${setlist.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      setlist.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptySetlists extends StatelessWidget {
  const _EmptySetlists({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      child: AppEmptyState(
        icon: Icons.queue_music_rounded,
        title: l10n.emptySetlistsTitle,
        body: l10n.emptySetlistsBody,
        actionLabel: l10n.createSetlist,
        onAction: onCreate,
      ),
    );
  }
}
