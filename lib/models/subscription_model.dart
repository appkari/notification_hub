enum SubscriptionStatus { free, active, expired, cancelled, pending }

class SubscriptionModel {
  final String id;
  final String productId;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final double price;
  final String currency;
  final bool isTrialPeriod;
  final int trialDaysRemaining;

  const SubscriptionModel({
    required this.id,
    required this.productId,
    required this.status,
    this.startDate,
    this.endDate,
    this.nextBillingDate,
    required this.price,
    required this.currency,
    this.isTrialPeriod = false,
    this.trialDaysRemaining = 0,
  });

  bool get isActive => status == SubscriptionStatus.active;
  bool get isPremium => status == SubscriptionStatus.active || isTrialPeriod;

  SubscriptionModel copyWith({
    String? id,
    String? productId,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextBillingDate,
    double? price,
    String? currency,
    bool? isTrialPeriod,
    int? trialDaysRemaining,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isTrialPeriod: isTrialPeriod ?? this.isTrialPeriod,
      trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'status': status.index,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'nextBillingDate': nextBillingDate?.millisecondsSinceEpoch,
      'price': price,
      'currency': currency,
      'isTrialPeriod': isTrialPeriod,
      'trialDaysRemaining': trialDaysRemaining,
    };
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    // Handle legacy subscription_data format with backward compatibility
    return SubscriptionModel(
      id: json['id'] as String? ?? 'unknown',
      productId: json['productId'] as String? ?? 'unknown',
      status: _parseSubscriptionStatus(json['status']),
      startDate:
          json['startDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['startDate'] as int)
              : null,
      endDate:
          json['endDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['endDate'] as int)
              : null,
      nextBillingDate:
          json['nextBillingDate'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                json['nextBillingDate'] as int,
              )
              : null,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      isTrialPeriod: json['isTrialPeriod'] as bool? ?? false,
      trialDaysRemaining: json['trialDaysRemaining'] as int? ?? 0,
    );
  }

  static SubscriptionStatus _parseSubscriptionStatus(dynamic status) {
    if (status == null) return SubscriptionStatus.free;
    if (status is int) {
      return status < SubscriptionStatus.values.length
          ? SubscriptionStatus.values[status]
          : SubscriptionStatus.free;
    }
    if (status is String) {
      try {
        return SubscriptionStatus.values.firstWhere(
          (e) => e.toString().split('.').last == status,
        );
      } catch (e) {
        return SubscriptionStatus.free;
      }
    }
    return SubscriptionStatus.free;
  }

  static SubscriptionModel get defaultFree => const SubscriptionModel(
    id: 'free',
    productId: 'free',
    status: SubscriptionStatus.free,
    price: 0.0,
    currency: 'INR',
  );
}
