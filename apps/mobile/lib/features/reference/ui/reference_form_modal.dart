import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../data/reference_dto.dart';
import '../data/reference_repository.dart';

const _kTypes = <String, String>{
  'TV_SHOW': '예능 프로그램',
  'YOUTUBE': '유튜브',
  'GAME_RULE': '게임 룰',
  'ARTICLE': '기사',
  'IDEA': '아이디어',
  'OTHER': '기타',
};

/// Bottom-sheet form. Manual entry only — no URL scraping (per plan §8).
Future<ReferenceDto?> showReferenceFormModal(BuildContext context) {
  return showModalBottomSheet<ReferenceDto?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PrismColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: const _ReferenceFormSheet(),
    ),
  );
}

class _ReferenceFormSheet extends ConsumerStatefulWidget {
  const _ReferenceFormSheet();

  @override
  ConsumerState<_ReferenceFormSheet> createState() =>
      _ReferenceFormSheetState();
}

class _ReferenceFormSheetState extends ConsumerState<_ReferenceFormSheet> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _source = TextEditingController();
  final _thumbnail = TextEditingController();
  final _summary = TextEditingController();
  String _type = 'TV_SHOW';
  bool _submitting = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final created = await ref.read(referenceRepositoryProvider).create(
            url: _url.text.trim(),
            title: _title.text.trim(),
            type: _type,
            sourceName: _source.text.trim(),
            thumbnailUrl: _thumbnail.text.trim(),
            summary: _summary.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(created);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('레퍼런스 저장 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _source.dispose();
    _thumbnail.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('레퍼런스 추가',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _url,
              decoration: const InputDecoration(
                  labelText: 'URL', border: OutlineInputBorder()),
              keyboardType: TextInputType.url,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'URL을 입력해 주세요.';
                final uri = Uri.tryParse(value);
                if (uri == null || !uri.isAbsolute) return '유효한 URL이 아닙니다.';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: '제목', border: OutlineInputBorder()),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? '제목을 입력해 주세요.' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                  labelText: '유형', border: OutlineInputBorder()),
              items: _kTypes.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _source,
              decoration: const InputDecoration(
                  labelText: '출처 (선택)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _thumbnail,
              decoration: const InputDecoration(
                  labelText: '썸네일 URL (선택)', border: OutlineInputBorder()),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _summary,
              decoration: const InputDecoration(
                  labelText: '요약 (선택)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('레퍼런스 저장'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
