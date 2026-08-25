// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/theme_cubit.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    final themeCubit = ThemeCubit();
    
    // Khởi dựng widget app
    await tester.pumpWidget(MyApp(themeCubit: themeCubit));

    // Đợi timer chuyển trang (2.2s) của SplashScreen chạy xong hoàn toàn
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
