import 'package:flutter/material.dart';

/// 可愛いローディング用Widget
class CuteLoadingWidget extends StatefulWidget {
  final String? message;
  final double size;
  final Color color;
  final Widget? icon;

  const CuteLoadingWidget({
    Key? key,
    this.message,
    this.size = 64,
    this.color = const Color(0xFF8B5CF6),
    this.icon,
  }) : super(key: key);

  @override
  State<CuteLoadingWidget> createState() => _CuteLoadingWidgetState();
}

class _CuteLoadingWidgetState extends State<CuteLoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            color: Colors.white,
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              child: widget.icon ??
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _controller.value * 6.28319, // 2π
                        child: child,
                      );
                    },
                    child: Text(
                      'C',
                      style: TextStyle(
                        fontSize: widget.size * 0.6,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                        fontFamily: 'Rounded Mplus 1c',
                        letterSpacing: 2,
                      ),
                    ),
                  ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 24),
            Text(
              widget.message!,
              style: TextStyle(
                color: widget.color,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }
}

/// 可愛い空状態Widget
class CuteEmptyWidget extends StatelessWidget {
  final String message;
  final Widget? icon;
  final Color color;
  final double width;
  final double height;

  const CuteEmptyWidget({
    Key? key,
    required this.message,
    this.icon,
    this.color = const Color(0xFF2563EB), // デフォ青系
    this.width = 320,
    this.height = 180,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon ?? Icon(Icons.access_time, size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
