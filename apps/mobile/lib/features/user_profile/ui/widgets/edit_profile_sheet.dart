import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/api_error.dart';
import '../../../auth/data/me_repository.dart';
import '../../../media/data/media_repository.dart';
import '../../data/user_profile_dto.dart';
import '../../data/user_profile_repository.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.userId,
    required this.initialProfile,
    required this.initialNickname,
    required this.initialAvatarUrl,
  });

  final String userId;
  final ProfileSubDto initialProfile;
  final String initialNickname;
  final String? initialAvatarUrl;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required ProfileSubDto initialProfile,
    required String initialNickname,
    required String? initialAvatarUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditProfileSheet(
          userId: userId,
          initialProfile: initialProfile,
          initialNickname: initialNickname,
          initialAvatarUrl: initialAvatarUrl,
        ),
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
  late final TextEditingController _nicknameCtrl;
  late List<String> _interests;
  late String? _avatarUrl;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.initialProfile.bio ?? '');
    _regionCtrl =
        TextEditingController(text: widget.initialProfile.region ?? '');
    _newInterestCtrl = TextEditingController();
    _nicknameCtrl = TextEditingController(text: widget.initialNickname);
    _interests = [...widget.initialProfile.interests];
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _regionCtrl.dispose();
    _newInterestCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar || _saving) return;
    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _uploadingAvatar = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _uploadingAvatar = false;
          _error = '파일을 읽지 못했어요.';
        });
        return;
      }
      final media = await ref.read(mediaRepositoryProvider).uploadImage(
            bytes: bytes,
            filename: file.name,
          );
      if (!mounted) return;
      setState(() {
        _avatarUrl = media.displayUrl;
        _uploadingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _error = e is ApiError ? e.message : e.toString();
      });
    }
  }

  void _clearAvatar() {
    setState(() => _avatarUrl = null);
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
    if (_saving || _uploadingAvatar) return;
    final newNickname = _nicknameCtrl.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final avatarChanged = _avatarUrl != widget.initialAvatarUrl;
      await ref.read(userProfileRepositoryProvider).updateMyProfile(
            UpdateProfileInput(
              bio: _bioCtrl.text.trim(),
              region: _regionCtrl.text.trim(),
              interests: _interests,
              nickname: newNickname == widget.initialNickname ? null : newNickname,
              avatarUrl: avatarChanged ? _avatarUrl : null,
              clearAvatar: avatarChanged && _avatarUrl == null,
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
          Row(
            children: [
              _AvatarPreview(url: _avatarUrl, nickname: _nicknameCtrl.text),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _uploadingAvatar ? null : _pickAvatar,
                      icon: _uploadingAvatar
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined, size: 16),
                      label:
                          Text(_uploadingAvatar ? '업로드 중...' : '아바타 변경'),
                    ),
                    if (_avatarUrl != null)
                      TextButton.icon(
                        onPressed: _uploadingAvatar ? null : _clearAvatar,
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('아바타 제거'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          minimumSize: const Size(0, 28),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nicknameCtrl,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: '닉네임',
              helperText: '한글/영문/숫자/_, 2~20자',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
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

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.url, required this.nickname});
  final String? url;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final fallback = nickname.isEmpty ? '?' : nickname.characters.first;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PrismColors.muted.withValues(alpha: 0.15),
        image: url != null
            ? DecorationImage(
                image: NetworkImage(url!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              fallback,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: PrismColors.muted,
              ),
            )
          : null,
    );
  }
}
