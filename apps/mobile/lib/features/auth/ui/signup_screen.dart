import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../data/auth_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(authRepositoryProvider).signupWithEmail(
                email: _emailCtrl.text.trim(),
                password: _passwordCtrl.text,
                nickname: _nicknameCtrl.text.trim(),
              );
      await ref.read(currentUserProvider.notifier).setUser(
            CurrentUser(
              id: result.userId,
              nickname: result.nickname,
              accessToken: result.accessToken,
              refreshToken: result.refreshToken,
            ),
          );
      if (mounted) context.go('/home');
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.bg,
      appBar: AppBar(
        backgroundColor: PrismColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.xl,
            PrismSpacing.lg,
            PrismSpacing.xl,
            PrismSpacing.xl3,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '회원가입',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: PrismColors.ink1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '이메일과 닉네임만 있으면 시작할 수 있어요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: PrismColors.muted,
                  ),
                ),
                const SizedBox(height: PrismSpacing.xl2),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return '이메일을 입력해주세요';
                    if (!s.contains('@')) return '올바른 이메일이 아니에요';
                    return null;
                  },
                ),
                const SizedBox(height: PrismSpacing.md),
                TextFormField(
                  controller: _nicknameCtrl,
                  textInputAction: TextInputAction.next,
                  enabled: !_busy,
                  maxLength: 24,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    helperText: '2~24자, 한글/영문/숫자 가능',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length < 2) return '닉네임은 2자 이상이어야 해요';
                    if (s.length > 24) return '닉네임은 24자 이하여야 해요';
                    return null;
                  },
                ),
                const SizedBox(height: PrismSpacing.md),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  enabled: !_busy,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    helperText: '8자 이상',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').length < 8) return '비밀번호는 8자 이상이어야 해요';
                    return null;
                  },
                ),
                const SizedBox(height: PrismSpacing.xl),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PrismColors.pp600,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('회원가입'),
                ),
                const SizedBox(height: PrismSpacing.md),
                TextButton(
                  onPressed: _busy ? null : () => context.go('/login'),
                  child: const Text('이미 계정이 있으신가요? 로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
