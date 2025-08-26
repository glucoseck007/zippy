import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../design/app_colors.dart';
import '../../design/app_typography.dart';
import '../../models/response/order/order_list_response.dart';
import '../../providers/core/theme_provider.dart';
import '../../providers/auth/auth_provider.dart';
import '../../services/order/order_service.dart';
import '../../widgets/payment/payment_helper.dart';

class PaymentManagementScreen extends ConsumerStatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  ConsumerState<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState
    extends ConsumerState<PaymentManagementScreen>
    with SingleTickerProviderStateMixin {
  List<OrderListItem> _allOrders = [];
  List<OrderListItem> _paidOrders = [];
  List<OrderListItem> _unpaidOrders = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get current user from provider
      final user = ref.read(currentUserProvider);
      if (user?.username == null) {
        throw Exception('User not found or not logged in');
      }

      // Fetch orders from the service
      final orderResponse = await OrderService.getUserOrders(user!.username);

      if (orderResponse?.success == true && orderResponse?.data != null) {
        setState(() {
          _allOrders = orderResponse!.data;
          _splitOrdersByPaymentStatus();
          _isLoading = false;
        });
      } else {
        throw Exception(orderResponse?.message ?? 'Failed to fetch orders');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _splitOrdersByPaymentStatus() {
    _paidOrders = _allOrders
        .where((order) => order.status.toUpperCase() == 'PAID')
        .toList();
    _unpaidOrders = _allOrders
        .where((order) => order.status.toUpperCase() != 'PAID')
        .toList();
  }

  Future<void> _handlePayment(OrderListItem order) async {
    // Since OrderListItem doesn't have price, we'll use a default amount
    // You may want to fetch the price from another API or use a fixed amount
    const defaultAmount = 100000.0; // 100,000 VND as default

    final result = await PaymentHelper.launchPayment(
      context: context,
      orderId: order.orderId,
      amount: defaultAmount,
      orderDescription: order.productName,
    );

    if (result == true) {
      // Payment successful - refresh orders
      await _fetchOrders();

      if (mounted) {
        PaymentHelper.showPaymentResult(
          context: context,
          success: true,
          message: tr('payment.success_order_confirmed'),
          onSuccess: () {
            // Optionally navigate somewhere or just stay on this screen
          },
        );
      }
    } else if (result == false) {
      // Payment failed
      if (mounted) {
        PaymentHelper.showPaymentResult(
          context: context,
          success: false,
          message: tr('payment.failed_try_again'),
        );
      }
    }
    // result == null means user cancelled
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.dmBackgroundColor
          : AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          tr('payment.management.title'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: tr('payment.management.unpaid_tab'),
              icon: Icon(Icons.payment),
            ),
            Tab(
              text: tr('payment.management.paid_tab'),
              icon: Icon(Icons.check_circle),
            ),
          ],
          labelColor: isDarkMode
              ? AppColors.dmButtonColor
              : AppColors.buttonColor,
          unselectedLabelColor: isDarkMode
              ? Colors.grey[400]
              : Colors.grey[600],
          indicatorColor: isDarkMode
              ? AppColors.dmButtonColor
              : AppColors.buttonColor,
        ),
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              tr('payment.management.loading_orders'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                tr('payment.management.error_loading'),
                style: isDarkMode
                    ? AppTypography.dmHeading(
                        context,
                      ).copyWith(color: Colors.red)
                    : AppTypography.heading(
                        context,
                      ).copyWith(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? tr('common.error_occurred'),
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchOrders,
                child: Text(tr('common.retry')),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildUnpaidOrdersList(isDarkMode),
        _buildPaidOrdersList(isDarkMode),
      ],
    );
  }

  Widget _buildUnpaidOrdersList(bool isDarkMode) {
    if (_unpaidOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              tr('payment.management.no_unpaid_orders'),
              style: isDarkMode
                  ? AppTypography.dmHeading(
                      context,
                    ).copyWith(color: Colors.grey[400])
                  : AppTypography.heading(
                      context,
                    ).copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              tr('payment.management.no_unpaid_orders_subtitle'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(
                      context,
                    ).copyWith(color: Colors.grey[500])
                  : AppTypography.bodyText(
                      context,
                    ).copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _unpaidOrders.length,
        itemBuilder: (context, index) {
          final order = _unpaidOrders[index];
          return _buildUnpaidOrderCard(order, isDarkMode);
        },
      ),
    );
  }

  Widget _buildPaidOrdersList(bool isDarkMode) {
    if (_paidOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              tr('payment.management.no_paid_orders'),
              style: isDarkMode
                  ? AppTypography.dmHeading(
                      context,
                    ).copyWith(color: Colors.grey[400])
                  : AppTypography.heading(
                      context,
                    ).copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _paidOrders.length,
        itemBuilder: (context, index) {
          final order = _paidOrders[index];
          return _buildPaidOrderCard(order, isDarkMode);
        },
      ),
    );
  }

  Widget _buildUnpaidOrderCard(OrderListItem order, bool isDarkMode) {
    return Card(
      color: isDarkMode ? AppColors.dmCardColor : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.orderCode,
                    style: isDarkMode
                        ? AppTypography.dmHeading(
                            context,
                          ).copyWith(fontSize: 16)
                        : AppTypography.heading(context).copyWith(fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.productName,
              style: isDarkMode
                  ? AppTypography.dmBodyText(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600)
                  : AppTypography.bodyText(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'payment.management.delivery_to',
                namedArgs: {'location': order.endpoint},
              ),
              style: isDarkMode
                  ? AppTypography.dmBodyText(
                      context,
                    ).copyWith(color: Colors.grey[400])
                  : AppTypography.bodyText(
                      context,
                    ).copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatAmount(
                    100000.0,
                  ), // Default amount since OrderListItem doesn't have price
                  style: isDarkMode
                      ? AppTypography.dmHeading(
                          context,
                        ).copyWith(fontSize: 18, color: Colors.orange)
                      : AppTypography.heading(
                          context,
                        ).copyWith(fontSize: 18, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handlePayment(order),
                icon: const Icon(Icons.payment, size: 18),
                label: Text(tr('payment.management.pay_now')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidOrderCard(OrderListItem order, bool isDarkMode) {
    return Card(
      color: isDarkMode ? AppColors.dmCardColor : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.orderCode,
                    style: isDarkMode
                        ? AppTypography.dmHeading(
                            context,
                          ).copyWith(fontSize: 16)
                        : AppTypography.heading(context).copyWith(fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('payment.management.paid'),
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.productName,
              style: isDarkMode
                  ? AppTypography.dmBodyText(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600)
                  : AppTypography.bodyText(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'payment.management.delivery_to',
                namedArgs: {'location': order.endpoint},
              ),
              style: isDarkMode
                  ? AppTypography.dmBodyText(
                      context,
                    ).copyWith(color: Colors.grey[400])
                  : AppTypography.bodyText(
                      context,
                    ).copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatAmount(
                    100000.0,
                  ), // Default amount since OrderListItem doesn't have price
                  style: isDarkMode
                      ? AppTypography.dmHeading(
                          context,
                        ).copyWith(fontSize: 18, color: Colors.green)
                      : AppTypography.heading(
                          context,
                        ).copyWith(fontSize: 18, color: Colors.green),
                ),
                const Spacer(),
                Text(
                  tr('payment.management.payment_completed'),
                  style: isDarkMode
                      ? AppTypography.dmBodyText(context).copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        )
                      : AppTypography.bodyText(context).copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatter = amount.toStringAsFixed(0);
    final parts = <String>[];

    for (int i = formatter.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, formatter.substring(start, i));
    }

    return '${parts.join(',')} ₫';
  }
}
