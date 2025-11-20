import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ProgressController extends ChangeNotifier {
  bool _isStopped = false;
  bool get isStopped => _isStopped;

  void stop() {
    if (!_isStopped) {
      _isStopped = true;
      notifyListeners();
    }
  }

  void reset() {
    if (_isStopped) {
      _isStopped = false;
      notifyListeners();
    }
  }
}

class LinearDeterminateProgressIndicator extends StatefulWidget {
  final Duration duration;
  final VoidCallback onFinished;
  final ProgressController? controller;
  final double height;

  const LinearDeterminateProgressIndicator({
    super.key,
    required this.duration,
    required this.onFinished,
    this.controller,
    this.height = 4.0,
  });

  @override
  State<LinearDeterminateProgressIndicator> createState() =>
      _LinearDeterminateProgressIndicatorState();
}

class _LinearDeterminateProgressIndicatorState
    extends State<LinearDeterminateProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isStopped = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onFinished();
            }
          });
        }
      });

    widget.controller?.addListener(_onControllerUpdate);
    if (widget.duration.inMilliseconds > 0) {
      _animationController.reverse(from: 1.0);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (widget.controller!.isStopped) {
      setState(() {
        _isStopped = true;
        _animationController.stop();
      });
      return;
    }
    // Controller has been reset (not stopped): clear flag and restart if we can
    if (_isStopped && widget.duration.inMilliseconds > 0) {
      setState(() {
        _isStopped = false;
      });
      _animationController
        ..reset()
        ..reverse(from: 1.0);
    }
  }

  @override
  void didUpdateWidget(covariant LinearDeterminateProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _animationController.duration = widget.duration;
      if (widget.duration.inMilliseconds <= 0) {
        setState(() {
          _isStopped = true;
          _animationController.stop();
        });
      } else {
        // Always restart on positive duration and ensure visual state is active
        // even if a prior stop occurred before duration was known.
        setState(() {
          _isStopped = false;
        });
        _animationController
          ..reset()
          ..reverse(from: 1.0);
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerUpdate);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final trackColor = appTheme.textMuted;
    final indicatorColor = appTheme.danger;

    return AnimatedOpacity(
      opacity: _isStopped ? 0.3 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        children: [
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animationController.value,
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(widget.height / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
