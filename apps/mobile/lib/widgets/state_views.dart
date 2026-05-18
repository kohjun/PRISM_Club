import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

/// Shared loading / empty / error blocks. All three match the handoff
/// `StateBlock` pattern: 88×88 rounded-square icon block, display title,
/// caption subtitle, optional primary + ghost CTAs.
///
/// Public constructor shapes (`message`, `onRetry`, `action`) are preserved
/// so the 22 widget tests keep working.

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.xl3,
          vertical: PrismSpacing.xl2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _IconBlock(child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )),
            const SizedBox(height: PrismSpacing.lg),
            Text(
              message ?? '불러오는 중',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: PrismColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.xl3,
          vertical: PrismSpacing.xl2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _IconBlock(
              tint: PrismColors.dangerBg,
              foreground: PrismColors.dangerFg,
              child: Icon(Icons.error_outline, size: 36),
            ),
            const SizedBox(height: PrismSpacing.xl),
            const Text(
              '내용을 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: PrismColors.ink1,
                height: 1.3,
              ),
            ),
            const SizedBox(height: PrismSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  letterSpacing: -0.2,
                  color: PrismColors.ink3,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: PrismSpacing.xl),
              FilledButton(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.xl3,
          vertical: PrismSpacing.xl2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _IconBlock(child: Icon(Icons.inbox_outlined, size: 36)),
            const SizedBox(height: PrismSpacing.xl),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  letterSpacing: -0.2,
                  color: PrismColors.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: PrismSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _IconBlock extends StatelessWidget {
  const _IconBlock({
    required this.child,
    this.tint = PrismColors.bgSoft,
    this.foreground = PrismColors.ink4,
  });

  final Widget child;
  final Color tint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(PrismSpacing.xl2),
      ),
      child: IconTheme(
        data: IconThemeData(color: foreground, size: 36),
        child: child,
      ),
    );
  }
}
