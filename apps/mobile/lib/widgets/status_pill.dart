import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

/// Status pill — `<dot> <label>`. Used on event status, recruitment status,
/// moderation/curation status, "HOT" / "NEW" markers, etc.
///
/// All variants share the same metrics (handoff §components):
///   • font-size 11, weight 700, letter-spacing 0.2
///   • padding 3×8, radius 5, white-space nowrap
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.showDot = true,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool showDot;

  /// 모집중 / 진행중 / 채택 / 해결 — success tone.
  factory StatusPill.success(String label) => StatusPill(
        label: label,
        background: PrismColors.successBg,
        foreground: PrismColors.successFg,
      );

  /// 마감임박 / 대기 / 경고 — warning tone.
  factory StatusPill.warning(String label) => StatusPill(
        label: label,
        background: PrismColors.warningBg,
        foreground: PrismColors.warningFg,
      );

  /// 긴급 / 반려 — danger tone.
  factory StatusPill.danger(String label) => StatusPill(
        label: label,
        background: PrismColors.dangerBg,
        foreground: PrismColors.dangerFg,
      );

  /// 처리중 — info tone.
  factory StatusPill.info(String label) => StatusPill(
        label: label,
        background: PrismColors.infoBg,
        foreground: PrismColors.infoFg,
      );

  /// 모집완료 / 기각 / 종료 — neutral tone.
  factory StatusPill.neutral(String label) => StatusPill(
        label: label,
        background: PrismColors.neutralBg,
        foreground: PrismColors.neutralFg,
      );

  /// 검토중 / NEW — Club Purple soft tone.
  factory StatusPill.purple(String label) => StatusPill(
        label: label,
        background: PrismColors.pp100,
        foreground: PrismColors.pp700,
      );

  /// 숨김 (운영 시점) — high-contrast ink-1 tone.
  factory StatusPill.hidden(String label) => StatusPill(
        label: label,
        background: PrismColors.ink1,
        foreground: Colors.white,
        showDot: false,
      );

  /// HOT marker — danger tone, label-only (no dot).
  factory StatusPill.hot([String label = 'HOT']) => StatusPill(
        label: label,
        background: PrismColors.dangerBg,
        foreground: PrismColors.dangerFg,
        showDot: false,
      );

  /// Map a recruitment status string ("OPEN" / "CLOSED" / "FILLED") to a
  /// localized pill.
  static StatusPill recruitment(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return StatusPill.success('모집중');
      case 'CLOSED':
        return StatusPill.neutral('모집완료');
      case 'FILLED':
        return StatusPill.neutral('마감');
      default:
        return StatusPill.neutral(status);
    }
  }

  /// Map a contribution decision ("PENDING" / "APPROVED" / "REJECTED" /
  /// "CHANGES_REQUESTED") to a localized pill.
  static StatusPill contribution(String decision) {
    switch (decision.toUpperCase()) {
      case 'PENDING':
        return StatusPill.purple('검토중');
      case 'APPROVED':
        return StatusPill.success('채택');
      case 'REJECTED':
        return StatusPill.danger('반려');
      case 'CHANGES_REQUESTED':
        return StatusPill.warning('보완 요청');
      default:
        return StatusPill.neutral(decision);
    }
  }

  /// Map an event status string ("UPCOMING" / "PAST" / "CANCELLED") to a
  /// localized pill.
  static StatusPill event(String status) {
    switch (status.toUpperCase()) {
      case 'UPCOMING':
      case 'OPEN':
        return StatusPill.success('진행 예정');
      case 'PAST':
      case 'CLOSED':
        return StatusPill.neutral('진행 완료');
      case 'CANCELLED':
        return StatusPill.danger('취소됨');
      default:
        return StatusPill.neutral(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PrismRadius.xs + 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
