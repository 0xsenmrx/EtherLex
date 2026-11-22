import 'package:flutter/widgets.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/fixed_colors.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/files_models.dart';

const double kFileRowExtent = 52;

/// Icon and tint per file type. Mid-tone colours that read on both themes.
({IconData icon, Color color}) fileVisual(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  switch (ext) {
    case 'pdf':
      return (icon: EIcons.fileText, color: FixedColors.pdf);
    case 'doc':
    case 'docx':
    case 'txt':
    case 'rtf':
    case 'md':
      return (icon: EIcons.fileText, color: FixedColors.document);
    case 'ppt':
    case 'pptx':
    case 'key':
      return (icon: EIcons.fileSlides, color: FixedColors.slides);
    case 'xls':
    case 'xlsx':
    case 'csv':
      return (icon: EIcons.fileSheet, color: FixedColors.sheet);
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return (icon: EIcons.fileArchive, color: FixedColors.archive);
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
    case 'svg':
      return (icon: EIcons.fileImage, color: FixedColors.image);
    case 'mp4':
    case 'mov':
    case 'mkv':
    case 'avi':
    case 'webm':
      return (icon: EIcons.fileVideo, color: FixedColors.video);
    case 'py':
    case 'java':
    case 'c':
    case 'cpp':
    case 'js':
    case 'ts':
    case 'dart':
    case 'ipynb':
    case 'm':
      return (icon: EIcons.fileCode, color: FixedColors.code);
    default:
      return (icon: EIcons.file, color: FixedColors.other);
  }
}

/// File, folder or course row: tinted icon tile, name, details, date, and
/// hover actions (hide, download).
class EntryRow extends StatelessWidget {
  const EntryRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.showDownload = false,
    this.onToggleHidden,
    this.hidden = false,
    this.onActionTap,
    this.selected = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;
  final bool showDownload;
  final VoidCallback? onToggleHidden;
  final bool hidden;
  final VoidCallback? onActionTap;

  /// Keyboard cursor is on this row.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return SizedBox(
      height: kFileRowExtent,
      child: Opacity(
        opacity: hidden ? 0.5 : 1,
        child: ETap(
          focusable: false,
          onTap: onTap,
          pressedScale: 0.995,
          builder: (context, tapState) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              color: selected ? c.selected : (tapState.hovered ? c.hover : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: c.isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                      const SizedBox(height: 3),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.metaMuted),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(trailing, style: t.metaMuted),
                if (onToggleHidden != null)
                  SizedBox(
                    width: 34,
                    child: tapState.hovered || selected
                        ? EIconButton(
                            icon: hidden ? EIcons.eye : EIcons.eyeOff,
                            tooltip: hidden ? 'Show' : 'Hide',
                            size: 28,
                            iconSize: 15,
                            bordered: false,
                            onTap: onToggleHidden,
                          )
                        : null,
                  ),
                SizedBox(
                  width: 34,
                  child: showDownload
                      ? (tapState.hovered || selected
                          ? EIconButton(
                              icon: EIcons.download,
                              tooltip: 'Save to Downloads',
                              size: 28,
                              iconSize: 15,
                              bordered: false,
                              onTap: onActionTap,
                            )
                          : null)
                      : Icon(EIcons.chevronRight, size: 16, color: c.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String fileSubtitle(FileEntry f) {
  final dot = f.name.lastIndexOf('.');
  final ext = dot >= 0 && dot < f.name.length - 1 ? f.name.substring(dot + 1).toUpperCase() : 'FILE';
  return '$ext · ${formatBytes(f.size)}';
}

String fileDate(FileEntry f, DateTime now) =>
    f.updatedAt == null ? '' : formatShortDate(f.updatedAt!, now);
