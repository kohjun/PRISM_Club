import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
          const Divider(height: 1, color: PrismColors.divider),
          Expanded(
            child: saves.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e is ApiError ? e.message : '저장 목록을 불러오지 못했어요.',
                onRetry: () =>
                    ref.invalidate(savedItemsProvider(_selectedType)),
              ),
              data: (list) => list.items.isEmpty
                  ? const EmptyView(message: '저장한 항목이 없어요')
                  : RefreshIndicator(
                      color: PrismColors.pp600,
                      onRefresh: () async => ref
                          .invalidate(savedItemsProvider(_selectedType)),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          PrismSpacing.xl,
                          PrismSpacing.md,
                          PrismSpacing.xl,
                          PrismSpacing.xl4,
                        ),
                        itemCount: list.items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: PrismSpacing.md),
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
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.xl,
          vertical: PrismSpacing.sm,
        ),
        children: [
          for (var i = 0; i < _types.length; i++) ...[
            _Chip(
              label: _types[i].$2,
              selected: selected == _types[i].$1,
              onTap: () => onSelect(_types[i].$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$label 필터',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 44,
              minWidth: 44,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.cardPad,
              vertical: 8,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? PrismColors.ink1 : PrismColors.bgTint,
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : PrismColors.ink2,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
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

    final trailing = Padding(
      padding: const EdgeInsets.only(top: PrismSpacing.sm),
      child: IconButton(
        icon: const Icon(Icons.bookmark, size: 22, color: PrismColors.pp700),
        tooltip: '저장 취소',
        onPressed: onUnsave,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      ),
    );

    if (post != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PostCardWidget(
              post: post,
              onTap: () => context.go('/posts/${post.id}'),
              onAuthorTap: (uid) => context.go('/users/$uid'),
            ),
          ),
          trailing,
        ],
      );
    }
    if (reference != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: ReferenceCardWidget(reference: reference)),
          trailing,
        ],
      );
    }
    if (eventCard != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
