import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Two thumb-friendly control clusters for touch gameplay.
class OnScreenGameControls extends StatelessWidget {
  final VoidCallback onMoveLeft, onMoveRight, onSoftDrop;
  final VoidCallback onRotateLeft, onRotateRight, onHardDrop;
  final VoidCallback? onHold;

  const OnScreenGameControls({
    super.key,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onSoftDrop,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onHardDrop,
    this.onHold,
  });

  static double _size(double width) => ((width - 16) / 6).clamp(0.0, 54.0);

  /// Vertical space occupied by the two control clusters.
  static double heightForWidth(double width) => 3 * _size(width);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final s = _size(constraints.maxWidth);
      return Semantics(
        container: true,
        label: context.l10n.text('Game controls'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Cluster(
              size: s,
              top: _Button(
                key: const Key('hard-drop-control'),
                icon: Icons.keyboard_double_arrow_down,
                label: 'Hard drop',
                action: onHardDrop,
                size: s,
              ),
              left: _Button(
                key: const Key('move-left-control'),
                icon: Icons.chevron_left,
                label: 'Move left',
                action: onMoveLeft,
                size: s,
              ),
              right: _Button(
                key: const Key('move-right-control'),
                icon: Icons.chevron_right,
                label: 'Move right',
                action: onMoveRight,
                size: s,
              ),
              bottom: _Button(
                key: const Key('soft-drop-control'),
                icon: Icons.keyboard_arrow_down,
                label: 'Soft drop',
                action: onSoftDrop,
                size: s,
              ),
            ),
            _Cluster(
              size: s,
              top: onHold == null
                  ? null
                  : _Button(
                      key: const Key('hold-control'),
                      icon: Icons.pan_tool_outlined,
                      label: 'Hold piece',
                      action: onHold!,
                      size: s,
                    ),
              left: _Button(
                key: const Key('rotate-left-control'),
                icon: Icons.rotate_left,
                label: 'Rotate left',
                action: onRotateLeft,
                size: s,
              ),
              right: _Button(
                key: const Key('rotate-right-control'),
                icon: Icons.rotate_right,
                label: 'Rotate right',
                action: onRotateRight,
                size: s,
              ),
              bottom: _Button(
                key: const Key('soft-drop-right-control'),
                icon: Icons.keyboard_arrow_down,
                label: 'Soft drop',
                action: onSoftDrop,
                size: s,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Cluster extends StatelessWidget {
  final double size;
  final Widget? top;
  final Widget left, right, bottom;

  const _Cluster({
    required this.size,
    required this.top,
    required this.left,
    required this.right,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size * 3,
        child: Stack(
          children: [
            if (top != null) Positioned(top: 0, left: size, child: top!),
            Positioned(left: 0, top: size, child: left),
            Positioned(right: 0, top: size, child: right),
            Positioned(bottom: 0, left: size, child: bottom),
          ],
        ),
      );
}

class _Button extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback action;
  final double size;

  const _Button({
    super.key,
    required this.icon,
    required this.label,
    required this.action,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.text(label),
      child: Material(
        color: cs.surfaceContainerHighest,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: action,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, size: size * 0.55, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
