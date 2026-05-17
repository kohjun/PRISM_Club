import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/event_detail_dto.dart';

/// Bottom sheet that asks "어느 방에 작성하시겠어요?" when an event has more than
/// one eligible room. Returns the chosen room's slug or null on dismiss.
///
/// If [eligibleRooms] is empty, callers should fall back to
/// `defaultComposeRoomSlug` or disable the CTA entirely — this widget is
/// only invoked when there is at least one related room.
Future<String?> showComposeRoomPicker(
  BuildContext context, {
  required List<RelatedRoomDto> eligibleRooms,
  String? defaultSlug,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: PrismColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: PrismColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '어느 방에 작성할까요?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              '이 이벤트와 연결된 방 중 하나를 골라 주세요.',
              style: TextStyle(color: PrismColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final r in eligibleRooms)
              _RoomTile(
                room: r,
                isDefault: r.slug == defaultSlug,
                onTap: () => Navigator.of(sheetContext).pop(r.slug),
              ),
          ],
        ),
      ),
    ),
  );
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.isDefault,
    required this.onTap,
  });
  final RelatedRoomDto room;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDefault ? PrismColors.soft : PrismColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: PrismColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  room.origin == 'USER'
                      ? Icons.person_outline
                      : Icons.forum_outlined,
                  color: PrismColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (isDefault)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Text(
                                '추천',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: PrismColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        room.relation == 'PIN'
                            ? '이 이벤트를 대표 자료로 고정'
                            : '이 이벤트가 첨부된 글이 있는 방',
                        style: const TextStyle(
                          color: PrismColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: PrismColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
