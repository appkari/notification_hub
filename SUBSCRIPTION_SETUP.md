# Google Play Subscription Setup Guide

This guide will help you set up the monthly ₹1 subscription feature using Google Play Console.

## Prerequisites

1. Google Play Console account
2. App uploaded to Google Play Console (at least as internal testing)
3. Google Play Developer account with payment profile set up

## Step 1: Create Subscription Product in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app
3. Navigate to **Monetize** > **Products** > **Subscriptions**
4. Click **Create subscription**
5. Fill in the details:
   - **Product ID**: `notihub_monthly_premium` (must match the ID in the code)
   - **Name**: Premium Monthly Subscription
   - **Description**: Unlock all premium features for advanced notification management
   - **Billing period**: 1 Month
   - **Price**: ₹1.00 (Indian Rupee)
   - **Free trial**: Optional (you can set 7 days free trial)
   - **Grace period**: 3 days (recommended)

## Step 2: Configure Base Plans

1. In the subscription product, create a base plan:
   - **Base plan ID**: `monthly-premium`
   - **Billing period**: 1 Month
   - **Price**: ₹1.00
   - **Renewal type**: Auto-renewing

## Step 3: App Configuration

The app is already configured with the necessary code. Key files:

- `lib/models/subscription_model.dart` - Subscription data model
- `lib/services/subscription_service.dart` - Google Play billing integration
- `lib/providers/subscription_provider.dart` - State management
- `lib/screens/subscription_screen.dart` - Subscription UI
- `pubspec.yaml` - Dependencies added

## Step 4: Testing

### Internal Testing
1. Upload your app to Google Play Console as internal testing
2. Add test accounts in **Setup** > **License testing**
3. Install the app from Play Store (internal testing track)
4. Test the subscription flow

### Test Cards
Google Play provides test payment methods for testing subscriptions without actual charges.

## Step 5: Features Included

### Premium Features Available:
- ✅ Advanced notification management
- ✅ Detailed analytics
- ✅ Cloud backup
- ✅ Custom themes
- ✅ Priority filtering
- ✅ Priority support

### UI Components:
- Premium badge on notification cards
- Subscription screen with feature list
- Settings integration
- Premium banner widget

## Step 6: Revenue and Analytics

1. Monitor subscription metrics in Google Play Console
2. Track conversion rates and churn
3. Use Google Play Billing Library for real-time subscription status

## Important Notes

1. **Product ID**: The product ID `notihub_monthly_premium` in the code must exactly match the one in Google Play Console
2. **Testing**: Always test with internal testing before releasing
3. **Pricing**: ₹1 is the minimum price for subscriptions in India
4. **Compliance**: Ensure your app complies with Google Play policies for subscriptions
5. **Cancellation**: Users can cancel subscriptions through Google Play Store

## Code Structure

```
lib/
├── models/
│   └── subscription_model.dart          # Subscription data model
├── services/
│   └── subscription_service.dart        # Google Play billing
├── providers/
│   └── subscription_provider.dart       # State management
├── screens/
│   └── subscription_screen.dart         # Subscription UI
└── widgets/
    └── premium_banner.dart              # Promotional banner
```

## Troubleshooting

### Common Issues:
1. **Product not found**: Ensure product ID matches exactly
2. **Billing not available**: Check if Google Play Services is installed
3. **Purchase failed**: Verify app is signed and uploaded to Play Console
4. **Test purchases**: Use test accounts and ensure app is from Play Store

### Debug Steps:
1. Check device logs for billing errors
2. Verify product ID in Google Play Console
3. Ensure app signature matches Play Console
4. Test with different Google accounts

## Next Steps

1. Upload app to Google Play Console
2. Create subscription product with ID `notihub_monthly_premium`
3. Test with internal testing
4. Release to production
5. Monitor subscription metrics

## Support

For Google Play billing issues, refer to:
- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [In-App Purchase Flutter Plugin](https://pub.dev/packages/in_app_purchase) 