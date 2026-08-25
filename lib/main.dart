import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/api_endpoints.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme_cubit.dart';
import 'core/theme/theme_transition_wrapper.dart';
import 'features/auth/presentation/pages/login_register_page.dart';
import 'features/auth/presentation/pages/onboarding_profile_page.dart';
import 'features/auth/presentation/pages/terms_page.dart';
import 'features/diary/data/repositories/diary_repository.dart';
import 'features/diary/presentation/bloc/diary_bloc.dart';
import 'features/diary/presentation/pages/diary_page.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeCubit = ThemeCubit();
  await themeCubit.loadSavedTheme();
  runApp(MyApp(themeCubit: themeCubit));
}

class MyApp extends StatelessWidget {
  final ThemeCubit themeCubit;

  const MyApp({super.key, required this.themeCubit});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final diaryRepository = DiaryRepository(apiClient: apiClient);

    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightScaffold,
      primaryColor: AppColors.primary,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightDivider,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightScaffold,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.lightCard,
        onSurface: AppColors.lightTextPrimary,
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkScaffold,
      primaryColor: AppColors.primary,
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.darkDivider,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkScaffold,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkTextPrimary,
      ),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: themeCubit),
        BlocProvider<DiaryBloc>(
          create: (_) => DiaryBloc(repository: diaryRepository),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          final isDark = themeMode == ThemeMode.dark;

          return MaterialApp(
            title: 'HealthLog',
            debugShowCheckedModeBanner: false,
            // Giữ themeMode cố định để MaterialApp không hủy và dựng lại toàn bộ cây widget gây chớp màn hình
            themeMode: ThemeMode.light,
            theme: lightTheme,
            darkTheme: darkTheme,
            builder: (context, child) {
              return ThemeTransitionWrapper(
                isDark: isDark,
                child: AnimatedTheme(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  data: isDark ? darkTheme : lightTheme,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            routes: {
              '/login': (context) => LoginRegisterPage(apiClient: apiClient),
              '/terms': (context) => TermsPage(apiClient: apiClient),
              '/home': (context) => const DiaryPage(),
            },
            home: SplashScreen(apiClient: apiClient),
          );
        },
      ),
    );
  }
}

class AuthCheckWrapper extends StatefulWidget {
  final ApiClient apiClient;

  const AuthCheckWrapper({super.key, required this.apiClient});

  @override
  State<AuthCheckWrapper> createState() => _AuthCheckWrapperState();
}

class _AuthCheckWrapperState extends State<AuthCheckWrapper> {
  bool _checking = true;
  bool _isAuthenticated = false;
  bool _needsTerms = false;
  bool _needsOnboarding = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await widget.apiClient.getToken();
    if (token == null || token.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _checking = false;
        });
      }
      return;
    }

    try {
      final res = await widget.apiClient.get('${ApiEndpoints.baseUrl}/users/profile');
      if (res != null && (res['success'] == true || res['data'] != null)) {
        final dynamic rawData = res['data'] ?? res;
        final Map<String, dynamic> userMap = rawData is Map<String, dynamic> ? rawData : {};
        final Map<String, dynamic> profileMap = (userMap['profile'] is Map<String, dynamic>)
            ? userMap['profile']
            : userMap;

        final bool isOnboarded = userMap['isOnboarded'] == true || profileMap['isOnboarded'] == true;
        final bool termsAccepted = userMap['termsAccepted'] == true ||
            profileMap['termsAccepted'] == true ||
            isOnboarded;

        final String resolvedName = profileMap['fullName'] ?? userMap['fullName'] ?? userMap['username'] ?? '';

        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _needsTerms = !termsAccepted && !isOnboarded;
            _needsOnboarding = !isOnboarded;
            _userName = resolvedName;
            _checking = false;
          });
        }
        return;
      }
    } catch (_) {
      final savedToken = await widget.apiClient.getToken();
      if (savedToken != null && savedToken.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _needsTerms = false;
            _needsOnboarding = false;
            _checking = false;
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = false;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_isAuthenticated) {
      if (_needsTerms) {
        return TermsPage(apiClient: widget.apiClient);
      }
      if (_needsOnboarding) {
        return OnboardingProfilePage(
          apiClient: widget.apiClient,
          initialName: _userName,
        );
      }
      return const DiaryPage();
    }

    return LoginRegisterPage(apiClient: widget.apiClient);
  }
}