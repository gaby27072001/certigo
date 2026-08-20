import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers.dart';
import '../../auth/application/auth_controller.dart';

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
  Future<void> purge();
}

class SharedPreferencesAccountDataPurger implements LocalAccountDataPurger {
  @override
  Future<void> purge() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  }
}

final localAccountDataPurgerProvider = Provider<LocalAccountDataPurger>(
  (Ref ref) => SharedPreferencesAccountDataPurger(),
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

  Future<void> load() async {
    state = const AccountDeletionState.loading();
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

    await _request(reauthentication.reauthenticationToken);
  }

  Future<void> retry() async {
    if (state.busy) return;
    await _request(null);
  }

  Future<void> _request(String? proofToken) async {
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
        await _sync.discardAll();
        await _localData.purge();
        await _auth.completeAccountDeletion();
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
}
