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
    return SubscriptionModel(
      id: json['id'] as String,
      productId: json['productId'] as String,
      status: SubscriptionStatus.values[json['status'] as int],
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
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      isTrialPeriod: json['isTrialPeriod'] as bool? ?? false,
      trialDaysRemaining: json['trialDaysRemaining'] as int? ?? 0,
    );
  }

  static SubscriptionModel get defaultFree => const SubscriptionModel(
    id: 'free',
    productId: 'free',
    status: SubscriptionStatus.free,
    price: 0.0,
    currency: 'INR',
  );
}
