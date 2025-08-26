import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../design/app_colors.dart';
import '../../design/app_typography.dart';
import '../../providers/core/theme_provider.dart';
import '../../providers/payment/payment_provider.dart';
import '../../services/payment/payment_service.dart';
import '../../state/payment/payment_state.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String orderId;
  final double? amount;
  final String? orderDescription;

  const PaymentScreen({
    super.key,
    required this.orderId,
    this.amount,
    this.orderDescription,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  WebViewController? _webViewController;
  bool _isWebViewLoading = true;

  @override
  void initState() {
    super.initState();

    // Create payment when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentProvider.notifier).createPayment(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;
    final paymentState = ref.watch(paymentProvider);

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.dmBackgroundColor
          : AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          tr('payment.title'),
          style: isDarkMode
              ? AppTypography.dmHeading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500)
              : AppTypography.heading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
        foregroundColor: isDarkMode
            ? AppColors.dmDefaultColor
            : AppColors.defaultColor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleBackPressed(),
        ),
      ),
      body: _buildBody(isDarkMode, paymentState),
    );
  }

  Widget _buildBody(bool isDarkMode, PaymentState paymentState) {
    switch (paymentState.runtimeType) {
      case PaymentLoading:
        return _buildLoadingView(isDarkMode);

      case PaymentCreated:
        final state = paymentState as PaymentCreated;
        return _buildPaymentCreatedView(isDarkMode, state);

      case PaymentWebViewLoading:
        final state = paymentState as PaymentWebViewLoading;
        return _buildWebViewLoadingView(isDarkMode, state);

      case PaymentProcessing:
        final state = paymentState as PaymentProcessing;
        return _buildProcessingView(isDarkMode, state);

      case PaymentSuccess:
        final state = paymentState as PaymentSuccess;
        return _buildSuccessView(isDarkMode, state);

      case PaymentFailed:
        final state = paymentState as PaymentFailed;
        return _buildFailedView(isDarkMode, state);

      case PaymentError:
        final state = paymentState as PaymentError;
        return _buildErrorView(isDarkMode, state);

      default:
        return _buildLoadingView(isDarkMode);
    }
  }

  Widget _buildLoadingView(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            tr('payment.creating_payment'),
            style: isDarkMode
                ? AppTypography.dmBodyText(context)
                : AppTypography.bodyText(context),
          ),
          if (widget.amount != null) ...[
            const SizedBox(height: 8),
            Text(
              PaymentService.formatAmount(widget.amount!),
              style: isDarkMode
                  ? AppTypography.dmHeading(context).copyWith(fontSize: 20)
                  : AppTypography.heading(context).copyWith(fontSize: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentCreatedView(bool isDarkMode, PaymentCreated state) {
    return Column(
      children: [
        // Payment info
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.dmCardColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('payment.order_summary'),
                style: isDarkMode
                    ? AppTypography.dmHeading(context).copyWith(fontSize: 18)
                    : AppTypography.heading(context).copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(isDarkMode, tr('payment.order_id'), widget.orderId),
              _buildInfoRow(
                isDarkMode,
                tr('payment.amount'),
                PaymentService.formatAmount(state.paymentData.amount),
              ),
              if (widget.orderDescription != null)
                _buildInfoRow(
                  isDarkMode,
                  tr('payment.description'),
                  widget.orderDescription!,
                ),
            ],
          ),
        ),

        // WebView
        Expanded(child: _buildWebView(state.paymentData.checkoutUrl)),
      ],
    );
  }

  Widget _buildWebViewLoadingView(
    bool isDarkMode,
    PaymentWebViewLoading state,
  ) {
    return Column(
      children: [
        // Payment info (same as above)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.dmCardColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('payment.order_summary'),
                style: isDarkMode
                    ? AppTypography.dmHeading(context).copyWith(fontSize: 18)
                    : AppTypography.heading(context).copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(isDarkMode, tr('payment.order_id'), widget.orderId),
              _buildInfoRow(
                isDarkMode,
                tr('payment.amount'),
                PaymentService.formatAmount(state.paymentData.amount),
              ),
            ],
          ),
        ),

        // Loading overlay on WebView
        Expanded(
          child: Stack(
            children: [
              _buildWebView(state.paymentData.checkoutUrl),
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebView(String url) {
    return WebViewWidget(controller: _getWebViewController(url));
  }

  WebViewController _getWebViewController(String url) {
    if (_webViewController == null) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Update loading state based on progress
              if (progress == 100 && _isWebViewLoading) {
                setState(() {
                  _isWebViewLoading = false;
                });
                ref.read(paymentProvider.notifier).setWebViewLoading(false);
              }
            },
            onPageStarted: (String url) {
              print('PaymentScreen: Page started loading: $url');

              // Check if this is the return URL
              if (url.startsWith('zippyapp://payment/result')) {
                _handlePaymentReturn(url);
              }
            },
            onPageFinished: (String url) {
              print('PaymentScreen: Page finished loading: $url');
            },
            onWebResourceError: (WebResourceError error) {
              print('PaymentScreen: WebView error: ${error.description}');
            },
            onNavigationRequest: (NavigationRequest request) {
              print('PaymentScreen: Navigation request: ${request.url}');

              // Handle deep link redirects
              if (request.url.startsWith('zippyapp://payment/result')) {
                _handlePaymentReturn(request.url);
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(url));

      // Set initial loading state
      ref.read(paymentProvider.notifier).setWebViewLoading(true);
    }

    return _webViewController!;
  }

  Widget _buildProcessingView(bool isDarkMode, PaymentProcessing state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            tr('payment.verifying_payment'),
            style: isDarkMode
                ? AppTypography.dmBodyText(context)
                : AppTypography.bodyText(context),
          ),
          const SizedBox(height: 8),
          Text(
            tr('payment.please_wait'),
            style: isDarkMode
                ? AppTypography.dmBodyText(
                    context,
                  ).copyWith(color: Colors.grey[400])
                : AppTypography.bodyText(
                    context,
                  ).copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isDarkMode, PaymentSuccess state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              tr('payment.success_title'),
              style: isDarkMode
                  ? AppTypography.dmHeading(context).copyWith(fontSize: 24)
                  : AppTypography.heading(context).copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              tr('payment.success_message'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              PaymentService.formatAmount(state.paymentStatus.amount),
              style: isDarkMode
                  ? AppTypography.dmHeading(
                      context,
                    ).copyWith(fontSize: 28, color: Colors.green)
                  : AppTypography.heading(
                      context,
                    ).copyWith(fontSize: 28, color: Colors.green),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(tr('payment.continue')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedView(bool isDarkMode, PaymentFailed state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              tr('payment.failed_title'),
              style: isDarkMode
                  ? AppTypography.dmHeading(context).copyWith(fontSize: 24)
                  : AppTypography.heading(context).copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage,
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr('common.cancel')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(paymentProvider.notifier)
                        .retryPayment(widget.orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr('payment.try_again')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isDarkMode, PaymentError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              tr('payment.error_title'),
              style: isDarkMode
                  ? AppTypography.dmHeading(context).copyWith(fontSize: 24)
                  : AppTypography.heading(context).copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              state.errorMessage,
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr('common.cancel')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(paymentProvider.notifier)
                        .retryPayment(widget.orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(tr('payment.retry')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(bool isDarkMode, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isDarkMode
                ? AppTypography.dmBodyText(
                    context,
                  ).copyWith(color: Colors.grey[400])
                : AppTypography.bodyText(
                    context,
                  ).copyWith(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: isDarkMode
                ? AppTypography.dmBodyText(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600)
                : AppTypography.bodyText(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _handlePaymentReturn(String url) {
    print('PaymentScreen: Handling payment return: $url');

    final uri = Uri.parse(url);
    final status = uri.queryParameters['status'];
    final orderId = uri.queryParameters['orderId'];

    if (status != null && orderId != null) {
      ref.read(paymentProvider.notifier).handlePaymentResult(orderId, status);
    } else {
      print('PaymentScreen: Invalid return URL parameters');
      ref
          .read(paymentProvider.notifier)
          .handlePaymentResult(widget.orderId, 'error');
    }
  }

  void _handleBackPressed() {
    final state = ref.read(paymentProvider);

    if (state is PaymentSuccess) {
      Navigator.of(context).pop(true);
    } else if (state is PaymentFailed || state is PaymentError) {
      Navigator.of(context).pop(false);
    } else {
      // Show confirmation dialog for in-progress payment
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('payment.cancel_payment_title')),
          content: Text(tr('payment.cancel_payment_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('common.no')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(false);
              },
              child: Text(tr('common.yes')),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _webViewController = null;
    super.dispose();
  }
}
