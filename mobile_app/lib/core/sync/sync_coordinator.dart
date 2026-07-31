// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../../data/repositories/ledger_repository.dart';

/// Serializes background sync attempts and turns connectivity/lifecycle events
/// into hints to retry.
///
/// Connectivity is deliberately not treated as proof that the server is
/// reachable. Repository requests remain the source of truth.
class SyncCoordinator with WidgetsBindingObserver {
  SyncCoordinator({
    required Future<SyncRunResult> Function() runSync,
    this.onResult,
    this.onAuthenticationRequired,
    Connectivity? connectivity,
    DateTime Function()? now,
  }) : _runSync = runSync,
       _connectivity = connectivity ?? Connectivity(),
       _now = now ?? DateTime.now;

  final Future<SyncRunResult> Function() _runSync;
  final void Function(SyncRunResult result)? onResult;
  final FutureOr<void> Function()? onAuthenticationRequired;
  final Connectivity _connectivity;
  final DateTime Function() _now;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;
  Completer<SyncRunResult?>? _activeRun;
  bool _rerunRequested = false;
  bool _started = false;
  bool _disposed = false;
  bool _authenticationSignalled = false;
  int _generation = 0;

  bool get isRunning => _activeRun != null;

  Future<void> start({bool syncImmediately = true}) async {
    if (_started || _disposed) return;
    _started = true;
    _generation += 1;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(syncNow());
      }
    });
    if (syncImmediately) unawaited(syncNow());
  }

  Future<SyncRunResult?> syncNow() {
    if (_disposed || !_started) return Future.value();
    final active = _activeRun;
    if (active != null) {
      _rerunRequested = true;
      return active.future;
    }
    _retryTimer?.cancel();
    final completer = Completer<SyncRunResult?>();
    _activeRun = completer;
    unawaited(_drain(completer, _generation));
    return completer.future;
  }

  Future<void> _drain(
    Completer<SyncRunResult?> completer,
    int generation,
  ) async {
    SyncRunResult? lastResult;
    try {
      do {
        _rerunRequested = false;
        lastResult = await _runSync();
        if (!_started || generation != _generation || _disposed) break;
        onResult?.call(lastResult);
        if (lastResult.authenticationRequired) {
          if (!_authenticationSignalled) {
            _authenticationSignalled = true;
            final callback = onAuthenticationRequired;
            if (callback != null) unawaited(Future.sync(callback));
          }
          _retryTimer?.cancel();
          break;
        }
        _authenticationSignalled = false;
        _schedule(lastResult.nextAttemptAt);
      } while (_rerunRequested &&
          _started &&
          generation == _generation &&
          !_disposed);
      completer.complete(lastResult);
    } catch (error, stackTrace) {
      // Unexpected programming/storage errors are surfaced to explicit callers;
      // network failures are represented by SyncRunResult and scheduled above.
      completer.completeError(error, stackTrace);
    } finally {
      if (identical(_activeRun, completer)) _activeRun = null;
    }
  }

  void _schedule(DateTime? nextAttemptAt) {
    _retryTimer?.cancel();
    if (nextAttemptAt == null || _disposed || !_started) return;
    final delay = nextAttemptAt.difference(_now().toUtc());
    _retryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(syncNow()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  Future<void> stop() async {
    final active = _activeRun?.future;
    _started = false;
    _generation += 1;
    _rerunRequested = false;
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _retryTimer = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // The explicit caller receives unexpected errors; stopping still
        // invalidates this generation and waits for it to leave the pipeline.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
  }
}
