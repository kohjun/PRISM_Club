import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../widgets/prism_avatar.dart';
import '../../../widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../data/dev_user_dto.dart';

final _devUsersProvider = FutureProvider<List<DevUserDto>>((ref) {
  return ref.read(authRepositoryProvider).listDevUsers();
});

class LoginPickerScreen extends ConsumerWidget {
  const LoginPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(_devUsersProvider);
    return Scaffold(
      backgroundColor: PrismColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const _BrandHero(),
            Expanded(
              child: users.when(
                loading: () => const LoadingView(message: '사용자 목록 로딩 중...'),
                error: (e, _) => ErrorView(
                  message: e is ApiError ? e.message : '사용자 목록을 불러오지 못했어요.',
                  onRetry: () => ref.invalidate(_devUsersProvider),
                ),
                data: (items) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.xl,
                    PrismSpacing.lg,
                    PrismSpacing.xl,
                    PrismSpacing.xl3,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _UserTile(user: items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.xl3,
        PrismSpacing.xl,
        PrismSpacing.xl,
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PrismColors.pp700,
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                ),
                child: CustomPaint(
                  size: const Size(22, 22),
                  painter: _BrandTriangle(),
                ),
              ),
              const SizedBox(width: PrismSpacing.md),
              // Expanded so the subtitle '예능 콘텐츠 · 오프라인 모임 지식형
              // 커뮤니티' wraps or ellipsizes instead of overflowing the
              // brand-hero Row on narrow phones (~53px overflow at 360dp
              // before this wrap — caught by login_picker_visual_smoke_test).
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PRISM Club',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: PrismColors.ink1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '예능 콘텐츠 · 오프라인 모임 지식형 커뮤니티',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: PrismColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: PrismColors.bg,
              borderRadius: BorderRadius.circular(PrismRadius.md),
              border: Border.all(color: PrismColors.pp100),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: PrismColors.pp700),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '시드 페르소나로 로그인하는 개발용 화면입니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: PrismColors.ink2,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandTriangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.16)
      ..lineTo(size.width * 0.88, size.height * 0.84)
      ..lineTo(size.width * 0.12, size.height * 0.84)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UserTile extends ConsumerStatefulWidget {
  const _UserTile({required this.user});
  final DevUserDto user;

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  bool _busy = false;

  /// M13: POST /v1/auth/login → store JWT → navigate. Unchanged from the
  /// previous implementation; only the surrounding UI changed.
  Future<void> _loginAndGo(String path) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(authRepositoryProvider).login(widget.user.id);
      await ref.read(currentUserProvider.notifier).setUser(
            CurrentUser(
              id: result.userId,
              nickname: result.nickname,
              accessToken: result.accessToken,
              refreshToken: result.refreshToken,
            ),
          );
      if (mounted) context.go(path);
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
    final user = widget.user;
    return Container(
      decoration: BoxDecoration(
        color: PrismColors.bg,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        border: Border.all(color: PrismColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          onTap: _busy ? null : () => _loginAndGo('/home'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.cardPad,
              vertical: PrismSpacing.md,
            ),
            child: Row(
              children: [
                if (_busy)
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PrismColors.pp600,
                        ),
                      ),
                    ),
                  )
                else
                  PrismAvatar(name: user.nickname, size: 44),
                const SizedBox(width: PrismSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: PrismColors.ink1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: PrismColors.ink4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: PrismColors.ink3,
                  ),
                  tooltip: '프로필 보기',
                  onPressed:
                      _busy ? null : () => _loginAndGo('/users/${user.id}'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: PrismColors.ink4,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
