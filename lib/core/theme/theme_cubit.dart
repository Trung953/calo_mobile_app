import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  static const String _themePrefKey = 'user_app_theme_mode';

  ThemeCubit() : super(ThemeMode.dark); // Khởi tạo mặc định Dark Mode

  /// Kiểm tra nhanh trạng thái Dark Mode hiện tại
  bool get isDarkMode => state == ThemeMode.dark;

  /// Đọc theme đã lưu từ bộ nhớ máy khi khởi động app
  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themePrefKey);

      if (savedTheme == 'dark') {
        emit(ThemeMode.dark);
      } else if (savedTheme == 'light') {
        emit(ThemeMode.light);
      } else {
        emit(ThemeMode.dark); // Ưu tiên Dark Theme cho HealthLog
      }
    } catch (_) {
      emit(ThemeMode.dark);
    }
  }

  /// Chuyển đổi Theme: có thể truyền bool hoặc để trống để tự đảo chiều
  Future<void> toggleTheme([bool? targetDark]) async {
    final bool nextIsDark = targetDark ?? (state != ThemeMode.dark);
    final nextMode = nextIsDark ? ThemeMode.dark : ThemeMode.light;

    // Phát State mới ngay lập tức để UI cập nhật không độ trễ
    emit(nextMode);

    // Ghi SharedPreferences ngầm dưới nền
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, nextIsDark ? 'dark' : 'light');
    } catch (_) {}
  }

  /// Khôi phục về chế độ theo hệ thống máy
  Future<void> setSystemTheme() async {
    emit(ThemeMode.system);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themePrefKey);
    } catch (_) {}
  }
}