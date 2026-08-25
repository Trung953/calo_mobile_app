import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../auth/presentation/pages/login_register_page.dart';
import 'physical_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final ApiClient apiClient;

  const ProfilePage({super.key, required this.apiClient});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _fullName = '';
  String _email = '';
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final res = await widget.apiClient.get(ApiEndpoints.profile);
      final rawData = res['data'] ?? res;
      final profile = rawData['profile'] ?? rawData;

      if (mounted) {
        setState(() {
          _fullName = profile['fullName'] ?? rawData['fullName'] ?? 'Người dùng';
          _email = rawData['email'] ?? '';
          _avatarUrl = profile['avatarUrl'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingAvatar = true);

      final res = await widget.apiClient.uploadFile(
        '${ApiEndpoints.profile}/avatar',
        File(pickedFile.path),
        'avatar',
      );

      final newUrl = res['data']?['avatarUrl'] ?? res['avatarUrl'];
      if (mounted) {
        setState(() {
          _avatarUrl = newUrl;
        });
        AppToast.showSuccess(context, 'Đổi ảnh đại diện thành công!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Không thể tải ảnh lên');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showAvatarOptions(bool isDark) {
    final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ảnh đại diện',
                style: GoogleFonts.plusJakartaSans(
                  color: textColor,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981)),
                ),
                title: Text(
                  'Chụp ảnh mới',
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0EA5E9)),
                ),
                title: Text(
                  'Chọn từ thư viện',
                  style: GoogleFonts.plusJakartaSans(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpCenterModal(BuildContext context, bool isDark) {
    _showCustomBottomSheet(
      context: context,
      isDark: isDark,
      title: 'Trung tâm trợ giúp',
      icon: Icons.headset_mic_rounded,
      iconColor: const Color(0xFF10B981),
      children: [
        _buildFaqItem(
          isDark: isDark,
          question: 'HealthLog tính Calo & TDEE như thế nào?',
          answer: 'Ứng dụng sử dụng công thức Mifflin-St Jeor chuẩn quốc tế dựa trên độ tuổi, giới tính, chiều cao, cân nặng và cường độ tập luyện để tính toán mức năng lượng tối ưu nhất.',
        ),
        _buildFaqItem(
          isDark: isDark,
          question: 'Làm sao để ghi món ăn nhanh chóng?',
          answer: 'Tại màn hình Nhật ký, bấm nút "+ Ghi món" hoặc sử dụng tính năng nhận diện AI qua camera để quét món ăn tự động.',
        ),
        _buildFaqItem(
          isDark: isDark,
          question: 'Tính năng AI Lộ Trình & Thực Đơn hoạt động ra sao?',
          answer: 'AI sẽ tổng hợp các mục tiêu thể trạng của bạn để lập thực đơn 7 ngày và tính toán thâm hụt calo chuẩn khoa học.',
        ),
      ],
    );
  }

  void _showPrivacyPolicyModal(BuildContext context, bool isDark) {
    _showCustomBottomSheet(
      context: context,
      isDark: isDark,
      title: 'Chính sách bảo mật',
      icon: Icons.shield_rounded,
      iconColor: const Color(0xFFF59E0B),
      children: [
        _buildLegalSection(
          isDark: isDark,
          title: '1. Thu thập dữ liệu thể chất',
          content: 'HealthLog thu thập thông tin thể trạng và nhật ký ăn uống nhằm mục đích duy nhất là tính toán chỉ số dinh dưỡng và cá nhân hóa lộ trình vóc dáng cho bạn.',
        ),
        _buildLegalSection(
          isDark: isDark,
          title: '2. Bảo mật thông tin & Mật khẩu',
          content: 'Toàn bộ mật khẩu được mã hóa an toàn và dữ liệu truyền tải giữa thiết bị với máy chủ được bảo vệ qua giao thức SSL/HTTPS.',
        ),
      ],
    );
  }

  void _showTermsOfServiceModal(BuildContext context, bool isDark) {
    _showCustomBottomSheet(
      context: context,
      isDark: isDark,
      title: 'Điều khoản dịch vụ',
      icon: Icons.description_rounded,
      iconColor: const Color(0xFFA855F7),
      children: [
        _buildLegalSection(
          isDark: isDark,
          title: '1. Chấp thuận điều khoản',
          content: 'Bằng việc đăng ký tài khoản và sử dụng HealthLog, bạn đồng ý tuân thủ toàn bộ các điều khoản sử dụng của ứng dụng.',
        ),
        _buildLegalSection(
          isDark: isDark,
          title: '2. Miễn trừ trách nhiệm y tế',
          content: 'Các thông tin tính toán TDEE và thực đơn đề xuất từ AI chỉ mang tính chất tham khảo dinh dưỡng khoa học, không thay thế chẩn đoán y khoa chuyên sâu.',
        ),
      ],
    );
  }

  void _showCustomBottomSheet({
    required BuildContext context,
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 17.5,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({required bool isDark, required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection({required bool isDark, required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.45,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        title: Text(
          'Đăng xuất tài khoản',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng HealthLog?',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.apiClient.clearToken();
              if (context.mounted) {
                AppToast.showSuccess(context, 'Đã đăng xuất tài khoản an toàn');
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => LoginRegisterPage(apiClient: widget.apiClient),
                  ),
                  (route) => false,
                );
              }
            },
            child: Text(
              'Đăng xuất',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final Color bgColor = Theme.of(context).scaffoldBackgroundColor;
        final Color cardBg = isDark ? const Color(0xFF161F30) : Colors.white;
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color borderColor = isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0);
        final Color innerItemBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

        String? fullAvatarUrl;
        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          if (_avatarUrl!.startsWith('http')) {
            fullAvatarUrl = _avatarUrl;
          } else {
            final host = ApiEndpoints.baseUrl.replaceAll('/api/v1', '');
            fullAvatarUrl = '$host$_avatarUrl';
          }
        }

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : Column(
                    children: [
                      // --- HEADER TRÊN CÙNG ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Tài khoản & Cài đặt',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 36),
                          ],
                        ),
                      ),

                      // --- NỘI DUNG PROFILE ---
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                          children: [
                            // 1. THẺ PROFILE CARD HERO
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: borderColor, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 68,
                                            height: 68,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              border: Border.all(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: _isUploadingAvatar
                                                  ? Container(
                                                      color: Colors.black26,
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                          color: Color(0xFF10B981),
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                    )
                                                  : (fullAvatarUrl != null)
                                                      ? Image.network(
                                                          fullAvatarUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, _, _) => const Icon(
                                                            Icons.person_rounded,
                                                            color: Color(0xFF10B981),
                                                            size: 38,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons.person_rounded,
                                                          color: Color(0xFF10B981),
                                                          size: 38,
                                                        ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: _isUploadingAvatar ? null : () => _showAvatarOptions(isDark),
                                              child: Container(
                                                padding: const EdgeInsets.all(5.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF161F30) : Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _fullName,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: textColor,
                                                fontSize: 18.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _email,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: subColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  InkWell(
                                    onTap: () async {
                                      final updated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PhysicalProfilePage(apiClient: widget.apiClient),
                                        ),
                                      );
                                      if (updated == true) {
                                        _loadUserProfile();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: innerItemBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.accessibility_new_rounded,
                                              color: Color(0xFF10B981),
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Hồ sơ thể chất & Chỉ số TDEE',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: textColor,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Icon(Icons.arrow_forward_ios, color: subColor, size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // 2. GIAO DIỆN & TÙY CHỌN
                            _buildSectionHeader('GIAO DIỆN & TÙY CHỌN', subColor),
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: borderColor, width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                    leading: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF818CF8).withValues(alpha: 0.18)
                                            : const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFFF59E0B),
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      'Chế độ giao diện tối',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    trailing: Switch(
                                      value: isDark,
                                      activeThumbColor: const Color(0xFF10B981),
                                      activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                                      inactiveThumbColor: Colors.grey,
                                      inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
                                      onChanged: (val) {
                                        context.read<ThemeCubit>().toggleTheme(val);
                                      },
                                    ),
                                  ),
                                  Divider(color: borderColor, height: 1, indent: 56),
                                  _buildActionTile(
                                    icon: Icons.language_rounded,
                                    iconColor: const Color(0xFF38BDF8),
                                    title: 'Ngôn ngữ',
                                    trailingText: 'Tiếng Việt',
                                    textColor: textColor,
                                    subColor: subColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // 3. HỖ TRỢ & BẢO MẬT
                            _buildSectionHeader('HỖ TRỢ & BẢO MẬT', subColor),
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: borderColor, width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  _buildActionTile(
                                    icon: Icons.headset_mic_rounded,
                                    iconColor: const Color(0xFF34D399),
                                    title: 'Trung tâm trợ giúp',
                                    textColor: textColor,
                                    subColor: subColor,
                                    onTap: () => _showHelpCenterModal(context, isDark),
                                  ),
                                  Divider(color: borderColor, height: 1, indent: 56),
                                  _buildActionTile(
                                    icon: Icons.shield_rounded,
                                    iconColor: const Color(0xFFF59E0B),
                                    title: 'Chính sách bảo mật',
                                    textColor: textColor,
                                    subColor: subColor,
                                    onTap: () => _showPrivacyPolicyModal(context, isDark),
                                  ),
                                  Divider(color: borderColor, height: 1, indent: 56),
                                  _buildActionTile(
                                    icon: Icons.description_rounded,
                                    iconColor: const Color(0xFFA855F7),
                                    title: 'Điều khoản dịch vụ',
                                    textColor: textColor,
                                    subColor: subColor,
                                    onTap: () => _showTermsOfServiceModal(context, isDark),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // 4. NÚT ĐĂNG XUẤT
                            InkWell(
                              onTap: () => _confirmLogout(context, isDark),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.1 : 0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Đăng xuất tài khoản',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFFEF4444),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, color: Color(0xFFEF4444), size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: subColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    required Color textColor,
    required Color subColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: GoogleFonts.plusJakartaSans(
                color: subColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.arrow_forward_ios, color: subColor, size: 13),
        ],
      ),
      onTap: onTap,
    );
  }
}