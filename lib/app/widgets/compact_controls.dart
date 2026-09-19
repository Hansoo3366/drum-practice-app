import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// 음악 앱 툴바 스타일의 작은 아이콘 버튼.
class CompactIconButton extends StatelessWidget {
  const CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.selected = false,
    this.selectedColor,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool selected;
  final Color? selectedColor;

  static const double size = 40;
  static const double iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected
        ? (selectedColor ?? scheme.secondary)
        : (color ?? scheme.onSurface);

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: iconSize,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(size, size),
        maximumSize: const Size(size, size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon),
    );
  }
}

/// 현재 값을 한 줄로 보여주고, 탭하면 옵션 시트를 연다.
class CompactOptionTile extends StatelessWidget {
  const CompactOptionTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.dense = false,
    this.foregroundColor,
    this.mutedColor,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool enabled;
  final bool dense;
  final Color? foregroundColor;
  final Color? mutedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foregroundColor ?? scheme.onSurface;
    final muted = mutedColor ?? scheme.onSurfaceVariant;

    return ListTile(
      enabled: enabled,
      dense: dense,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: muted, fontSize: 13)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 20, color: muted),
        ],
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

Future<T?> showOptionPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  required T selected,
  Color? backgroundColor,
  Color? foregroundColor,
  Color? mutedColor,
}) {
  final bg = backgroundColor ?? Theme.of(context).colorScheme.surface;
  final fg = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
  final muted = mutedColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: bg,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(labelOf(option), style: TextStyle(color: fg)),
                      trailing: option == selected
                          ? Icon(Icons.check_rounded, color: muted)
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Viewer 설정 시트 상단 아이콘 퀵 액션.
class SettingsQuickAction extends StatelessWidget {
  const SettingsQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? AppColors.accent.withValues(alpha: 0.2)
          : AppColors.stagePanel,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(
                icon,
                color: emphasized ? AppColors.accent : Colors.white,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: emphasized ? AppColors.accent : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 설정 시트의 접이식 그룹.
class SettingsExpansionGroup extends StatelessWidget {
  const SettingsExpansionGroup({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
    this.foregroundColor,
    this.mutedColor,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  final Color? foregroundColor;
  final Color? mutedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foregroundColor ?? scheme.onSurface;
    final muted = mutedColor ?? scheme.onSurfaceVariant;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: muted,
        collapsedIconColor: muted,
        title: Text(
          title,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        children: children,
      ),
    );
  }
}
