import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider with ChangeNotifier {
  final SubscriptionService _subscriptionService = SubscriptionService();

  SubscriptionModel _currentSubscription = SubscriptionModel.defaultFree;
  bool _isLoading = false;
  String? _error;

  // Getters
  SubscriptionModel get currentSubscription => _currentSubscription;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPremium => _currentSubscription.isPremium;
  bool get isSubscriptionActive => _currentSubscription.isActive;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _subscriptionService.initialize();
      _currentSubscription = _subscriptionService.currentSubscription;
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize subscription service: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> purchaseSubscription() async {
    if (_isLoading) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final requestStarted = await _subscriptionService.purchaseSubscription();
      if (requestStarted) {
        _error = null;
      } else {
        _error = 'Failed to purchase subscription';
      }
      return requestStarted;
    } catch (e) {
      _error = 'Error purchasing subscription: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSubscriptionStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _subscriptionService.refreshSubscriptionStatus();
      _currentSubscription = _subscriptionService.currentSubscription;
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh subscription status: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscriptionService.dispose();
    super.dispose();
  }
}
