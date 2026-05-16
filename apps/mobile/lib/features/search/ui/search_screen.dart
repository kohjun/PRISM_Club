import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/search_dto.dart';
import '../data/search_repository.dart';
import 'widgets/search_result_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.categorySlug});

  final String? initialQuery;
  final String? categorySlug;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery ?? '');
  Set<String> _types = const <String>{};
  String _query = '';
  Timer? _debounce;
  Future<SearchResponseDto>? _future;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _query = initial;
      _scheduleSearch(immediate: true);
    }
  }

  void _onChanged(String value) {
    _query = value.trim();
    _scheduleSearch();
  }

  void _fire() {
    setState(() {
      _loading = true;
      _future = ref
          .read(searchRepositoryProvider)
          .search(query: _query, types: _types);
    });
    _future!.whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _scheduleSearch({bool immediate = false}) {
    _debounce?.cancel();
    if (_query.isEmpty) {
      setState(() {
        _future = null;
        _loading = false;
      });
      return;
    }
    if (immediate) {
      _fire();
    } else {
      _debounce = Timer(const Duration(milliseconds: 300), _fire);
    }
  }

  void _setTypes(Set<String> next) {
    setState(() {
      _types = next;
    });
    _scheduleSearch(immediate: true);
  }

  void _useSuggestion(String s) {
    _controller.text = s;
    _controller.selection = TextSelection.collapsed(offset: s.length);
    _onChanged(s);
    _scheduleSearch(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _scheduleSearch(immediate: true),
          decoration: const InputDecoration(
            hintText: '소개팅 미션, 환승연애 ...',
            border: InputBorder.none,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/spaces');
            }
          },
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '지우기',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _TypeFilter(
            selected: _types,
            onChanged: _setTypes,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return _EmptyStateSuggestions(
        categorySlug: widget.categorySlug,
        onTap: _useSuggestion,
      );
    }
    if (_loading || _future == null) {
      return const LoadingView();
    }
    return FutureBuilder<SearchResponseDto>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          final e = snap.error;
          return ErrorView(
            message: e is ApiError ? e.message : '검색에 실패했어요.',
            onRetry: () => _scheduleSearch(immediate: true),
          );
        }
        final res = snap.data;
        if (res == null) return const SizedBox.shrink();
        if (res.totalHits == 0) {
          return _NoResults(
            query: res.query,
            categorySlug: widget.categorySlug,
            onSuggestion: _useSuggestion,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final g in res.groups)
              if (g.items.isNotEmpty) ...[
                _GroupHeader(type: g.type, count: g.items.length),
                const SizedBox(height: 8),
                for (final hit in g.items) ...[
                  SearchResultTile(hit: hit),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selected, required this.onChanged});
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('전체'),
              selected: selected.isEmpty,
              onSelected: (_) => onChanged(const <String>{}),
            ),
            for (final t in SearchEntityType.all) ...[
              const SizedBox(width: 6),
              ChoiceChip(
                label: Text(SearchEntityType.label(t)),
                selected: selected.contains(t),
                onSelected: (yes) {
                  final next = Set<String>.from(selected);
                  if (yes) {
                    next.add(t);
                  } else {
                    next.remove(t);
                  }
                  onChanged(next);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.type, required this.count});
  final String type;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(SearchEntityType.label(type),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 6),
        Text('($count)',
            style: const TextStyle(color: PrismColors.muted, fontSize: 12)),
      ],
    );
  }
}

class _EmptyStateSuggestions extends ConsumerWidget {
  const _EmptyStateSuggestions({required this.categorySlug, required this.onTap});
  final String? categorySlug;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sugs = ref.watch(searchSuggestionsProvider(categorySlug));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('인기 토픽', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          sugs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text(
              e is ApiError ? e.message : '추천어를 불러오지 못했어요.',
              style: const TextStyle(color: Colors.redAccent),
            ),
            data: (items) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      onPressed: () => onTap(s),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends ConsumerWidget {
  const _NoResults({
    required this.query,
    required this.categorySlug,
    required this.onSuggestion,
  });
  final String query;
  final String? categorySlug;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("'$query'에 대한 결과가 없어요.",
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          _EmptyStateSuggestions(
            categorySlug: categorySlug,
            onTap: onSuggestion,
          ),
        ],
      ),
    );
  }
}
