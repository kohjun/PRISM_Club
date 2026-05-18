import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
      backgroundColor: PrismColors.bg,
      appBar: AppBar(
        backgroundColor: PrismColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 8,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          color: PrismColors.ink2,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/spaces');
            }
          },
        ),
        title: _SearchField(
          controller: _controller,
          autofocus:
              widget.initialQuery == null || widget.initialQuery!.isEmpty,
          onChanged: _onChanged,
          onSubmitted: () => _scheduleSearch(immediate: true),
          onClear: _query.isEmpty
              ? null
              : () {
                  _controller.clear();
                  _onChanged('');
                },
        ),
        actions: const [SizedBox(width: PrismSpacing.sm)],
      ),
      body: Column(
        children: [
          _TypeFilter(selected: _types, onChanged: _setTypes),
          const Divider(height: 1, color: PrismColors.divider),
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
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.xl,
            PrismSpacing.md,
            PrismSpacing.xl,
            PrismSpacing.xl4,
          ),
          children: [
            for (final g in res.groups)
              if (g.items.isNotEmpty) ...[
                _GroupHeader(type: g.type, count: g.items.length),
                const SizedBox(height: PrismSpacing.sm),
                for (final hit in g.items) ...[
                  SearchResultTile(hit: hit),
                  const SizedBox(height: PrismSpacing.sm),
                ],
                const SizedBox(height: PrismSpacing.md),
              ],
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: PrismColors.bgTint,
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.cardPad),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: PrismColors.ink3),
          const SizedBox(width: PrismSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              style: const TextStyle(
                fontSize: 14,
                letterSpacing: -0.2,
                color: PrismColors.ink1,
              ),
              decoration: const InputDecoration(
                hintText: 'Topic Hub · 방 · 사람 · 이벤트',
                hintStyle: TextStyle(
                  color: PrismColors.ink4,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              color: PrismColors.ink3,
              tooltip: '검색어 지우기',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 44,
                height: 44,
              ),
            ),
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.cardPad,
        PrismSpacing.sm,
        PrismSpacing.cardPad,
        PrismSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(
              label: '전체',
              selected: selected.isEmpty,
              onTap: () => onChanged(const <String>{}),
            ),
            for (final t in SearchEntityType.all) ...[
              const SizedBox(width: 6),
              _Chip(
                label: SearchEntityType.label(t),
                selected: selected.contains(t),
                onTap: () {
                  final next = Set<String>.from(selected);
                  if (next.contains(t)) {
                    next.remove(t);
                  } else {
                    next.add(t);
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.type, required this.count});
  final String type;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          SearchEntityType.label(type),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: PrismColors.ink1,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(
            color: PrismColors.ink4,
            fontSize: 12,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _EmptyStateSuggestions extends ConsumerWidget {
  const _EmptyStateSuggestions({
    required this.categorySlug,
    required this.onTap,
  });
  final String? categorySlug;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sugs = ref.watch(searchSuggestionsProvider(categorySlug));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.lg,
        PrismSpacing.xl,
        PrismSpacing.xl4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '인기 토픽',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: PrismColors.ink1,
            ),
          ),
          const SizedBox(height: PrismSpacing.md),
          sugs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: PrismColors.pp600,
                backgroundColor: PrismColors.pp50,
              ),
            ),
            error: (e, _) => Text(
              e is ApiError ? e.message : '추천어를 불러오지 못했어요.',
              style: const TextStyle(color: PrismColors.danger),
            ),
            data: (items) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (s) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onTap(s),
                        borderRadius:
                            BorderRadius.circular(PrismRadius.pill),
                        child: Semantics(
                          button: true,
                          label: '추천 검색 $s',
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 44,
                              minWidth: 44,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: PrismSpacing.cardPad,
                              vertical: 10,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PrismColors.pp50,
                              borderRadius:
                                  BorderRadius.circular(PrismRadius.pill),
                              border: Border.all(color: PrismColors.pp100),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: PrismColors.pp700,
                              ),
                            ),
                          ),
                        ),
                      ),
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
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.lg,
        PrismSpacing.xl,
        PrismSpacing.xl4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "'$query'에 대한 결과가 없어요.",
            style: const TextStyle(
              fontSize: 14,
              color: PrismColors.ink2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: PrismSpacing.lg),
          Expanded(
            child: _EmptyStateSuggestions(
              categorySlug: categorySlug,
              onTap: onSuggestion,
            ),
          ),
        ],
      ),
    );
  }
}
