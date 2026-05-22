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
  String? _selectedCollectionId; // null = all collections

  SavedItemsFilter get _filter =>
      SavedItemsFilter(type: _selectedType, collectionId: _selectedCollectionId);

  @override
  Widget build(BuildContext context) {
    final saves = ref.watch(filteredSavedItemsProvider(_filter));
    final collections = ref.watch(savedCollectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('저장한 항목'),
        actions: [
          IconButton(
            tooltip: '새 폴더',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _promptCreateCollection(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _CollectionTabRow(
            collections: collections,
            selected: _selectedCollectionId,
            onSelect: (id) => setState(() => _selectedCollectionId = id),
          ),
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
                onRetry: () => ref.invalidate(filteredSavedItemsProvider(_filter)),
              ),
              data: (list) => list.items.isEmpty
                  ? const EmptyView(message: '저장한 항목이 없어요')
                  : RefreshIndicator(
                      color: PrismColors.pp600,
                      onRefresh: () async {
                        ref.invalidate(filteredSavedItemsProvider(_filter));
                        ref.invalidate(savedCollectionsProvider);
                      },
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
                          onMove: () => _moveItem(list.items[index]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptCreateCollection(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 폴더'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(hintText: '폴더 이름 (1~50자)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(savesRepositoryProvider).createCollection(name);
      ref.invalidate(savedCollectionsProvider);
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('폴더 생성 실패: ${e.message}')),
      );
    }
  }

  Future<void> _moveItem(SavedItemDto item) async {
    final collections = await ref.read(savedCollectionsProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<_MoveChoice>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('폴더 없음'),
              onTap: () =>
                  Navigator.of(ctx).pop(const _MoveChoice(collectionId: null)),
            ),
            const Divider(height: 1),
            for (final c in collections)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(c.name),
                subtitle: Text('${c.itemCount}개'),
                onTap: () => Navigator.of(ctx)
                    .pop(_MoveChoice(collectionId: c.id)),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await ref
          .read(savesRepositoryProvider)
          .moveSave(item.id, picked.collectionId);
      ref.invalidate(filteredSavedItemsProvider(_filter));
      ref.invalidate(savedCollectionsProvider);
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이동 실패: ${e.message}')),
      );
    }
  }

  Future<void> _unsave(SavedItemDto item) async {
    try {
      await ref
          .read(savesRepositoryProvider)
          .toggle(item.targetType, item.targetId);
      ref.invalidate(filteredSavedItemsProvider(_filter));
      ref.invalidate(savedCollectionsProvider);
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

class _MoveChoice {
  const _MoveChoice({required this.collectionId});
  final String? collectionId;
}

class _CollectionTabRow extends StatelessWidget {
  const _CollectionTabRow({
    required this.collections,
    required this.selected,
    required this.onSelect,
  });
  final AsyncValue<List<SavedCollectionDto>> collections;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final list = collections.maybeWhen(
      data: (data) => data,
      orElse: () => const <SavedCollectionDto>[],
    );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.xl,
          vertical: PrismSpacing.sm,
        ),
        children: [
          _CollectionChip(
            label: '모든 폴더',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          _CollectionChip(
            label: '폴더 없음',
            selected: selected == '__none__',
            onTap: () => onSelect('__none__'),
          ),
          const SizedBox(width: 8),
          for (final c in list) ...[
            _CollectionChip(
              label: '${c.name} (${c.itemCount})',
              selected: selected == c.id,
              onTap: () => onSelect(c.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
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
      label: '$label 폴더',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.cardPad,
              vertical: 6,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? PrismColors.pp600 : PrismColors.bgTint,
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
  const _SavedItemTile({
    required this.item,
    required this.onUnsave,
    required this.onMove,
  });
  final SavedItemDto item;
  final VoidCallback onUnsave;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final post = item.postTarget;
    final reference = item.referenceTarget;
    final eventCard = item.eventCardTarget;

    final trailing = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.bookmark, size: 22, color: PrismColors.pp700),
          tooltip: '저장 취소',
          onPressed: onUnsave,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline,
              size: 20, color: PrismColors.ink2),
          tooltip: '폴더 이동',
          onPressed: onMove,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      ],
    );

    if (post != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PostCardWidget(
              post: post,
              onTap: () => context.push('/posts/${post.id}'),
              onAuthorTap: (uid) => context.push('/users/$uid'),
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
              onTap: () => context.push('/events/${eventCard.id}'),
            ),
          ),
          trailing,
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
