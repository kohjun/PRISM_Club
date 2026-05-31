import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../widgets/state_views.dart';
import '../data/memories_dto.dart';
import '../data/memories_repository.dart';

/// P6.11 — full "오늘의 기록" timeline. Each row taps through to the
/// underlying surface via its deep link (room / topic hub / event).
class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayMemoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 기록')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '오늘의 기록을 불러오지 못했어요: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PrismColors.muted),
            ),
          ),
        ),
        data: (memories) {
          if (memories.isEmpty) {
            return const EmptyView(
              message: '오늘 떠오를 기록이 아직 없어요.\n방을 팔로우하고 지식을 남겨 보세요!',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: memories.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _MemoryTile(item: memories.items[i]),
          );
        },
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.item});
  final MemoryItemDto item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PrismColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('memory-${item.kind}-${item.yearsAgo}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(item.deepLink),
        child: Container(
          padding: const EdgeInsets.all(PrismSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PrismColors.border, width: 0.6),
          ),
          child: Row(
            children: [
              _KindIcon(kind: item.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PrismColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PrismColors.ink1,
                        height: 1.35,
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
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (kind) {
      case 'ROOM_FOLLOW':
        icon = Icons.forum_outlined;
        break;
      case 'CONTRIBUTION_APPROVED':
        icon = Icons.verified_outlined;
        break;
      case 'EVENT_RSVP':
        icon = Icons.event_outlined;
        break;
      default:
        icon = Icons.auto_awesome;
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: PrismColors.pp50,
      child: Icon(icon, size: 16, color: PrismColors.pp700),
    );
  }
}
