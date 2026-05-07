import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription_model.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Subscription'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(subscriptionProvider),
                _buildFeaturesList(),
                _buildPricingCard(subscriptionProvider),
                if (subscriptionProvider.isPremium)
                  _buildSubscriptionStatus(subscriptionProvider),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(SubscriptionProvider subscriptionProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.deepPurple, Colors.deepPurple.shade300],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              subscriptionProvider.isPremium ? Icons.star : Icons.star_border,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              subscriptionProvider.isPremium
                  ? 'Premium Active'
                  : 'Unlock Premium',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subscriptionProvider.isPremium
                  ? 'Enjoy all premium features'
                  : 'Get advanced features for just ₹1/month',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      _FeatureItem(
        icon: Icons.notifications_active,
        title: 'Advanced Notifications',
        description: 'Enhanced notification management and categorization',
      ),
      _FeatureItem(
        icon: Icons.analytics,
        title: 'Detailed Analytics',
        description: 'Get insights into your notification patterns',
      ),
      _FeatureItem(
        icon: Icons.backup,
        title: 'Cloud Backup',
        description: 'Automatic backup of your notification data',
      ),
      _FeatureItem(
        icon: Icons.color_lens,
        title: 'Custom Themes',
        description: 'Multiple themes and customization options',
      ),
      _FeatureItem(
        icon: Icons.priority_high,
        title: 'Priority Filtering',
        description: 'Smart filtering and priority-based sorting',
      ),
      _FeatureItem(
        icon: Icons.support,
        title: 'Priority Support',
        description: '24/7 premium customer support',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium Features',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => _buildFeatureItem(feature)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(_FeatureItem feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(feature.icon, color: Colors.deepPurple, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(SubscriptionProvider subscriptionProvider) {
    if (subscriptionProvider.isPremium) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade50, Colors.white],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Monthly Premium',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '₹',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Text(
                      '1',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    Text(
                      '/month',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Billed monthly • Cancel anytime',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        subscriptionProvider.isLoading
                            ? null
                            : () => _handlePurchase(subscriptionProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        subscriptionProvider.isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Subscribe Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  ),
                ),
                if (subscriptionProvider.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subscriptionProvider.error!,
                            style: TextStyle(color: Colors.red.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatus(SubscriptionProvider subscriptionProvider) {
    final subscription = subscriptionProvider.currentSubscription;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Subscription Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildStatusRow('Status', _getStatusText(subscription.status)),
              if (subscription.startDate != null)
                _buildStatusRow(
                  'Started',
                  _formatDate(subscription.startDate!),
                ),
              if (subscription.nextBillingDate != null)
                _buildStatusRow(
                  'Next Billing',
                  _formatDate(subscription.nextBillingDate!),
                ),
              _buildStatusRow(
                'Price',
                '₹${subscription.price.toStringAsFixed(0)}/month',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getStatusText(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.pending:
        return 'Pending';
      case SubscriptionStatus.free:
        return 'Free';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _handlePurchase(
    SubscriptionProvider subscriptionProvider,
  ) async {
    final success = await subscriptionProvider.purchaseSubscription();

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Purchase started. Premium will activate after store confirmation.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              subscriptionProvider.error ?? 'Failed to purchase subscription',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
