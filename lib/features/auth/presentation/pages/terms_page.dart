import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_toast.dart';
import 'onboarding_profile_page.dart';
import '../../../diary/presentation/pages/diary_page.dart';

class TermsPage extends StatefulWidget {
  final ApiClient? apiClient;
  const TermsPage({super.key, this.apiClient});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  late final ApiClient _apiClient;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
  }

  Future<void> _onAcceptTerms() async {
    setState(() => _isLoading = true);
    try {
      // 1. Gửi request đồng ý điều khoản lên server
      final response = await _apiClient.post(
        '${ApiEndpoints.baseUrl}/auth/accept-terms',
        {},
      );

      if (!mounted) return;

      if (response != null && (response['success'] == true || response['data'] != null)) {
        AppToast.showSuccess(context, 'Đã xác nhận điều khoản dịch vụ!', title: 'Thành công');

        // 2. Kiểm tra xem người dùng đã hoàn thành Onboarding (nhập chiều cao/cân nặng) chưa
        final resProfile = await _apiClient.get('${ApiEndpoints.baseUrl}/users/profile');
        final dynamic rawData = resProfile?['data'] ?? resProfile ?? {};
        final Map<String, dynamic> userMap = rawData is Map<String, dynamic> ? rawData : {};
        final Map<String, dynamic> profileMap = (userMap['profile'] is Map<String, dynamic>)
            ? userMap['profile']
            : userMap;

        final bool isOnboarded = userMap['isOnboarded'] == true || profileMap['isOnboarded'] == true;
        final String resolvedName = profileMap['fullName'] ?? userMap['fullName'] ?? userMap['username'] ?? '';

        if (!mounted) return;

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
                apiClient: _apiClient,
                initialName: resolvedName,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        throw Exception(response?['message'] ?? 'Không thể xác nhận điều khoản');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Lỗi xác nhận');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onDeclineTerms() async {
    setState(() => _isLoading = true);
    try {
      await _apiClient.delete('${ApiEndpoints.baseUrl}/auth/delete-me');
      await _apiClient.clearToken();

      if (!mounted) return;
      AppToast.showError(
        context,
        'Tài khoản đã bị hủy do chưa chấp thuận điều khoản.',
        title: 'Đã hủy tài khoản',
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      await _apiClient.clearToken();
      if (!mounted) return;
      AppToast.showError(context, 'Đã đưa bạn về trang đăng nhập.', title: 'Thông báo');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Điều khoản & Quyền riêng tư',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: titleColor),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        '1. Thu thập dữ liệu:\nỨng dụng ghi nhận thông tin thể trạng và hình ảnh món ăn để hỗ trợ AI tính toán calo và dinh dưỡng.\n\n'
                        '2. Bảo mật dữ liệu:\nDữ liệu của bạn được mã hóa an toàn và chỉ phục vụ việc cá nhân hóa kế hoạch dinh dưỡng của chính bạn.\n\n'
                        '3. Khuyến cáo sức khỏe:\nCác chỉ số và phân tích do AI đề xuất mang tính tham khảo dinh dưỡng.\n\n'
                        'Nếu bạn chọn "Từ chối", hệ thống sẽ xóa toàn bộ dữ liệu tài khoản vừa tạo và đăng xuất.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.6, color: textColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _onDeclineTerms,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Từ chối',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _onAcceptTerms,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'Đồng ý & Tiếp tục',
                                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                      ),
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