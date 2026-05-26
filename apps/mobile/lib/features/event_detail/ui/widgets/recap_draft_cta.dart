import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/api_error.dart';
import '../../../post/ui/post_composer_screen.dart';
import '../../data/recap_suggest_repository.dart';

/// P7.3 — call-to-action that pulls a recap draft from the backend and
/// drops the organizer into the composer with the body, event-card
/// attachment, and target room already wired up.
///
/// The CTA is rendered only for `eventStatus == 'COMPLETED'`. We don't
/// pre-check eligibility (the backend is the source of truth): the tap
/// kicks off `POST /v1/event-cards/:id/recap/suggest`, and the response
/// either resolves into the composer or surfaces a snackbar explaining
/// why the user can't draft this recap (403 = not organizer, 400 =
/// status mismatch, 404 = unknown event).
class RecapDraftCallToAction extends ConsumerStatefulWidget {
  const RecapDraftCallToAction({
    super.key,
    required this.eventCardId,
    required this.eventStatus,
  });

  final String eventCardId;
  final String eventStatus;

  @override
  ConsumerState<RecapDraftCallToAction> createState() =>
      _RecapDraftCallToActionState();
}

class _RecapDraftCallToActionState
    extends ConsumerState<RecapDraftCallToAction> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (widget.eventStatus != 'COMPLETED') return const SizedBox.shrink();
    // Slim row so the CTA doesn't push the existing related-rooms /
    // related-posts sections out of the default test viewport (the
    // `event_detail_screen_test` widget tests assert on those labels
    // being mounted, which depends on them staying within ~600px of
    // the top). Helper copy lives on the button label itself.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.sm,
        PrismSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('recap-draft-cta'),
              icon: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: Text(
                _loading ? '후기 초안 만드는 중…' : '후기 초안 만들기',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: PrismColors.pp700,
                side: const BorderSide(color: PrismColors.pp200),
              ),
              onPressed: _loading ? null : _onTap,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTap() async {
    setState(() => _loading = true);
    try {
      final dto = await ref
          .read(recapSuggestRepositoryProvider)
          .suggest(widget.eventCardId);
      if (!mounted) return;
      if (dto.suggestedRoomSlugs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('연결된 방을 찾지 못했어요. 직접 방을 골라 작성해 주세요.'),
          ),
        );
        return;
      }
      // The backend orders owned rooms first — picking [0] gives the
      // organizer's own surface when they have one, falling back to the
      // most canonical linked room otherwise. A multi-room picker is a
      // v2 enhancement once we see whether organizers actually want to
      // choose between rooms here.
      final targetSlug = dto.suggestedRoomSlugs.first;
      final composerArgs = PostComposerArgs(
        initialBody: dto.suggestedBody,
        initialEventCardId: dto.event.id,
      );
      // ignore: use_build_context_synchronously
      context.push(
        '/rooms/$targetSlug/compose',
        extra: composerArgs,
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      final msg = _humanize(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanize(ApiError e) {
    // Backend uses 403 for "not organizer / not planner" and 400 for
    // status-not-COMPLETED. The raw server message is already in Korean
    // so it's fine to surface verbatim; we just add a friendly fallback
    // for unexpected statuses.
    if (e.statusCode == 403 || e.statusCode == 400) {
      return e.message;
    }
    return '후기 초안을 만들지 못했어요: ${e.message}';
  }
}
