import 'package:flutter/material.dart';
import '../../../../core/utils/app_toast.dart';
import '../../data/auth_repository.dart';

class AuthPage extends StatefulWidget {
  final AuthRepository authRepository;
  final VoidCallback onAuthSuccess;

  const AuthPage({
    super.key,
    required this.authRepository,
    required this.onAuthSuccess,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;
  bool _isLoading = false;

  final _emailCtrl = TextEditingController(text: 'user@test.com');
  final _passCtrl = TextEditingController(text: 'Password@123');
  final _nameCtrl = TextEditingController(text: 'Người Dùng');
  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '65');

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  bool _isPasswordStrong(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&#^()_+={}\[\]:;<>,.~`|\\/-]).{8,}$');
    return regex.hasMatch(password);
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (!_isValidEmail(email)) {
      AppToast.showError(context, 'Vui lòng nhập email đúng định dạng (VD: name@gmail.com)', title: 'Email không hợp lệ');
      return;
    }

    if (!_isLogin && !_isPasswordStrong(password)) {
      AppToast.showError(
        context,
        'Mật khẩu phải từ 8 ký tự, gồm: chữ hoa, chữ thường, số và ký tự đặc biệt',
        title: 'Mật khẩu chưa đủ mạnh',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await widget.authRepository.login(email, password);
      } else {
        await widget.authRepository.register(
          email: email,
          password: password,
          fullName: _nameCtrl.text.trim(),
          gender: 'MALE',
          birthDate: '2000-01-01',
          heightCm: double.tryParse(_heightCtrl.text) ?? 170.0,
          currentWeightKg: double.tryParse(_weightCtrl.text) ?? 65.0,
          activityLevel: 'MODERATELY_ACTIVE',
          goal: 'MAINTAIN',
        );
      }
      if (!mounted) return;
      AppToast.showSuccess(context, _isLogin ? 'Đăng nhập thành công!' : 'Tạo tài khoản thành công!');
      widget.onAuthSuccess();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e, title: _isLogin ? 'Đăng nhập thất bại' : 'Đăng ký thất bại');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Đăng Nhập' : 'Đăng Ký Tài Khoản'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isLogin) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Chiều cao (cm)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cân nặng (kg)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  helperText: _isLogin ? null : 'Tối thiểu 8 ký tự: hoa, thường, số, ký tự đặc biệt',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? 'Đăng Nhập' : 'Đăng Ký & Tính Macro Tự Động'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin
                    ? 'Chưa có tài khoản? Đăng ký ngay'
                    : 'Đã có tài khoản? Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}