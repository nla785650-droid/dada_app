import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/supabase_service.dart';

/// 注册页（MVP 必备）
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscurePwd = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    if (name.isEmpty || email.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请填写完整信息');
      return;
    }

    if (pwd.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseService.signUp(
        email: email,
        password: pwd,
        username: name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('注册成功，请查收验证邮件'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.success,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '注册失败，该邮箱可能已存在';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '创建账号',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '加入搭哒，发现更多精彩',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 36),

              TextField(
                controller: _nameCtrl,
                decoration: _inputDecoration('昵称'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('邮箱'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwdCtrl,
                obscureText: _obscurePwd,
                decoration: _inputDecoration('密码（至少 6 位）').copyWith(
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
                onPressed: _loading ? null : _signUp,
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
                    : const Text('注册', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('已有账号？',
                      style: TextStyle(color: AppTheme.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('去登录'),
                  ),
                ],
              ),
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
