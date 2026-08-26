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
  double _pointerDownX = 0.0;
  double _consumedDx = 0.0;
  static const Duration _moveDelay = Duration(milliseconds: 150);
  static const double _lockThreshold = 10.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanDown: (details) {
        _pointerDownX = details.localPosition.dx;
      },
      onPanStart: (details) {
        _totalDx = 0.0;
        _totalDy = 0.0;
        _consumedDx = 0.0;
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

        _totalDx = details.localPosition.dx - _pointerDownX - _consumedDx;
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
          while (_totalDx.abs() >= widget.moveThreshold &&
              !widget.gameLogic.isSlamming) {
            final movingRight = _totalDx > 0;
            if (movingRight) {
              widget.gameLogic.movePieceRight();
            } else {
              widget.gameLogic.movePieceLeft();
            }
            _totalDx +=
                movingRight ? -widget.moveThreshold : widget.moveThreshold;
            _consumedDx +=
                movingRight ? widget.moveThreshold : -widget.moveThreshold;
            _lastMoveTime = now;
          }
        } else {
          if (_totalDy >= widget.moveThreshold &&
              !widget.gameLogic.isNewPieceGracePeriod) {
            widget.gameLogic.softDrop();
            _totalDy = 0.0;
            _lastMoveTime = now;
          } else if (_totalDy >= widget.moveThreshold * 0.7 &&
              timeSinceLastMove >= _moveDelay &&
              details.delta.dy > 3.0 &&
              !widget.gameLogic.isNewPieceGracePeriod) {
            widget.gameLogic.softDrop();
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
        }

        _totalDx = 0.0;
        _totalDy = 0.0;
        _consumedDx = 0.0;
        _directionLocked = false;
        _lockedHorizontal = false;
      },
      child: widget.child,
    );
  }
}
