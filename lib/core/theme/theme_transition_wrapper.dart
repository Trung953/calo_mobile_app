import 'package:flutter/material.dart';

class ThemeTransitionWrapper extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const ThemeTransitionWrapper({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  State<ThemeTransitionWrapper> createState() => _ThemeTransitionWrapperState();
}

class _ThemeTransitionWrapperState extends State<ThemeTransitionWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _lastIsDark = false;

  @override
  void initState() {
    super.initState();
    _lastIsDark = widget.isDark;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Hiệu ứng mờ dần (Fade) hình sin mượt mà: 0.0 -> 0.45 -> 0.0
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.45).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 45.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.45, end: 0.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 55.0,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant ThemeTransitionWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      _lastIsDark = oldWidget.isDark;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Giao diện chính tự động chuyển màu mượt qua AnimatedTheme
        widget.child,

        // Lớp phủ màu mờ dần êm ái khi đổi trạng thái (Tự động bắt sự kiện, không cần truyền tọa độ)
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            if (_controller.isDismissed || _fadeAnimation.value <= 0.0) {
              return const SizedBox.shrink();
            }
            // Nếu đang chuyển sang Dark -> phủ tối dần, nếu sang Light -> phủ sáng mờ nhẹ
            final Color overlayColor = _lastIsDark 
                ? const Color(0xFF0F172A) 
                : const Color(0xFFF8FAFC);

            return IgnorePointer(
              ignoring: true,
              child: Container(
                color: overlayColor.withValues(alpha: _fadeAnimation.value),
              ),
            );
          },
        ),
      ],
    );
  }
}