import 'dart:io' show Platform, exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../diary/presentation/pages/diary_page.dart';
import 'onboarding_profile_page.dart';

class LoginRegisterPage extends StatefulWidget {
  final ApiClient apiClient;

  const LoginRegisterPage({super.key, required this.apiClient});

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  bool _isLoginMode = true;
  bool _obscurePass = true;
  bool _isLoading = false;
  bool _isSocialLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool _isPasswordStrong(String password) {
    final regex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#^()_+={}\[\]:;<>,.~`|\\/-]).{8,}$');
    return regex.hasMatch(password);
  }

  void _exitApp() {
    if (kIsWeb) {
      SystemNavigator.pop();
    } else {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else if (Platform.isIOS) {
        exit(0);
      }
    }
  }

  Future<bool> _showTermsAgreementDialog() async {
    bool isAgreed = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.7,
          expand: false,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_outlined,
                          color: Color(0xFF8B5CF6), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Điều khoản dịch vụ & Sử dụng',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFF334155)),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildLegalSection(
                        title: '1. Chấp thuận điều khoản',
                        content:
                            'Bằng việc đăng ký tài khoản và sử dụng HealthLog, bạn đồng ý tuân thủ toàn bộ các điều khoản sử dụng và quy định vận hành của ứng dụng.',
                      ),
                      _buildLegalSection(
                        title: '2. Miễn trừ trách nhiệm y tế',
                        content:
                            'Các thông tin tính toán TDEE, Calo và thực đơn đề xuất từ AI chỉ mang tính chất tham khảo khoa học dinh dưỡng đời sống. Ứng dụng không thay thế cho phác đồ điều trị, đơn thuốc hay chẩn đoán từ bác sĩ chuyên khoa.',
                      ),
                      _buildLegalSection(
                        title: '3. Trách nhiệm người dùng',
                        content:
                            'Người dùng có trách nhiệm tự bảo mật thông tin tài khoản đăng nhập của mình và đảm bảo thông tin số đo nhập vào là chính xác để hệ thống tính toán hiệu quả nhất.',
                      ),
                      _buildLegalSection(
                        title: '4. Bản quyền & Cập nhật',
                        content:
                            'Bản quyền giao diện, thuật toán và nội dung thuộc về HealthLog. Điều khoản có thể được cập nhật định kỳ để nâng cao chất lượng dịch vụ người dùng.',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16, color: Color(0xFF334155)),
                InkWell(
                  onTap: () => setModalState(() => isAgreed = !isAgreed),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isAgreed,
                          activeColor: AppColors.primary,
                          checkColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF64748B), width: 1.5),
                          onChanged: (val) => setModalState(() => isAgreed = val ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'Tôi đã đọc, hiểu rõ và đồng ý với toàn bộ Điều khoản dịch vụ của HealthLog.',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx, false);
                        },
                        child: const Text('Từ chối', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAgreed ? AppColors.primary : Colors.grey.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isAgreed ? () => Navigator.pop(ctx, true) : null,
                        child: const Text('Đồng ý & Tiếp tục', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    return result == true;
  }

  Widget _buildLegalSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Colors.white)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Future<void> _navigateBasedOnOnboardingStatus(
    Map<String, dynamic>? res, {
    String? defaultName,
    bool checkTerms = false,
  }) async {
    if (!mounted) return;

    final dynamic rawData = res?['data'] ?? res ?? {};
    final Map<String, dynamic> data = rawData is Map<String, dynamic> ? rawData : {};
    final Map<String, dynamic> user = (data['user'] is Map<String, dynamic>) ? data['user'] : {};
    final Map<String, dynamic> profile = (user['profile'] is Map<String, dynamic>)
        ? user['profile']
        : ((data['profile'] is Map<String, dynamic>) ? data['profile'] : {});

    final bool isOnboarded = user['isOnboarded'] == true ||
        profile['isOnboarded'] == true ||
        data['isOnboarded'] == true;

    final String resolvedName = (defaultName != null && defaultName.trim().isNotEmpty)
        ? defaultName.trim()
        : (profile['fullName'] ?? user['fullName'] ?? user['username'] ?? '');

    // Chỉ hỏi điều khoản khi checkTerms = true (Tài khoản Google mới toanh)
    if (checkTerms) {
      final agreed = await _showTermsAgreementDialog();
      if (!agreed) {
        try {
          await widget.apiClient.delete('${ApiEndpoints.baseUrl}/auth/delete-me');
        } catch (_) {}
        await widget.apiClient.clearToken();
        if (mounted) {
          AppToast.showError(
            context,
            'Tài khoản đã bị hủy do chưa chấp thuận điều khoản.',
            title: 'Đã hủy đăng ký',
          );
        }
        return;
      }

      try {
        await widget.apiClient.post('${ApiEndpoints.baseUrl}/auth/accept-terms', {});
      } catch (_) {}
    }

    if (!mounted) return;

    AppToast.showSuccess(
      context,
      _isLoginMode ? 'Đăng nhập thành công!' : 'Tạo tài khoản thành công!',
    );

    if (isOnboarded) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DiaryPage(key: UniqueKey())),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => OnboardingProfilePage(
            apiClient: widget.apiClient,
            initialName: resolvedName,
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passCtrl.text.trim();
    if (!_isLoginMode && !_isPasswordStrong(password)) {
      AppToast.showError(
        context,
        'Mật khẩu phải từ 8 ký tự, gồm: chữ hoa, chữ thường, số và ký tự đặc biệt',
        title: 'Mật khẩu chưa đủ mạnh',
      );
      return;
    }

    // Đăng ký thường: Hỏi điều khoản tại đây
    if (!_isLoginMode) {
      final agreed = await _showTermsAgreementDialog();
      if (!agreed) return;
    }

    setState(() => _isLoading = true);

    try {
      final endpoint = _isLoginMode ? ApiEndpoints.login : ApiEndpoints.register;
      final payload = _isLoginMode
          ? {
              'username': _usernameCtrl.text.trim(),
              'password': _passCtrl.text,
            }
          : {
              'username': _usernameCtrl.text.trim(),
              'email': _emailCtrl.text.trim(),
              'password': _passCtrl.text,
            };

      final res = await widget.apiClient.post(endpoint, payload);
      final token = res['data']?['token'] ?? res['token'];

      if (token != null) {
        await widget.apiClient.saveToken(token);

        if (!_isLoginMode) {
          try {
            await widget.apiClient.post('${ApiEndpoints.baseUrl}/auth/accept-terms', {});
          } catch (_) {}
        }

        _navigateBasedOnOnboardingStatus(res, defaultName: _usernameCtrl.text.trim(), checkTerms: false);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          e,
          title: _isLoginMode ? 'Đăng nhập thất bại' : 'Đăng ký thất bại',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading || _isSocialLoading) return;
    setState(() => _isSocialLoading = true);

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isSocialLoading = false);
        return;
      }

      final String googleName = (googleUser.displayName != null && googleUser.displayName!.trim().isNotEmpty)
          ? googleUser.displayName!.trim()
          : googleUser.email.split('@')[0];

      final res = await widget.apiClient.post(ApiEndpoints.google, {
        'email': googleUser.email,
        'displayName': googleName,
        'photoUrl': googleUser.photoUrl,
      });

      final token = res['data']?['token'] ?? res['token'];
      if (token != null) {
        await widget.apiClient.saveToken(token);
      }

      // Trích xuất an toàn dữ liệu trả về
      final dynamic rawData = res['data'] ?? res ?? {};
      final dynamic rawUser = (rawData is Map<String, dynamic> && rawData['user'] != null)
          ? rawData['user']
          : rawData;
      final dynamic rawProfile = (rawUser is Map<String, dynamic> && rawUser['profile'] != null)
          ? rawUser['profile']
          : (rawData is Map<String, dynamic> ? rawData['profile'] : null);

      // 1. Kiểm tra xem tài khoản đã Onboarded chưa
      final bool isOnboarded = (rawUser is Map<String, dynamic> && rawUser['isOnboarded'] == true) ||
          (rawProfile is Map<String, dynamic> && rawProfile['isOnboarded'] == true) ||
          (rawData is Map<String, dynamic> && rawData['isOnboarded'] == true);

      // 2. Kiểm tra cờ termsAccepted
      final bool termsAccepted = (rawUser is Map<String, dynamic> && rawUser['termsAccepted'] == true) ||
          (rawData is Map<String, dynamic> && rawData['termsAccepted'] == true);

      // 3. Kiểm tra cờ isNewUser
      final bool isNew = (rawData is Map<String, dynamic> && rawData['isNewUser'] == true) ||
          res['isNewUser'] == true;

      // ĐIỀU KIỆN QUYẾT ĐỊNH:
      // Tài khoản cũ đã hoàn tất hồ sơ (isOnboarded == true) -> KHÔNG BAO GIỜ HỎI
      // Tài khoản mới (isNew == true HOẶC chưa onboard + chưa accept terms) -> BẮT BUỘC HỎI
      final bool needShowTerms = !isOnboarded && (isNew || !termsAccepted);

      _navigateBasedOnOnboardingStatus(
        res,
        defaultName: googleName,
        checkTerms: needShowTerms,
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Đăng nhập Google thất bại');
      }
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color inputFillColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color hintColor = isDark ? const Color(0xFF64748B) : Colors.grey.shade400;

    final bool isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.2),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icon/logo_APP.png',
                          width: 130,
                          height: 130,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
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
                              fontSize: 32,
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
                            size: 20,
                            color: Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 16, height: 1.5, color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Text(
                          'Theo dõi dinh dưỡng & Lộ trình vóc dáng',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hintColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 16, height: 1.5, color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _usernameCtrl,
                      hintText: _isLoginMode ? 'Tên đăng nhập hoặc Email' : 'Tên người dùng (Username)',
                      prefixIcon: Icons.person_outline_rounded,
                      inputFillColor: inputFillColor,
                      textColor: textColor,
                      hintColor: hintColor,
                      isDark: isDark,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên người dùng' : null,
                    ),
                    const SizedBox(height: 14),
                    if (!_isLoginMode) ...[
                      _buildTextField(
                        controller: _emailCtrl,
                        hintText: 'Địa chỉ Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        inputFillColor: inputFillColor,
                        textColor: textColor,
                        hintColor: hintColor,
                        isDark: isDark,
                        validator: (v) => v == null || !v.contains('@') ? 'Nhập email hợp lệ' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildTextField(
                      controller: _passCtrl,
                      hintText: 'Mật khẩu',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePass,
                      inputFillColor: inputFillColor,
                      textColor: textColor,
                      hintColor: hintColor,
                      isDark: isDark,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: hintColor, size: 20),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: (v) => v == null || v.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null,
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: (_isLoading || _isSocialLoading) ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                _isLoginMode ? 'Đăng nhập' : 'Tạo tài khoản',
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: Text(
                        _isLoginMode ? 'Bạn chưa có tài khoản? Đăng ký ngay' : 'Đã có tài khoản? Đăng nhập',
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'HOẶC',
                            style: GoogleFonts.plusJakartaSans(
                                color: hintColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: (_isLoading || _isSocialLoading) ? null : _signInWithGoogle,
                        child: _isSocialLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration:
                                        const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Text('G',
                                        style: TextStyle(
                                            color: Color(0xFF3B82F6),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15)),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        'Sign in with Google',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700, fontSize: 14.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (isApplePlatform) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {},
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.apple, color: Colors.black, size: 22),
                              const SizedBox(width: 8),
                              Text('Sign in with Apple',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    required Color inputFillColor,
    required Color textColor,
    required Color hintColor,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(color: hintColor, fontSize: 14.5),
        filled: true,
        fillColor: inputFillColor,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: hintColor, size: 20) : null,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
      validator: validator,
    );
  }
}