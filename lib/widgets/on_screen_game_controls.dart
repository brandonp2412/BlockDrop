import 'package:flutter/material.dart';

/// A compact touch controller for players who prefer discrete game inputs.
class OnScreenGameControls extends StatelessWidget {
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onSoftDrop;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onHardDrop;
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Game controls',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 132,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  child: _ControlButton(
                    key: const Key('move-left-control'),
                    icon: Icons.arrow_left,
                    label: 'Move left',
                    onPressed: onMoveLeft,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: _ControlButton(
                    key: const Key('move-right-control'),
                    icon: Icons.arrow_right,
                    label: 'Move right',
                    onPressed: onMoveRight,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: _ControlButton(
                    key: const Key('soft-drop-control'),
                    icon: Icons.arrow_drop_down,
                    label: 'Soft drop',
                    onPressed: onSoftDrop,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _ControlButton(
                key: const Key('rotate-left-control'),
                icon: Icons.rotate_left,
                label: 'Rotate left',
                onPressed: onRotateLeft,
              ),
              _ControlButton(
                key: const Key('rotate-right-control'),
                icon: Icons.rotate_right,
                label: 'Rotate right',
                onPressed: onRotateRight,
              ),
              _ControlButton(
                key: const Key('hard-drop-control'),
                icon: Icons.vertical_align_bottom,
                label: 'Hard drop',
                onPressed: onHardDrop,
              ),
              if (onHold != null)
                _ControlButton(
                  key: const Key('hold-control'),
                  icon: Icons.inventory_2_outlined,
                  label: 'Hold piece',
                  onPressed: onHold!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
