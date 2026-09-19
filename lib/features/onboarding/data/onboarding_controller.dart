import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingPrefsKey = 'onboarding_completed_v1';

/// `null` while prefs load; then whether welcome was finished.
class OnboardingController extends Notifier<bool?> {
  @override
  bool? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_onboardingPrefsKey) ?? false;
  }

  Future<void> complete() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingPrefsKey, true);
  }

  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingPrefsKey, false);
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool?>(OnboardingController.new);

/// Bridges Riverpod onboarding changes into [Listenable] for go_router.
class OnboardingRefresh extends ChangeNotifier {
  OnboardingRefresh(this._ref) {
    _subscription = _ref.listen<bool?>(onboardingCompletedProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<bool?> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
