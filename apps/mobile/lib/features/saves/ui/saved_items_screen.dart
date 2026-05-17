import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../data/saved_item_dto.dart';
import '../data/saves_repository.dart';

class SavedItemsScreen extends ConsumerStatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  ConsumerState<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends ConsumerState<SavedItemsScreen> {
  String? _selectedType; // null = all

  @override
  Widget build(BuildContext context) {
    final saves = ref.watch(savedItemsProvider(_selectedType));

    return Scaffold(
      appBar: AppBar(title: const Text('저장한 항목')),
      body: Column(
        children: [
          _TypeChipRow(
            selected: _selectedType,
            onSelect: (type) => setState(() => _selectedType = type),
          ),
          Expanded(
            child: saves.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e is ApiError ? e.message : '저장 목록을 불러오지 못했어요.',
                onRetry: () => ref.invalidate(savedItemsProvider(_selectedType)),
              ),
              data: (list) => list.items.isEmpty
                  ? const EmptyView(message: '저장한 항목이 없어요')
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(savedItemsProvider(_selectedType)),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) => _SavedItemTile(
                          item: list.items[index],
                          onUnsave: () => _unsave(list.items[index]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unsave(SavedItemDto item) async {
    try {
      await ref
          .read(savesRepositoryProvider)
          .toggle(item.targetType, item.targetId);
      ref.invalidate(savedItemsProvider(_selectedType));
      ref.invalidate(savedItemsProvider(null));
      ref.invalidate(saveStateProvider('${item.targetType}:${item.targetId}'));
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 취소 실패: ${e.message}')),
        );
      }
    }
  }
}

class _TypeChipRow extends StatelessWidget {
  const _TypeChipRow({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  static const _types = [
    (null, '전체'),
    ('POST', '글'),
    ('REFERENCE', '레퍼런스'),
    ('EVENT_CARD', '이벤트'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final (type, label) in _types) ...[
            ChoiceChip(
              label: Text(label),
              selected: selected == type,
              onSelected: (_) => onSelect(type),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SavedItemTile extends StatelessWidget {
  const _SavedItemTile({required this.item, required this.onUnsave});
  final SavedItemDto item;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final post = item.postTarget;
    final reference = item.referenceTarget;
    final eventCard = item.eventCardTarget;

    final trailing = IconButton(
      icon: const Icon(Icons.bookmark, size: 20),
      tooltip: '저장 취소',
      onPressed: onUnsave,
    );

    if (post != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PostCardWidget(
              post: post,
              onTap: () => context.go('/posts/${post.id}'),
            ),
          ),
          trailing,
        ],
      );
    }
    if (reference != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ReferenceCardWidget(reference: reference)),
          trailing,
        ],
      );
    }
    if (eventCard != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: EventCardWidget(
              card: eventCard,
              onTap: () => context.go('/events/${eventCard.id}'),
            ),
          ),
          trailing,
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
