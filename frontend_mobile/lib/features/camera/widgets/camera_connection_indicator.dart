import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CameraConnectionIndicator extends StatefulWidget {
  final String status;
  final bool small;

  const CameraConnectionIndicator({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  State<CameraConnectionIndicator> createState() =>
      _CameraConnectionIndicatorState();
}

class _CameraConnectionIndicatorState extends State<CameraConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.status == 'Connecting...') {
      _controller.repeat(reverse: true);
    } else if (widget.status == 'Connected') {
      _controller.forward();
    } else {
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(covariant CameraConnectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == 'Connecting...' && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.status == 'Connected') {
      _controller.forward();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnecting = widget.status == 'Connecting...';
    final bool isConnected = widget.status == 'Connected';
    final Color color = isConnected
        ? AppTheme.neonGreen
        : isConnecting
            ? AppTheme.neonCyan
            : AppTheme.errorRed;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double pulse = isConnecting
            ? 0.6 + (_controller.value * 0.4)
            : (isConnected ? 1.0 : 0.5);
        final double size = widget.small ? 12.0 : 16.0;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(pulse),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4 * pulse),
                blurRadius: widget.small ? 4 : 8,
                spreadRadius: widget.small ? 1 : 2,
              ),
            ],
          ),
        );
      },
    );
  }
}