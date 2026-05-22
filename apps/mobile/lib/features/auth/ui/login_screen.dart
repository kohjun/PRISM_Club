import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../data/auth_repository.dart';

/// Read by router.dart to conditionally register `/dev/login`. Compiled
/// out of release builds because `bool.fromEnvironment` resolves at
/// compile time.
const bool kPrismDevLoginEnabled = bool.fromEnvironment(
  'PRISM_DEV_LOGIN',
  defaultValue: false,
);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(authRepositoryProvider).loginWithEmail(
                email: _emailCtrl.text.trim(),
                password: _passwordCtrl.text,
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
          SnackBar(content: Text('로그인 실패: ${e.message}')),
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const _AuthHero(
                title: 'PRISM Club',
                subtitle: '주제를 함께 쌓는 커뮤니티',
              ),
              Padding(
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
                      _KakaoLoginButton(),
                      const SizedBox(height: PrismSpacing.lg),
                      const _OrDivider(),
                      const SizedBox(height: PrismSpacing.lg),
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
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !_busy,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
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
                          if ((v ?? '').isEmpty) return '비밀번호를 입력해주세요';
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
                            : const Text('로그인'),
                      ),
                      const SizedBox(height: PrismSpacing.md),
                      TextButton(
                        onPressed: _busy ? null : () => context.go('/signup'),
                        child: const Text('계정이 없으신가요? 회원가입'),
                      ),
                      if (kPrismDevLoginEnabled) ...[
                        const SizedBox(height: PrismSpacing.lg),
                        OutlinedButton.icon(
                          onPressed:
                              _busy ? null : () => context.go('/dev/login'),
                          icon: const Icon(Icons.science_outlined, size: 18),
                          label: const Text('Dev 페르소나로 진입'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.xl3,
        PrismSpacing.xl,
        PrismSpacing.xl2,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PrismColors.pp50, PrismColors.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: PrismColors.ink1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: PrismColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kakao OAuth is wired on the API side (Phase 1.1) but the mobile-side
/// in-app webview flow needs the production redirect URI which is
/// gated on the team picking a domain. Kept disabled with a clear
/// "준비 중" label so the button doesn't disappear once domain lands.
class _KakaoLoginButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: const Text('카카오 로그인 (준비 중)'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: PrismColors.muted,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: PrismColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.md),
          child: Text(
            '또는 이메일로',
            style: const TextStyle(
              color: PrismColors.muted,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider(color: PrismColors.line)),
      ],
    );
  }
}
