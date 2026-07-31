import 'dart:async';

import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/storage/app_storage.dart';
import '../../core/sync/sync_coordinator.dart';
import '../../data/repositories/auth_repository.dart';
import '../ledger/ledger_controller.dart';

class AuthController extends GetxController {
  AuthController(
    this._repository,
    this._ledger,
    this._storage,
    this._api,
    this._sync,
  );

  final AuthRepository _repository;
  final LedgerController _ledger;
  final AppStorage _storage;
  final ApiClient _api;
  final SyncCoordinator _sync;

  final busy = false.obs;
  final errorMessage = RxnString();
  final challenge = Rxn<OtpChallenge>();

  StreamSubscription<void>? _unauthorizedSubscription;
  bool _handlingExpiredSession = false;

  @override
  void onInit() {
    super.onInit();
    _ledger.setSyncRequestHandler(() => unawaited(_sync.syncNow()));
    _unauthorizedSubscription = _api.unauthorizedEvents.listen(
      (_) => unawaited(handleExpiredSession()),
    );
  }

  @override
  void onClose() {
    unawaited(_unauthorizedSubscription?.cancel());
    super.onClose();
  }

  Future<void> restoreSession() async {
    errorMessage.value = null;
    final cookie = await _storage.readSessionToken();
    if (cookie == null) {
      await _sync.stop();
      await _storage.quarantineActiveScope();
      _ledger.clear();
      Get.offAllNamed(AppRoutes.login);
      return;
    }

    try {
      await _ledger.initializeLocalFirst();
      await _sync.start(syncImmediately: false);
      Get.offAllNamed(AppRoutes.shell);
    } on ApiFailure catch (error) {
      if (error.isUnauthorized) {
        await handleExpiredSession();
        return;
      }
      errorMessage.value = error.message;
    }
  }

  Future<bool> requestOtp(String phone) async {
    if (busy.value) return false;
    busy.value = true;
    errorMessage.value = null;
    try {
      challenge.value = await _repository.requestOtp(phone);
      return true;
    } on ApiFailure catch (error) {
      errorMessage.value = error.message;
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> verifyOtp(String code) async {
    final current = challenge.value;
    if (current == null || busy.value) return false;
    busy.value = true;
    errorMessage.value = null;
    try {
      await _repository.verifyOtp(
        challengeId: current.challengeId,
        phone: current.phoneE164,
        code: code,
      );
      _api.resetUnauthorizedSignal();
      await _ledger.reload();
      await _sync.start(syncImmediately: true);
      Get.offAllNamed(AppRoutes.shell);
      return true;
    } on ApiFailure catch (error) {
      errorMessage.value = error.message;
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> logout() async {
    if (busy.value) return;
    busy.value = true;
    try {
      await _sync.stop();
      await _repository.logout();
    } catch (_) {
      // Local logout remains available if the server is temporarily offline.
    } finally {
      await _storage.clearAll();
      _ledger.clear();
      challenge.value = null;
      busy.value = false;
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> deleteAccount() async {
    if (busy.value) {
      throw const ApiFailure('Please wait for the current action to finish.');
    }
    busy.value = true;
    errorMessage.value = null;
    var deleted = false;
    try {
      await _sync.stop();
      await _ledger.deleteAccount();
      deleted = true;
      _ledger.clear();
      challenge.value = null;
    } on ApiFailure catch (error) {
      errorMessage.value = error.message;
      await _sync.start(syncImmediately: false);
      rethrow;
    } finally {
      busy.value = false;
    }
    if (deleted) Get.offAllNamed(AppRoutes.login);
  }

  /// Quarantines encrypted cached data and pending operations until the same
  /// account authenticates again. It deliberately does not delete the outbox.
  Future<void> handleExpiredSession() async {
    if (_handlingExpiredSession) return;
    _handlingExpiredSession = true;
    try {
      await _sync.stop();
      await _storage.clearSessionToken();
      await _storage.quarantineActiveScope();
      _ledger.clear();
      challenge.value = null;
      errorMessage.value = 'Your session expired. Sign in to continue syncing.';
      if (Get.currentRoute != AppRoutes.login) {
        Get.offAllNamed(AppRoutes.login);
      }
    } finally {
      _handlingExpiredSession = false;
    }
  }
}
