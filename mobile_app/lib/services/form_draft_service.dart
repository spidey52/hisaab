import '../core/storage/app_storage.dart';

abstract class FormDraftService {
  Future<Map<String, dynamic>?> read({
    required String kind,
    required String id,
  });

  Future<void> save({
    required String kind,
    required String id,
    required Map<String, dynamic> payload,
  });

  Future<void> clear({required String kind, required String id});
}

class EncryptedFormDraftService implements FormDraftService {
  const EncryptedFormDraftService(this._storage);

  final AppStorage _storage;

  @override
  Future<Map<String, dynamic>?> read({
    required String kind,
    required String id,
  }) => _storage.readDraft(kind: kind, draftId: id);

  @override
  Future<void> save({
    required String kind,
    required String id,
    required Map<String, dynamic> payload,
  }) => _storage.saveDraft(kind: kind, draftId: id, payload: payload);

  @override
  Future<void> clear({required String kind, required String id}) =>
      _storage.clearDraft(kind: kind, draftId: id);
}
