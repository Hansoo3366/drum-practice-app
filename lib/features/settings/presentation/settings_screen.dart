import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:page_a_diddle/app/branding/app_support.dart';
import 'package:page_a_diddle/app/icons/app_icons.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/l10n/locale_controller.dart';
import 'package:page_a_diddle/app/l10n/locale_picker.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/theme/theme_controller.dart';
import 'package:page_a_diddle/app/widgets/app_brand_mark.dart';
import 'package:page_a_diddle/features/onboarding/data/onboarding_controller.dart';
import 'package:url_launcher/url_launcher.dart';

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = ref.watch(localeControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final packageInfo = ref.watch(_packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Row(
              children: [
                const AppBrandMark(size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appName,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        l10n.tagline,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _SectionHeader(l10n.sectionApp),
          ListTile(
            leading: Icon(Icons.language_rounded, color: colors.primary),
            title: Text(l10n.language),
            subtitle: Text(AppLocaleLabels.of(l10n, locale)),
            onTap: () => pickAppLanguage(
              context: context,
              ref: ref,
              current: locale,
            ),
          ),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: colors.primary),
            title: Text(l10n.theme),
            subtitle: Text(_themeLabel(l10n, themeMode)),
            onTap: () => _pickTheme(context, ref, themeMode),
          ),
          ListTile(
            leading: Icon(AppIcons.cloud, color: colors.primary),
            title: Text(l10n.webDavTechnical),
            subtitle: Text(l10n.cloudScores),
            onTap: () => context.push('/tools/webdav'),
          ),
          ListTile(
            leading: Icon(Icons.waving_hand_outlined, color: colors.primary),
            title: Text(l10n.replayOnboarding),
            onTap: () async {
              await ref.read(onboardingCompletedProvider.notifier).reset();
              if (context.mounted) context.go('/onboarding');
            },
          ),
          const Divider(height: 28),
          _SectionHeader(l10n.sectionLegal),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: colors.primary),
            title: Text(l10n.privacyPolicy),
            onTap: () => context.push('/legal/privacy'),
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: colors.primary),
            title: Text(l10n.termsOfUse),
            onTap: () => context.push('/legal/terms'),
          ),
          ListTile(
            leading: Icon(Icons.mail_outline_rounded, color: colors.primary),
            title: Text(l10n.contactSupport),
            subtitle: const Text(AppSupport.supportEmail),
            onTap: () => _contactSupport(context),
          ),
          ListTile(
            leading: Icon(Icons.balance_outlined, color: colors.primary),
            title: Text(l10n.openSourceLicenses),
            onTap: () {
              final info = packageInfo.asData?.value;
              showLicensePage(
                context: context,
                applicationName: l10n.appName,
                applicationVersion: info?.version,
                applicationLegalese: AppSupport.supportEmail,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: colors.primary),
            title: Text(l10n.version),
            subtitle: Text(
              packageInfo.when(
                data: (info) => '${info.version} (${info.buildNumber})',
                loading: () => '…',
                error: (_, _) => '1.0.0',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(_themeLabel(l10n, mode)),
                  trailing: mode == current
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, mode),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await ref.read(themeControllerProvider.notifier).setThemeMode(selected);
  }

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri.parse(AppSupport.supportMailUri);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenMail)),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
