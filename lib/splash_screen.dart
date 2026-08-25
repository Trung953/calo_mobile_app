import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/api_endpoints.dart';
import 'core/network/api_client.dart';
import 'features/auth/presentation/pages/login_register_page.dart';
import 'features/auth/presentation/pages/onboarding_profile_page.dart';
import 'features/auth/presentation/pages/terms_page.dart';
import 'features/diary/presentation/pages/diary_page.dart';

class SplashScreen extends StatefulWidget {
  final ApiClient apiClient;

  const SplashScreen({super.key, required this.apiClient});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();
    _startTransition();
  }

  Future<void> _startTransition() async {
    String? token;
    bool isOnboarded = false;
    bool termsAccepted = true;
    String resolvedName = '';

    try {
      // 1. Chạy song song: Đọc token và giữ hiệu ứng logo ít nhất 2.2 giây
      final tokenFuture = widget.apiClient.getToken();
      final delayFuture = Future.delayed(const Duration(milliseconds: 2200));

      final results = await Future.wait([tokenFuture, delayFuture]);
      token = results[0] as String?;

      // 2. Nếu đã có token, lấy thông tin hồ sơ
      if (token != null && token.trim().isNotEmpty) {
        final res = await widget.apiClient.get('${ApiEndpoints.baseUrl}/users/profile');
        if (res != null && (res['success'] == true || res['data'] != null)) {
          final dynamic rawData = res['data'] ?? res;
          final Map<String, dynamic> userMap = rawData is Map<String, dynamic> ? rawData : {};
          final Map<String, dynamic> profileMap = (userMap['profile'] is Map<String, dynamic>)
              ? userMap['profile']
              : userMap;

          isOnboarded = userMap['isOnboarded'] == true || profileMap['isOnboarded'] == true;
          termsAccepted = userMap['termsAccepted'] == true ||
              profileMap['termsAccepted'] == true ||
              isOnboarded;
          resolvedName = profileMap['fullName'] ?? userMap['fullName'] ?? userMap['username'] ?? '';
        } else {
          isOnboarded = true;
        }
      }
    } catch (_) {
      // Khi mất mạng tạm thời, vẫn đọc lại token từ bộ nhớ để không bị văng ra Login
      token = await widget.apiClient.getToken();
      isOnboarded = true;
    }

    if (!mounted) return;

    final bool isAuthenticated = token != null && token.trim().isNotEmpty;

    // 3. Phân luồng điều hướng
    Widget targetPage;
    if (!isAuthenticated) {
      targetPage = LoginRegisterPage(apiClient: widget.apiClient);
    } else if (!termsAccepted && !isOnboarded) {
      targetPage = TermsPage(apiClient: widget.apiClient);
    } else if (isOnboarded) {
      targetPage = const DiaryPage();
    } else {
      targetPage = OnboardingProfilePage(
        apiClient: widget.apiClient,
        initialName: resolvedName,
      );
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(
                          alpha: isDark ? 0.35 : 0.18,
                        ),
                        blurRadius: isDark ? 32 : 24,
                        spreadRadius: isDark ? 4 : 2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icon/logo_APP.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.8,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF10B981)],
                      ).createShader(bounds),
                      child: Text(
                        'Log',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(2, -4),
                      child: const Icon(
                        Icons.eco_rounded,
                        size: 22,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 16,
                      height: 1.5,
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Theo dõi dinh dưỡng & Lộ trình vóc dáng',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 16,
                      height: 1.5,
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}