import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/topic_block.dart';
import '../data/category_dto.dart';
import '../data/category_repository.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key, required this.spaceSlug});
  final String spaceSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoryListProvider(spaceSlug));

    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/spaces'),
        ),
      ),
      body: cats.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '카테고리를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(categoryListProvider(spaceSlug)),
        ),
        data: (items) => items.isEmpty
            ? const EmptyView(message: '아직 카테고리가 없어요.')
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async =>
                    ref.invalidate(categoryListProvider(spaceSlug)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(PrismSpacing.xl),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PrismSpacing.md),
                  itemBuilder: (context, i) => _CategoryCard(
                    cat: items[i],
                    spaceSlug: spaceSlug,
                  ),
                ),
              ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.cat, required this.spaceSlug});
  final CategoryDto cat;
  final String spaceSlug;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        onTap: () => context.go(
          '/categories/${cat.slug}?spaceSlug=${Uri.encodeQueryComponent(spaceSlug)}',
        ),
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.lg),
          child: Row(
            children: [
              TopicBlock(label: cat.name, size: 44),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '# ${cat.name}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: PrismColors.ink1,
                      ),
                    ),
                    if (cat.description != null && cat.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        cat.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PrismColors.ink3,
                          fontSize: 12.5,
                          height: 1.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: PrismSpacing.sm),
              const Icon(Icons.chevron_right, color: PrismColors.ink4),
            ],
          ),
        ),
      ),
    );
  }
}
