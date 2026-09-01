import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/active_track_store.dart';
import '../../../app/content/runtime_content_dependencies.dart';
import '../../../app/offline/prefs_sync_store.dart';
import '../../../app/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

enum AccountDeletionStage { loading, ready, verifying, deleting, pending, failure }

class AccountDeletionState {
  const AccountDeletionState({
    required this.stage,
    this.deletion,
    this.message,
    this.requestRecorded = false,
  });

  const AccountDeletionState.loading() : this(stage: AccountDeletionStage.loading);

  final AccountDeletionStage stage;
  final AccountDeletion? deletion;
  final String? message;
  final bool requestRecorded;

  bool get busy =>
      stage == AccountDeletionStage.loading ||
      stage == AccountDeletionStage.verifying ||
      stage == AccountDeletionStage.deleting;
}

abstract interface class LocalAccountDataPurger {
  Future<void> purge({
    required String personId,
    required bool serverConfirmed,
  });
}

class PersonScopedAccountDataPurger implements LocalAccountDataPurger {
  const PersonScopedAccountDataPurger(
    this._runtimeContent, {
    ActiveTrackStore? activeTrackStore,
  }) : _activeTrackStore = activeTrackStore;

  final RuntimeContentPersonPurger _runtimeContent;
  final ActiveTrackStore? _activeTrackStore;

  @override
  Future<void> purge({
    required String personId,
    required bool serverConfirmed,
  }) async {
    if (!serverConfirmed) {
      throw StateError('Local account data cannot be purged before server confirmation.');
    }
    await _runtimeContent.purge(
      personId: personId,
      serverConfirmed: serverConfirmed,
    );
    final ActiveTrackStore? activeTrackStore = _activeTrackStore;
    if (activeTrackStore?.read()?.ownerId == personId) {
      await activeTrackStore!.clear();
    }
    await _purgeQuarantinedActions(personId);
  }

  Future<void> _purgeQuarantinedActions(String personId) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> keys = preferences
        .getKeys()
        .where((String key) => key.startsWith('$kSyncQueueQuarantinePrefsPrefix.'))
        .toList(growable: false);
    for (final String key in keys) {
      final String? raw = preferences.getString(key);
      if (raw == null) continue;
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic> || decoded['ownerId'] != personId) continue;
        final bool removed = await preferences.remove(key);
        if (!removed) {
          throw StateError('Unable to purge a person-scoped queue quarantine entry.');
        }
      } on FormatException {
        debugPrint('[account-deletion] retained unreadable shared queue quarantine $key');
      }
    }
  }
}

final localAccountDataPurgerProvider = Provider<LocalAccountDataPurger>(
  (Ref ref) => PersonScopedAccountDataPurger(
    RuntimeContentPersonPurger(
      store: ref.watch(runtimeContentStoreProvider),
      pins: ref.watch(runtimeContentPinRegistryProvider),
    ),
    activeTrackStore: ref.watch(activeTrackStoreProvider),
  ),
);

final accountDeletionControllerProvider =
    StateNotifierProvider.autoDispose<AccountDeletionController, AccountDeletionState>((Ref ref) {
  return AccountDeletionController(
    ref.watch(accountDeletionRepositoryProvider),
    ref.watch(authControllerProvider.notifier),
    ref.watch(syncEngineProvider),
    ref.watch(localAccountDataPurgerProvider),
  )..load();
});

class AccountDeletionController extends StateNotifier<AccountDeletionState> {
  AccountDeletionController(this._repository, this._auth, this._sync, this._localData)
      : super(const AccountDeletionState.loading());

  final AccountDeletionRepository _repository;
  final AuthController _auth;
  final SyncEngine _sync;
  final LocalAccountDataPurger _localData;
  String? _deletionOwnerId;

  Future<void> load() async {
    state = const AccountDeletionState.loading();
    _deletionOwnerId ??= _currentPersonId();
    final Result<AccountDeletion> result = await _repository.getStatus();
    await result.when(
      success: _applyServerStatus,
      failure: (Failure failure) async {
        state = AccountDeletionState(
          stage: AccountDeletionStage.failure,
          message: _messageFor(failure, requestRecorded: false),
        );
      },
    );
  }

  Future<void> start({required String expectedUserId, String? password}) async {
    if (state.busy || state.requestRecorded) return;
    state = const AccountDeletionState(stage: AccountDeletionStage.verifying);
    final SensitiveReauthenticationResult reauthentication = await _auth
        .reauthenticateForAccountDeletion(expectedUserId: expectedUserId, password: password);
    if (!reauthentication.succeeded) {
      state = AccountDeletionState(
        stage: AccountDeletionStage.failure,
        message: reauthentication.message,
      );
      return;
    }
    _deletionOwnerId = expectedUserId.trim();

    await _request(reauthentication.reauthenticationToken);
  }

  Future<void> retry() async {
    if (state.busy) return;
    await _request(null);
  }

  Future<void> _request(String? proofToken) async {
    final String? deletionOwner = _deletionOwnerId;
    if (deletionOwner == null || _currentPersonId() != deletionOwner) {
      state = AccountDeletionState(
        stage: AccountDeletionStage.failure,
        deletion: state.deletion,
        message: 'Le compte authentifié a changé. Reprenez la suppression depuis ce compte.',
        requestRecorded: state.requestRecorded,
      );
      return;
    }
    state = AccountDeletionState(
      stage: AccountDeletionStage.deleting,
      deletion: state.deletion,
      requestRecorded: state.requestRecorded,
    );
    final Result<AccountDeletion> result = await _repository.requestDeletion(
      reauthenticationToken: proofToken,
    );
    await result.when(
      success: _applyServerStatus,
      failure: (Failure failure) async {
        state = AccountDeletionState(
          stage: AccountDeletionStage.failure,
          deletion: state.deletion,
          message: _messageFor(failure, requestRecorded: state.requestRecorded),
          requestRecorded: state.requestRecorded,
        );
      },
    );
  }

  Future<void> _applyServerStatus(AccountDeletion deletion) async {
    if (deletion.isCompleted) {
      try {
        final String? personId = _deletionOwnerId;
        if (personId == null || personId.trim().isEmpty) {
          throw StateError('Authenticated person is unavailable for local deletion.');
        }
        if (_currentPersonId() != personId) {
          throw StateError('Authenticated person changed before local deletion.');
        }
        await _sync.discardOwner(personId);
        await _localData.purge(
          personId: personId,
          serverConfirmed: true,
        );
        if (_currentPersonId() != personId) {
          throw StateError('Authenticated person changed during local deletion.');
        }
        await _auth.completeAccountDeletion(expectedUserId: personId);
      } on Object catch (error) {
        debugPrint(
          '[account-deletion] local cleanup failed: ${error.runtimeType}',
        );
        state = AccountDeletionState(
          stage: AccountDeletionStage.failure,
          deletion: deletion,
          message: 'Le serveur a confirmé la suppression, mais le nettoyage de cet appareil '
              'n’est pas terminé. Restez sur cet écran et réessayez.',
          requestRecorded: true,
        );
      }
      return;
    }

    if (deletion.isPending) {
      state = AccountDeletionState(
        stage: AccountDeletionStage.pending,
        deletion: deletion,
        message: deletion.failureCode == null
            ? 'La suppression est en cours.'
            : 'Une étape sera relancée sans recréer la demande.',
        requestRecorded: true,
      );
      return;
    }

    state = AccountDeletionState(stage: AccountDeletionStage.ready, deletion: deletion);
  }

  static String _messageFor(Failure failure, {required bool requestRecorded}) {
    if (failure is NetworkFailure) {
      return requestRecorded
          ? 'La demande existe déjà sur le serveur. Reconnectez-vous pour reprendre.'
          : 'Impossible de confirmer si la demande a été enregistrée. '
              'Reconnectez-vous : Certigo vérifiera son état avant toute nouvelle demande.';
    }
    if (failure is AuthFailure) {
      return 'Votre identité n’a pas pu être confirmée. Reconnectez-vous puis réessayez.';
    }
    return requestRecorded
        ? 'La suppression n’est pas terminée. Réessayez : les étapes déjà effectuées sont conservées.'
        : 'La demande n’a pas pu être enregistrée. Réessayez.';
  }

  String? _currentPersonId() {
    final AuthState auth = _auth.state;
    final String normalized = auth is Authenticated ? (auth.session.userId ?? '').trim() : '';
    return normalized.isEmpty ? null : normalized;
  }
}
