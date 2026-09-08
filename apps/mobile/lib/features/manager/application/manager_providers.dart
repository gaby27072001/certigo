import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'manager_models.dart';
import 'manager_policy.dart';
import 'manager_repository.dart';

/// Fails closed until a future server-backed tenant contract can override it.
///
/// Local previews and tests provide an explicit organization context; the
/// production app must not infer one from a route or fixture.
final managerOrganizationContextProvider = Provider<ManagerOrganizationContext?>((Ref ref) => null);

final managerPolicyProvider = Provider<ManagerPolicy>(
  (Ref ref) => const ManagerPolicy(),
);

final managerPortalRepositoryProvider = Provider<ManagerPortalRepository>(
  (Ref ref) => FixtureManagerPortalRepository(policy: ref.watch(managerPolicyProvider)),
);

final managerExportServiceProvider = Provider<ManagerExportService>(
  (Ref ref) => const FixtureManagerExportService(),
);

final managerPortalDataProvider =
    FutureProvider.autoDispose.family<ManagerPortalData, ManagerOrganizationContext>((
  Ref ref,
  ManagerOrganizationContext context,
) async {
  final Result<ManagerPortalData> result =
      await ref.watch(managerPortalRepositoryProvider).loadPortal(context);
  return result.when(
    success: (ManagerPortalData data) => data,
    failure: (Failure failure) => throw ManagerPortalLoadException(failure),
  );
});

class ManagerPortalLoadException implements Exception {
  const ManagerPortalLoadException(this.failure);

  final Failure failure;
}
