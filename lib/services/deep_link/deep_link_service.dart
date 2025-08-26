import 'dart:async';
import 'package:flutter/services.dart';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('deep_link_channel');
  static StreamController<String>? _linkStreamController;

  /// Initialize deep link handling
  static Future<void> initialize() async {
    _linkStreamController = StreamController<String>.broadcast();

    // Listen for deep links while app is running
    _channel.setMethodCallHandler(_handleMethodCall);

    // Check for deep link when app starts
    try {
      final String? initialLink = await _channel.invokeMethod('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        print('DeepLinkService: Initial link: $initialLink');
        _linkStreamController?.add(initialLink);
      }
    } catch (e) {
      print('DeepLinkService: Error getting initial link: $e');
    }
  }

  /// Handle method calls from native platforms
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeepLink':
        final String link = call.arguments as String;
        print('DeepLinkService: Received deep link: $link');
        _linkStreamController?.add(link);
        break;
      default:
        print('DeepLinkService: Unknown method: ${call.method}');
    }
  }

  /// Stream of incoming deep links
  static Stream<String>? get linkStream => _linkStreamController?.stream;

  /// Close the stream
  static void dispose() {
    _linkStreamController?.close();
    _linkStreamController = null;
  }

  /// Parse payment result from deep link
  static Map<String, String>? parsePaymentResult(String link) {
    try {
      if (!link.startsWith('zippyapp://payment/result')) {
        return null;
      }

      final uri = Uri.parse(link);
      final status = uri.queryParameters['status'];
      final orderId = uri.queryParameters['orderId'];

      if (status != null && orderId != null) {
        return {'status': status, 'orderId': orderId};
      }
    } catch (e) {
      print('DeepLinkService: Error parsing payment result: $e');
    }

    return null;
  }
}
