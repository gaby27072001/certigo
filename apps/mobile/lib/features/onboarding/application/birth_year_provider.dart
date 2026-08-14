import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kBirthYearKey = 'user_birth_year';

/// Persists and exposes the learner's year of birth.
///
/// `null` means not yet collected; any integer value is the stored year.
/// Backed by [SharedPreferences] so the value survives app restarts.
class BirthYearNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBirthYearKey);
  }

  /// Persists [year] to [SharedPreferences] and updates the state.
  Future<void> save(int year) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBirthYearKey, year);
    state = AsyncData<int?>(year);
  }

  /// Removes the stored birth year (e.g. on account reset).
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBirthYearKey);
    state = const AsyncData<int?>(null);
  }
}

/// Global provider for the learner's birth year.
///
/// Read this anywhere in the app to check whether the birth year has been
/// collected and what its value is.
final birthYearProvider = AsyncNotifierProvider<BirthYearNotifier, int?>(BirthYearNotifier.new);
