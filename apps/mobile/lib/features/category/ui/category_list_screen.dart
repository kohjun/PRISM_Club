import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
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
                onRefresh: () async =>
                    ref.invalidate(categoryListProvider(spaceSlug)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CategoryCard(cat: items[i]),
                ),
              ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.cat});
  final CategoryDto cat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/categories/${cat.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: PrismColors.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.topic_outlined,
                        color: PrismColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cat.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: PrismColors.muted),
                ],
              ),
              if (cat.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  cat.description!,
                  style: const TextStyle(color: PrismColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
