import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'saved_item_dto.dart';

class SavesRepository {
  SavesRepository(this._ref);
  final Ref _ref;

  Future<SavedItemListDto> list({String? type}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/me/saves',
            queryParameters: {
              if (type != null) 'type': type,
            },
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load saved items', res.statusCode);
      }
      return SavedItemListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ToggleSaveResultDto> toggle(String targetType, String targetId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/me/saves',
            data: {'target_type': targetType, 'target_id': targetId},
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to toggle save', res.statusCode);
      }
      return ToggleSaveResultDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final savesRepositoryProvider =
    Provider<SavesRepository>((ref) => SavesRepository(ref));

// Null means "all types", a string value filters by type.
final savedItemsProvider =
    FutureProvider.family<SavedItemListDto, String?>((ref, type) {
  return ref.read(savesRepositoryProvider).list(type: type);
});

// Key format: "TYPE:targetId" e.g. "POST:abc-123"
class SaveNotifier extends FamilyAsyncNotifier<bool, String> {
  @override
  Future<bool> build(String arg) async {
    final idx = arg.indexOf(':');
    final type = arg.substring(0, idx);
    final id = arg.substring(idx + 1);
    final saves = await ref.read(savedItemsProvider(type).future);
    return saves.items.any((item) => item.targetId == id);
  }

  Future<void> toggle() async {
    final idx = arg.indexOf(':');
    final type = arg.substring(0, idx);
    final id = arg.substring(idx + 1);
    final result = await ref.read(savesRepositoryProvider).toggle(type, id);
    state = AsyncData(result.saved);
    ref.invalidate(savedItemsProvider(type));
  }
}

final saveStateProvider =
    AsyncNotifierProvider.family<SaveNotifier, bool, String>(
  SaveNotifier.new,
);
