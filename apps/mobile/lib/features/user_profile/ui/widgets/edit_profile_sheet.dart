import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/api_error.dart';
import '../../../auth/data/me_repository.dart';
import '../../data/user_profile_dto.dart';
import '../../data/user_profile_repository.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.userId,
    required this.initialProfile,
  });

  final String userId;
  final ProfileSubDto initialProfile;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required ProfileSubDto initialProfile,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditProfileSheet(
            userId: userId, initialProfile: initialProfile),
      ),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _bioCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _newInterestCtrl;
  late List<String> _interests;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.initialProfile.bio ?? '');
    _regionCtrl =
        TextEditingController(text: widget.initialProfile.region ?? '');
    _newInterestCtrl = TextEditingController();
    _interests = [...widget.initialProfile.interests];
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _regionCtrl.dispose();
    _newInterestCtrl.dispose();
    super.dispose();
  }

  void _addInterest() {
    final v = _newInterestCtrl.text.trim().toLowerCase();
    if (v.isEmpty) return;
    if (v.length > 30) return;
    if (_interests.length >= 10) return;
    if (_interests.contains(v)) {
      _newInterestCtrl.clear();
      return;
    }
    setState(() {
      _interests.add(v);
      _newInterestCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(userProfileRepositoryProvider).updateMyProfile(
            UpdateProfileInput(
              bio: _bioCtrl.text.trim(),
              region: _regionCtrl.text.trim(),
              interests: _interests,
            ),
          );
      ref.invalidate(userProfileProvider(widget.userId));
      ref.invalidate(meProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e is ApiError ? e.message : e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('프로필 편집',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 16),
          TextField(
            controller: _bioCtrl,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '자기소개',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regionCtrl,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: '지역',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('관심사 (최대 10개)',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._interests.map((it) => InputChip(
                    label: Text(it),
                    onDeleted: () => setState(() => _interests.remove(it)),
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newInterestCtrl,
                  decoration: const InputDecoration(
                    hintText: '관심사 추가',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addInterest(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: PrismColors.primary),
                onPressed: _addInterest,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '저장 중...' : '저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
