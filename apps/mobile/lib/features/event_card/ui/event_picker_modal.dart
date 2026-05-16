import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/event_card_dto.dart';
import '../data/event_repository.dart';
import '../data/external_event_dto.dart';

/// Bottom-sheet picker. Returns the upserted EventCard on selection, or null
/// if the user cancels.
Future<EventCardDto?> showEventPickerModal(BuildContext context) {
  return showModalBottomSheet<EventCardDto?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PrismColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _EventPickerSheet(),
    ),
  );
}

class _EventPickerSheet extends ConsumerStatefulWidget {
  const _EventPickerSheet();

  @override
  ConsumerState<_EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends ConsumerState<_EventPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  late Future<List<ExternalEventDto>> _future;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(eventRepositoryProvider).search('');
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _future = ref.read(eventRepositoryProvider).search(value);
      });
    });
  }

  Future<void> _select(ExternalEventDto event) async {
    setState(() => _converting = true);
    try {
      final card =
          await ref.read(eventRepositoryProvider).upsert(event.externalEventId);
      if (mounted) Navigator.of(context).pop(card);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이벤트 추가 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: PrismColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('이벤트 검색',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: '제목, 장소, 지역으로 검색',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<ExternalEventDto>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snap.hasError) {
                final e = snap.error;
                return ErrorView(
                  message: e is ApiError ? e.message : '검색 실패',
                  onRetry: () => _onChanged(_controller.text),
                );
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return const EmptyView(message: '검색 결과가 없어요.');
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ExternalEventTile(
                  event: items[i],
                  disabled: _converting,
                  onTap: () => _select(items[i]),
                ),
              );
            },
          ),
        ),
        if (_converting)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _ExternalEventTile extends StatelessWidget {
  const _ExternalEventTile({
    required this.event,
    required this.onTap,
    required this.disabled,
  });
  final ExternalEventDto event;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${event.startsAt.year}.${event.startsAt.month.toString().padLeft(2, '0')}.${event.startsAt.day.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        title: Text(event.title),
        subtitle: Text('$dateStr · ${event.venueName} · ${event.region}',
            style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: event.isCompleted ? PrismColors.border : PrismColors.soft,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            event.isCompleted ? '완료' : '예정',
            style: TextStyle(
              fontSize: 10,
              color: event.isCompleted ? PrismColors.muted : PrismColors.primary,
            ),
          ),
        ),
        onTap: disabled ? null : onTap,
      ),
    );
  }
}
