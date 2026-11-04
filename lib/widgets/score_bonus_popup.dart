import 'package:flutter/material.dart';

import '../game/game_logic.dart';
import '../l10n/app_localizations.dart';

/// Shows the score earned for a line clear over the active game board.
class ScoreBonusPopup extends StatefulWidget {
  const ScoreBonusPopup({super.key, required this.gameLogic});

  final GameLogic gameLogic;

  @override
  State<ScoreBonusPopup> createState() => _ScoreBonusPopupState();
}

class _ScoreBonusPopupState extends State<ScoreBonusPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _offset;
  String _label = '';
  int _delta = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
    ]).animate(_controller);
    _offset = Tween<double>(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    widget.gameLogic.addListener(_onGameStateChanged);
    _onGameStateChanged();
  }

  @override
  void didUpdateWidget(covariant ScoreBonusPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameLogic == widget.gameLogic) return;
    oldWidget.gameLogic.removeListener(_onGameStateChanged);
    widget.gameLogic.addListener(_onGameStateChanged);
    _controller.reset();
    _onGameStateChanged();
  }

  void _onGameStateChanged() {
    if (widget.gameLogic.clearBonusLabel.isEmpty) return;
    _label = widget.gameLogic.clearBonusLabel;
    _delta = widget.gameLogic.lastScoreDelta;
    widget.gameLogic.consumeClearBonus();
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.gameLogic.removeListener(_onGameStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (_controller.isDismissed || _controller.isCompleted) {
              return const SizedBox.shrink();
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: constraints.maxHeight / 2 + _offset.value,
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.text(_label),
                          key: const ValueKey('score-bonus-label'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _label.startsWith('T-SPIN')
                                ? Colors.purple[200]
                                : (_label == 'QUAD!'
                                    ? Colors.amber
                                    : Colors.white),
                            fontSize: _label == 'QUAD!' ? 26 : 20,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(blurRadius: 8, color: Colors.black),
                            ],
                          ),
                        ),
                        Text(
                          '+$_delta',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
