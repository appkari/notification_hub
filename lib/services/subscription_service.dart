import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_model.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _subscriptionAttached = false;

  // Product IDs for your subscription
  static const String monthlySubscriptionId = 'notihub_monthly_premium';
  static const Set<String> productIds = {monthlySubscriptionId};

  List<ProductDetails> _products = [];
  // List<PurchaseDetails> _purchases = [];
  bool _isAvailable = false;
  bool _purchasePending = false;

  // Subscription status
  SubscriptionModel _currentSubscription = SubscriptionModel.defaultFree;

  // Getters
  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  SubscriptionModel get currentSubscription => _currentSubscription;

  // Initialize the service
  Future<void> initialize() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdated,
      onDone: _updateStreamOnDone,
      onError: _updateStreamOnError,
    );
    _subscriptionAttached = true;

    await _initStoreInfo();
    await _loadSubscriptionStatus();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      _isAvailable = isAvailable;
      _products = [];
      // _purchases = [];
      _purchasePending = false;
      return;
    }

    if (Platform.isAndroid) {
      // Enable pending purchases on Android if needed
      // This is handled automatically by the in_app_purchase plugin
    }

    final ProductDetailsResponse productDetailResponse = await _inAppPurchase
        .queryProductDetails(productIds);

    if (productDetailResponse.error != null) {
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      // _purchases = [];
      _purchasePending = false;
      return;
    }

    if (productDetailResponse.productDetails.isEmpty) {
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      // _purchases = [];
      _purchasePending = false;
      return;
    }

    _isAvailable = isAvailable;
    _products = productDetailResponse.productDetails;

    // Restore purchases
    await _restorePurchases();
  }

  Future<void> _restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  Future<bool> purchaseSubscription() async {
    if (_products.isEmpty) {
      return false;
    }

    final ProductDetails productDetails = _products.firstWhere(
      (product) => product.id == monthlySubscriptionId,
    );

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    try {
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      return success;
    } catch (e) {
      debugPrint('Error purchasing subscription: $e');
      return false;
    }
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      _handlePurchaseUpdate(purchaseDetails);
    }
  }

  void _handlePurchaseUpdate(PurchaseDetails purchaseDetails) {
    if (purchaseDetails.status == PurchaseStatus.pending) {
      _purchasePending = true;
    } else {
      if (purchaseDetails.status == PurchaseStatus.error) {
        _purchasePending = false;
        debugPrint('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _purchasePending = false;
        _verifyPurchase(purchaseDetails);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Here you would typically verify the purchase with your backend
    // For now, we'll treat it as valid
    if (purchaseDetails.productID == monthlySubscriptionId) {
      final now = DateTime.now();
      _currentSubscription = SubscriptionModel(
        id: purchaseDetails.purchaseID ?? 'unknown',
        productId: purchaseDetails.productID,
        status: SubscriptionStatus.active,
        startDate: now,
        nextBillingDate: now.add(const Duration(days: 30)),
        price: 1.0,
        currency: 'INR',
      );

      await _saveSubscriptionStatus();
      debugPrint('Subscription activated: ${_currentSubscription.id}');
    }
  }

  Future<void> _saveSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionData = _currentSubscription.toJson();
    await prefs.setString('subscription_data', subscriptionData.toString());
  }

  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptionDataString = prefs.getString('subscription_data');

    if (subscriptionDataString != null) {
      try {
        // Parse the saved data and check if subscription is still valid
        final now = DateTime.now();
        if (_currentSubscription.nextBillingDate?.isBefore(now) == true) {
          // Subscription expired
          _currentSubscription = _currentSubscription.copyWith(
            status: SubscriptionStatus.expired,
          );
          await _saveSubscriptionStatus();
        }
      } catch (e) {
        debugPrint('Error loading subscription status: $e');
        _currentSubscription = SubscriptionModel.defaultFree;
      }
    }
  }

  void _updateStreamOnDone() {
    if (_subscriptionAttached) {
      _subscription.cancel();
      _subscriptionAttached = false;
    }
  }

  void _updateStreamOnError(dynamic error) {
    debugPrint('Purchase stream error: $error');
  }

  void dispose() {
    if (_subscriptionAttached) {
      _subscription.cancel();
      _subscriptionAttached = false;
    }
  }
}
