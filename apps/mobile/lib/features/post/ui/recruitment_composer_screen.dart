import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../data/post_repository.dart';

/// Milestone 4: structured composer for RECRUITMENT-type posts. The form
/// posts to the same `POST /rooms/:slug/posts` endpoint with `post_type`
/// set to `'RECRUITMENT'`. Submit is enabled only when every required field
/// is non-empty and `capacity` parses as a positive integer.
class RecruitmentComposerScreen extends ConsumerStatefulWidget {
  const RecruitmentComposerScreen({super.key, required this.roomSlug});
  final String roomSlug;

  @override
  ConsumerState<RecruitmentComposerScreen> createState() =>
      _RecruitmentComposerScreenState();
}

class _RecruitmentComposerScreenState
    extends ConsumerState<RecruitmentComposerScreen> {
  final _role = TextEditingController();
  final _schedule = TextEditingController();
  final _location = TextEditingController();
  final _compensation = TextEditingController();
  final _capacity = TextEditingController();
  final _applicationMethod = TextEditingController();
  final _body = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _role,
      _schedule,
      _location,
      _compensation,
      _capacity,
      _applicationMethod,
      _body,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _role,
      _schedule,
      _location,
      _compensation,
      _capacity,
      _applicationMethod,
      _body,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _parsedCapacity {
    final raw = _capacity.text.trim();
    final n = int.tryParse(raw);
    if (n == null || n <= 0) return null;
    return n;
  }

  bool get _canSubmit =>
      _role.text.trim().isNotEmpty &&
      _schedule.text.trim().isNotEmpty &&
      _location.text.trim().isNotEmpty &&
      _compensation.text.trim().isNotEmpty &&
      _applicationMethod.text.trim().isNotEmpty &&
      _body.text.trim().isNotEmpty &&
      _parsedCapacity != null;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    try {
      final fields = CreateRecruitmentFields(
        role: _role.text.trim(),
        schedule: _schedule.text.trim(),
        location: _location.text.trim(),
        compensation: _compensation.text.trim(),
        capacity: _parsedCapacity!,
        applicationMethod: _applicationMethod.text.trim(),
      );
      final post = await ref.read(postRepositoryProvider).create(
            widget.roomSlug,
            body: _body.text.trim(),
            postType: 'RECRUITMENT',
            recruitmentFields: fields,
          );
      ref.invalidate(timelineProvider(widget.roomSlug));
      if (mounted) context.go('/posts/${post.id}');
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('모집 글 작성 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스태프 모집'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/rooms/${widget.roomSlug}'),
        ),
        actions: [
          TextButton(
            onPressed: (!_canSubmit || _submitting) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('게시'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '필수 항목을 모두 작성하면 게시할 수 있어요.',
            style: TextStyle(color: PrismColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _Field(label: '역할', controller: _role, hint: '예: 진행 어시스턴트'),
          _Field(label: '일정', controller: _schedule, hint: '예: 5/30 19:00–22:00'),
          _Field(label: '장소', controller: _location, hint: '예: 홍대 스튜디오'),
          _Field(label: '보상', controller: _compensation, hint: '예: 8만원 + 식대'),
          _Field(
            label: '인원',
            controller: _capacity,
            hint: '양의 정수',
            keyboardType: TextInputType.number,
          ),
          _Field(
            label: '지원 방법',
            controller: _applicationMethod,
            hint: 'DM, 이메일 등',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Text('본문', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(
              hintText: '모집 배경, 우대 사항, 행사 정보를 짧게 적어주세요.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
