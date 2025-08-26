# PayOS Payment Integration - Flutter Implementation

This document explains how to use the PayOS payment integration in your Flutter app.

## Overview

The payment integration consists of several components:
- **PaymentScreen**: Main UI for handling payments with WebView
- **PaymentService**: API calls to backend payment endpoints
- **PaymentProvider**: State management using Riverpod
- **Deep Link Handling**: Processes payment results from PayOS redirects

## Setup

### 1. Dependencies

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  webview_flutter: ^4.4.4
  url_launcher: ^6.2.2
  # ... your existing dependencies
```

### 2. Platform Configuration

#### Android (android/app/src/main/AndroidManifest.xml)

Add deep link intent filter to your main activity:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    
    <!-- Existing intent filters -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    
    <!-- Add this for payment deep links -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="zippyapp" android:host="payment" />
    </intent-filter>
</activity>
```

#### iOS (ios/Runner/Info.plist)

Add URL scheme to handle deep links:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>zippyapp.payment</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>zippyapp</string>
        </array>
    </dict>
</array>
```

## Usage

### Basic Payment Flow

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/payment/payment_helper.dart';

class OrderScreen extends ConsumerWidget {
  final String orderCode;
  final double amount;
  final String productName;

  const OrderScreen({
    Key? key,
    required this.orderCode,
    required this.amount,
    required this.productName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Order: $orderCode')),
      body: Column(
        children: [
          // Your order details UI
          Text('Product: $productName'),
          Text('Amount: ${amount.toStringAsFixed(0)} ₫'),
          
          const Spacer(),
          
          // Payment button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handlePayment(context),
                child: const Text('Pay Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePayment(BuildContext context) async {
    final result = await PaymentHelper.launchPayment(
      context: context,
      orderId: orderCode,
      amount: amount,
      orderDescription: productName,
    );

    if (result == true) {
      // Payment successful
      _onPaymentSuccess(context);
    } else if (result == false) {
      // Payment failed
      _onPaymentFailure(context);
    }
    // result == null means user cancelled
  }

  void _onPaymentSuccess(BuildContext context) {
    PaymentHelper.showPaymentResult(
      context: context,
      success: true,
      message: 'Payment completed successfully! Your order is confirmed.',
      onSuccess: () {
        // Navigate to order tracking or home
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  void _onPaymentFailure(BuildContext context) {
    PaymentHelper.showPaymentResult(
      context: context,
      success: false,
      message: 'Payment failed. Please try again or contact support.',
      onFailure: () {
        // Stay on current screen or navigate back
      },
    );
  }
}
```

### Direct PaymentScreen Usage

```dart
import '../screens/payment/payment_screen.dart';

void _launchPaymentDirect() async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) => PaymentScreen(
        orderId: 'ORDER_123',
        amount: 150000.0,
        orderDescription: 'Coffee and Pastry',
      ),
      fullscreenDialog: true,
    ),
  );

  if (result == true) {
    print('Payment successful');
  } else if (result == false) {
    print('Payment failed');
  } else {
    print('Payment cancelled');
  }
}
```

### Using PaymentProvider Directly

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/payment/payment_provider.dart';
import '../state/payment/payment_state.dart';

class CustomPaymentWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentState = ref.watch(paymentProvider);

    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            ref.read(paymentProvider.notifier).createPayment('ORDER_123');
          },
          child: const Text('Create Payment'),
        ),

        // React to payment state changes
        if (paymentState is PaymentLoading) 
          const CircularProgressIndicator(),

        if (paymentState is PaymentCreated)
          Text('Payment URL: ${paymentState.paymentData.checkoutUrl}'),

        if (paymentState is PaymentSuccess)
          Text('Payment successful: ${paymentState.paymentStatus.amount}'),

        if (paymentState is PaymentError)
          Text('Error: ${paymentState.errorMessage}'),
      ],
    );
  }
}
```

## API Integration

### Backend Endpoints

The Flutter app expects these backend endpoints:

1. **Create Payment**: `POST /api/payment/mobile/create/{orderId}`
   ```json
   Response:
   {
     "paymentId": "uuid-string",
     "paymentLinkId": "payos-link-id", 
     "checkoutUrl": "https://pay.payos.vn/...",
     "orderCode": "order-code",
     "amount": 150000.0
   }
   ```

2. **Check Payment Status**: `GET /api/payment/mobile/status/{orderId}`
   ```json
   Response:
   {
     "paymentId": "uuid-string",
     "paymentStatus": "PAID", // or "PENDING"
     "orderStatus": "confirmed",
     "amount": 150000.0,
     "createdAt": "2025-01-01T12:00:00Z",
     "paidAt": "2025-01-01T12:05:00Z" // or null
   }
   ```

### Authentication

The PaymentService automatically includes JWT tokens from SecureStorage:
```dart
'Authorization': 'Bearer $token'
```

## Deep Link Handling

### Automatic Handling

The PaymentScreen automatically handles deep link redirects from PayOS:
- PayOS redirects to: `zippyapp://payment/result?status=success&orderId={orderId}`
- App extracts parameters and calls payment status API
- UI updates based on payment result

### Manual Deep Link Setup

If you need custom deep link handling:

```dart
import '../services/deep_link/deep_link_service.dart';

void initializeDeepLinks() {
  DeepLinkService.initialize();
  
  DeepLinkService.linkStream?.listen((link) {
    final result = DeepLinkService.parsePaymentResult(link);
    if (result != null) {
      final orderId = result['orderId']!;
      final status = result['status']!;
      
      // Handle payment result
      _handlePaymentResult(orderId, status);
    }
  });
}
```

## Error Handling

The payment integration handles various error scenarios:

1. **Network Errors**: Automatic retry with user feedback
2. **Payment Failures**: Clear error messages and retry options
3. **WebView Issues**: Fallback error handling
4. **Deep Link Problems**: Graceful degradation

## Customization

### Styling

Modify colors and themes in:
- `PaymentScreen._buildBody()` methods
- Theme provider integration
- Translation keys in `assets/translations/`

### Payment Flow

Customize the payment flow by:
- Extending `PaymentState` for additional states
- Modifying `PaymentProvider` for custom logic
- Creating custom UI components

## Testing

### Test Payment Flow

1. **Create Test Order**: Use a test order ID
2. **Mock Backend**: Ensure your backend returns test payment URLs
3. **PayOS Sandbox**: Use PayOS sandbox environment for testing

### Deep Link Testing

Test deep links using ADB (Android):
```bash
adb shell am start \
  -W -a android.intent.action.VIEW \
  -d "zippyapp://payment/result?status=success&orderId=TEST_ORDER" \
  com.yourcompany.zippy
```

## Troubleshooting

### Common Issues

1. **WebView not loading**: Check internet connection and payment URL
2. **Deep links not working**: Verify AndroidManifest.xml and Info.plist configuration
3. **Payment status not updating**: Check backend webhook configuration
4. **Authentication errors**: Verify JWT token is valid and included

### Debug Mode

Enable debug logs by checking console output:
```dart
print('PaymentService: ...');
print('PaymentProvider: ...');
print('PaymentScreen: ...');
```

## Security Considerations

1. **HTTPS Only**: Ensure all payment URLs use HTTPS
2. **Token Validation**: Backend should validate JWT tokens
3. **Deep Link Validation**: Verify payment status via API, not just deep link parameters
4. **Sensitive Data**: Never log payment details or tokens in production

## Support

For issues or questions:
1. Check console logs for detailed error messages
2. Verify backend API responses
3. Test deep link configuration
4. Contact PayOS support for payment gateway issues
