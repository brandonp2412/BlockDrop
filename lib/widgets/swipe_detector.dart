import 'package:flutter/material.dart';

import '../game/game_logic.dart';

/// Wraps [child] with swipe/pan gesture handling that drives [gameLogic].
/// Extracted so both the solo and multiplayer game screens can share it.
class SwipeDetector extends StatefulWidget {
  final GameLogic gameLogic;
  final double moveThreshold;
  final double fastSwipeVelocity;
  final Widget child;

  const SwipeDetector({
    super.key,
    required this.gameLogic,
    required this.moveThreshold,
    required this.fastSwipeVelocity,
    required this.child,
  });

  @override
  State<SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<SwipeDetector> {
  double _totalDx = 0.0;
  double _totalDy = 0.0;
  DateTime _lastMoveTime = DateTime.now();
  bool _directionLocked = false;
  bool _lockedHorizontal = false;
  static const Duration _moveDelay = Duration(milliseconds: 150);
  static const double _lockThreshold = 10.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        _totalDx = 0.0;
        _totalDy = 0.0;
        _directionLocked = false;
        _lockedHorizontal = false;
        _lastMoveTime = DateTime.now();
      },
      onPanUpdate: (details) {
        if (!widget.gameLogic.isGameRunning ||
            widget.gameLogic.isGameOver ||
            widget.gameLogic.isPaused) {
          return;
        }

        _totalDx += details.delta.dx;
        _totalDy += details.delta.dy;

        final now = DateTime.now();
        final timeSinceLastMove = now.difference(_lastMoveTime);

        if (!_directionLocked &&
            (_totalDx.abs() >= _lockThreshold ||
                _totalDy.abs() >= _lockThreshold)) {
          _lockedHorizontal = _totalDx.abs() > _totalDy.abs();
          _directionLocked = true;
        }

        if (!_directionLocked) return;

        if (_lockedHorizontal) {
          if (_totalDx.abs() >= widget.moveThreshold &&
              !widget.gameLogic.isSlamming) {
            if (_totalDx > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
            _totalDx = 0.0;
            _lastMoveTime = now;
          } else if (_totalDx.abs() >= widget.moveThreshold * 0.6 &&
              timeSinceLastMove >= _moveDelay &&
              details.delta.dx.abs() > 2.5 &&
              !widget.gameLogic.isSlamming) {
            if (_totalDx > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
            _totalDx = 0.0;
            _lastMoveTime = now;
          }
        } else {
          if (_totalDy >= widget.moveThreshold &&
              !widget.gameLogic.isNewPieceGracePeriod) {
            widget.gameLogic.movePieceDown();
            _totalDy = 0.0;
            _lastMoveTime = now;
          } else if (_totalDy >= widget.moveThreshold * 0.7 &&
              timeSinceLastMove >= _moveDelay &&
              details.delta.dy > 3.0 &&
              !widget.gameLogic.isNewPieceGracePeriod) {
            widget.gameLogic.movePieceDown();
            _totalDy = 0.0;
            _lastMoveTime = now;
          }
        }
      },
      onPanEnd: (details) {
        if (!widget.gameLogic.isGameRunning ||
            widget.gameLogic.isGameOver ||
            widget.gameLogic.isPaused) {
          return;
        }

        if (details.velocity.pixelsPerSecond.dy > widget.fastSwipeVelocity &&
            details.velocity.pixelsPerSecond.dy >
                details.velocity.pixelsPerSecond.dx.abs() * 2 &&
            !widget.gameLogic.isNewPieceGracePeriod) {
          widget.gameLogic.dropPiece();
        } else if (details.velocity.pixelsPerSecond.dx.abs() > 600.0 &&
            details.velocity.pixelsPerSecond.dx.abs() >
                details.velocity.pixelsPerSecond.dy.abs() * 2 &&
            !widget.gameLogic.isSlamming) {
          final direction = details.velocity.pixelsPerSecond.dx > 0 ? 1 : -1;
          final extraMoves =
              (details.velocity.pixelsPerSecond.dx.abs() / 1200.0)
                  .clamp(0.0, 2.0)
                  .round();
          for (int i = 0; i < extraMoves; i++) {
            if (direction > 0) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
          }
        }

        _totalDx = 0.0;
        _totalDy = 0.0;
        _directionLocked = false;
        _lockedHorizontal = false;
      },
      child: widget.child,
    );
  }
}
