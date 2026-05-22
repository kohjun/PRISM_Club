import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
      if (mounted) {
        // Replace the composer with the new post detail. canPop+push
        // would leave the composer in the stack; using replace keeps
        // back-from-detail returning to the room timeline directly.
        if (context.canPop()) context.pop();
        context.push('/posts/${post.id}');
      }
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
          tooltip: '닫기',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/rooms/${widget.roomSlug}'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.sm,
              vertical: 8,
            ),
            child: FilledButton(
              onPressed: (!_canSubmit || _submitting) ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: PrismColors.pp600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: PrismColors.bgTint,
                disabledForegroundColor: PrismColors.ink4,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '게시',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.lg,
          PrismSpacing.xl,
          PrismSpacing.xl4,
        ),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.md,
              vertical: PrismSpacing.md,
            ),
            decoration: BoxDecoration(
              color: PrismColors.pp50,
              borderRadius: BorderRadius.circular(PrismRadius.md),
              border: Border.all(color: PrismColors.pp100),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: PrismColors.pp700),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '필수 항목을 모두 작성하면 게시할 수 있어요.',
                    style: TextStyle(
                      color: PrismColors.ink2,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrismSpacing.lg),
          _FieldGroup(
            title: '모집 항목',
            children: [
              _Field(label: '역할', controller: _role, hint: '예: 진행 어시스턴트'),
              _Field(
                  label: '일정',
                  controller: _schedule,
                  hint: '예: 5/30 19:00–22:00'),
              _Field(
                  label: '장소', controller: _location, hint: '예: 홍대 스튜디오'),
              _Field(
                  label: '보상',
                  controller: _compensation,
                  hint: '예: 8만원 + 식대'),
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
            ],
          ),
          const SizedBox(height: PrismSpacing.lg),
          _FieldGroup(
            title: '본문',
            children: [
              TextField(
                controller: _body,
                maxLines: 6,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText: '모집 배경, 우대 사항, 행사 정보를 짧게 적어주세요.',
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
        ],
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.cardPad,
        PrismSpacing.md,
        PrismSpacing.cardPad,
        PrismSpacing.md,
      ),
      decoration: BoxDecoration(
        color: PrismColors.bg,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        border: Border.all(color: PrismColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: PrismColors.ink2,
            ),
          ),
          const SizedBox(height: PrismSpacing.md),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const SizedBox(height: PrismSpacing.md),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PrismColors.ink3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
