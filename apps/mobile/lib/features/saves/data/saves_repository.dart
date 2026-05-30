import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'saved_item_dto.dart';

class SavesRepository {
  SavesRepository(this._ref);
  final Ref _ref;

  Future<SavedItemListDto> list({String? type, String? collectionId}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/me/saves',
            queryParameters: {
              'type': ?type,
              'collection_id': ?collectionId,
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

  Future<List<SavedCollectionDto>> listCollections() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/me/collections');
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load collections',
          res.statusCode,
        );
      }
      final list = (res.data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(SavedCollectionDto.fromJson)
          .toList(growable: false);
      return list;
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<SavedCollectionDto> createCollection(String name) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .post<dynamic>('/me/collections', data: {'name': name});
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to create collection',
          res.statusCode,
        );
      }
      return SavedCollectionDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      final res =
          await _ref.read(dioProvider).delete<dynamic>('/me/collections/$id');
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to delete collection',
          res.statusCode,
        );
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> moveSave(String saveId, String? collectionId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/me/saves/$saveId/move',
        data: {'collection_id': collectionId},
      );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to move save',
          res.statusCode,
        );
      }
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

class SavedItemsFilter {
  const SavedItemsFilter({this.type, this.collectionId});
  final String? type;

  /// `null` = all collections (no filter)
  /// `'__none__'` = items without any collection
  /// a real UUID = that collection only
  final String? collectionId;

  @override
  bool operator ==(Object other) =>
      other is SavedItemsFilter &&
      other.type == type &&
      other.collectionId == collectionId;

  @override
  int get hashCode => Object.hash(type, collectionId);
}

final filteredSavedItemsProvider =
    FutureProvider.family<SavedItemListDto, SavedItemsFilter>(
  (ref, filter) => ref.read(savesRepositoryProvider).list(
        type: filter.type,
        collectionId: filter.collectionId,
      ),
);

final savedCollectionsProvider =
    FutureProvider<List<SavedCollectionDto>>((ref) {
  return ref.read(savesRepositoryProvider).listCollections();
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
