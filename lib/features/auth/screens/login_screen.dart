import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/supabase_service.dart';

/// 登录页（MVP 必备）
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePwd = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请填写邮箱和密码');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseService.signIn(email: email, password: pwd);
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '登录失败，请检查邮箱和密码';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (b) =>
                    AppTheme.primaryGradient.createShader(b),
                child: const Text(
                  '搭哒',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '欢迎回来',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // 邮箱
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: _inputDecoration('邮箱'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 16),

              // 密码
              TextField(
                controller: _pwdCtrl,
                obscureText: _obscurePwd,
                autofillHints: const [AutofillHints.password],
                decoration: _inputDecoration('密码').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePwd
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePwd = !_obscurePwd),
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('登录', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('还没有账号？',
                      style: TextStyle(color: AppTheme.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: const Text('立即注册'),
                  ),
                ],
              ),
              if (!AppConstants.isSupabaseConfigured) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: Text(
                    '进入演示（未配置 Supabase）',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
