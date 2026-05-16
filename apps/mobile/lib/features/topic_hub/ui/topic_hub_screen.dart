import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../room/data/room_summary_dto.dart';
import '../data/topic_hub_dto.dart';
import '../data/topic_hub_repository.dart';

class TopicHubScreen extends ConsumerWidget {
  const TopicHubScreen({super.key, required this.categorySlug});
  final String categorySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(topicHubProvider(categorySlug));

    return Scaffold(
      appBar: AppBar(
        title: bundle.maybeWhen(
          data: (b) => Text(b.categoryName),
          orElse: () => const Text('Topic Hub'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/spaces/participant/categories'),
        ),
      ),
      body: bundle.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : 'Topic Hub를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(topicHubProvider(categorySlug)),
        ),
        data: (b) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(topicHubProvider(categorySlug)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HubHeader(bundle: b),
              const SizedBox(height: 24),
              _Section(
                title: '핵심 정보',
                children: b.blocks
                    .map((block) => _KnowledgeBlockCard(block: block))
                    .toList(),
              ),
              if (b.signals.isNotEmpty) ...[
                const SizedBox(height: 24),
                _Section(
                  title: '데이터 신호',
                  children: b.signals
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SignalRow(signal: s),
                          ))
                      .toList(),
                ),
              ],
              if (b.relatedEvents.isNotEmpty) ...[
                const SizedBox(height: 24),
                _Section(
                  title: '관련 이벤트',
                  children: b.relatedEvents
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: EventCardWidget(card: e),
                          ))
                      .toList(),
                ),
              ],
              if (b.relatedReferences.isNotEmpty) ...[
                const SizedBox(height: 24),
                _Section(
                  title: '인기 레퍼런스',
                  children: b.relatedReferences
                      .map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ReferenceCardWidget(reference: r),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              _RoomsSection(
                rooms: b.rooms,
                onCreateRoom: () => context.go(
                    '/categories/$categorySlug/rooms/new'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.bundle});
  final TopicHubBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bundle.hubTitle ?? bundle.categoryName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          bundle.hubSummary ?? bundle.categoryDescription ?? '',
          style: const TextStyle(color: PrismColors.muted),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _KnowledgeBlockCard extends StatelessWidget {
  const _KnowledgeBlockCard({required this.block});
  final KnowledgeBlockDto block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PrismColors.soft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _blockLabel(block.blockType),
                      style: const TextStyle(
                          fontSize: 11, color: PrismColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      block.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(block.body),
            ],
          ),
        ),
      ),
    );
  }

  String _blockLabel(String type) {
    switch (type) {
      case 'OVERVIEW':
        return '개요';
      case 'POPULAR_FORMAT':
        return '포맷';
      case 'RECOMMENDED_PARTY_SIZE':
        return '인원';
      case 'MOOD_TIPS':
        return '팁';
      case 'FAQ':
        return 'FAQ';
      case 'CHECKLIST':
        return '체크리스트';
      case 'WARNING':
        return '주의';
      default:
        return type;
    }
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});
  final TopicSignalDto signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PrismColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PrismColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined,
              size: 16, color: PrismColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(signal.title)),
          Text(
            signal.displayValue,
            style: const TextStyle(
                color: PrismColors.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RoomsSection extends StatelessWidget {
  const _RoomsSection({required this.rooms, required this.onCreateRoom});
  final List<RoomSummaryDto> rooms;
  final VoidCallback onCreateRoom;

  @override
  Widget build(BuildContext context) {
    final official = rooms.where((r) => !r.isUserCreated).toList();
    final user = rooms.where((r) => r.isUserCreated).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('방', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.icon(
              onPressed: onCreateRoom,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('방 만들기'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (official.isNotEmpty) ...[
          const _RoomGroupLabel(label: '기본 방'),
          for (final r in official) _RoomTile(room: r),
        ],
        if (user.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _RoomGroupLabel(label: '유저가 만든 방'),
          for (final r in user) _RoomTile(room: r),
        ],
      ],
    );
  }
}

class _RoomGroupLabel extends StatelessWidget {
  const _RoomGroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        style: const TextStyle(color: PrismColors.muted, fontSize: 12),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});
  final RoomSummaryDto room;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PrismColors.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              room.isUserCreated
                  ? Icons.person_outline
                  : Icons.forum_outlined,
              color: PrismColors.primary,
              size: 20,
            ),
          ),
          title: Text(room.name),
          subtitle: room.ownerNickname != null
              ? Text('${room.ownerNickname} · ${_roomTypeLabel(room.roomType)}',
                  style: const TextStyle(fontSize: 12))
              : Text(_roomTypeLabel(room.roomType),
                  style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: PrismColors.muted),
          onTap: () => context.go('/rooms/${room.slug}'),
        ),
      ),
    );
  }

  String _roomTypeLabel(String t) {
    switch (t) {
      case 'DISCUSSION':
        return '토론';
      case 'EVENT_REACTION':
        return '이벤트 반응';
      case 'REFERENCE':
        return '레퍼런스';
      case 'IDEA':
        return '아이디어';
      case 'RECRUITMENT':
        return '모집';
      case 'SOCIAL':
        return '소셜링';
      default:
        return t;
    }
  }
}
