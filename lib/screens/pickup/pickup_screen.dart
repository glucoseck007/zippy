import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/models/response/order/order_list_response.dart';
import 'package:zippy/providers/auth/auth_provider.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/screens/booking/booking_screen.dart';
import 'package:zippy/screens/pickup/qr_scanner_screen.dart';
import 'package:zippy/screens/pickup/trip_progress_screen.dart';
import 'package:zippy/services/order/order_service.dart';
import 'package:zippy/services/trip/trip_service.dart';
import 'package:zippy/state/auth/auth_state.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:zippy/widgets/pickup/confirm_pickup_dialog.dart';

class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({super.key});

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  List<OrderListItem> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final authState = ref.read(authProvider);

    if (!authState.isAuthenticated || authState.user == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = tr('auth.login_required');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final response = await OrderService.getUserOrders(
        authState.user!.username,
      );

      if (mounted) {
        if (response != null && response.success) {
          setState(() {
            _orders = response.data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = response?.message ?? tr('pickup.error');
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = tr('pickup.error');
          _isLoading = false;
        });
      }
    }
  }

  String _translateOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return tr('pickup.status.pending');
      case 'approved':
        return tr('pickup.status.approved');
      case 'active':
      case 'in_progress':
        return tr('pickup.status.active');
      case 'completed':
      case 'finished':
        return tr('pickup.status.completed');
      case 'cancelled':
        return tr('pickup.status.cancelled');
      case 'in_transit':
        return tr('pickup.status.in_transit');
      case 'delivered':
        return tr('pickup.status.delivered');
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
      case 'approved':
      case 'in_progress':
      case 'in_transit':
        return Colors.green;
      case 'delivered':
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'active':
      case 'in_progress':
      case 'in_transit':
      case 'approved':
      case 'delivered':
        return Icons.local_shipping;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  void _showTripProgress(OrderListItem order) {
    _getTripCodeAndNavigate(order);
  }

  Future<void> _getTripCodeAndNavigate(OrderListItem order) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final tripResponse = await TripService.getTripByOrderCode(
        order.orderCode,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (tripResponse != null &&
            tripResponse.success &&
            tripResponse.data != null) {
          // Use the actual trip code from the API response
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripProgressScreen(
                tripCode: tripResponse.data!.tripCode,
                orderCode: order.orderCode,
                robotCode: order.robotCode,
              ),
            ),
          );
        } else {
          // Show error dialog if trip code cannot be retrieved
          _showErrorDialog(
            tripResponse?.message ?? 'Failed to retrieve trip information',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog('Network error: Failed to retrieve trip information');
      }
    }
  }

  void _showErrorDialog(String message) {
    final themeState = ref.read(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
        title: Text(
          tr('pickup.error'),
          style: isDarkMode
              ? AppTypography.dmHeading(context)
              : AppTypography.heading(context),
        ),
        content: Text(
          message,
          style: isDarkMode
              ? AppTypography.dmBodyText(context)
              : AppTypography.bodyText(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr('pickup.common.ok'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(
                      context,
                    ).copyWith(color: AppColors.dmButtonColor)
                  : AppTypography.bodyText(
                      context,
                    ).copyWith(color: AppColors.buttonColor),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReceiveOrder(OrderListItem order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(
          onScanned: (qrCode) {
            _onQRCodeScanned(order, qrCode);
          },
        ),
      ),
    );
  }

  void _onQRCodeScanned(OrderListItem order, String qrCode) {
    // Parse QR code to extract tripCode
    String tripCode = '';
    try {
      final parsedData = jsonDecode(qrCode);
      tripCode = parsedData['tripCode'] ?? '';
    } catch (e) {
      // If JSON parsing fails, use empty tripCode
      tripCode = '';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ConfirmPickupDialog(
          orderCode: order.orderCode,
          tripCode: tripCode,
          onSuccess: () {
            _loadOrders(); // Refresh the orders list
          },
        );
      },
    );
  }

  void _handlePayOrder(OrderListItem order) {
    // Show payment dialog
    final themeState = ref.read(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tr('pickup.payment.title'),
            style: isDarkMode
                ? AppTypography.dmHeading(context)
                : AppTypography.heading(context),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payment, size: 60, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                '${tr('pickup.payment.message')}\n${order.orderCode}',
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('pickup.payment.cancel'),
                style: isDarkMode
                    ? AppTypography.dmBodyText(
                        context,
                      ).copyWith(color: Colors.grey)
                    : AppTypography.bodyText(
                        context,
                      ).copyWith(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processPayment(order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('pickup.payment.confirm')),
            ),
          ],
        );
      },
    );
  }

  void _processPayment(OrderListItem order) {
    // TODO: Implement actual payment processing
    // For now, show a success message
    final themeState = ref.read(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tr('pickup.payment.success_title'),
            style: isDarkMode
                ? AppTypography.dmHeading(context)
                : AppTypography.heading(context),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 60, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                tr('pickup.payment.success_message'),
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadOrders(); // Refresh orders after payment
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(tr('pickup.common.ok')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    bool isDarkMode = themeState.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('pickup.title'),
          style: isDarkMode
              ? AppTypography.dmHeading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500)
              : AppTypography.heading(
                  context,
                ).copyWith(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: tr('pickup.refresh'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildBody(isDarkMode),
      ),
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
              tr('pickup.loading'),
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
          padding: const EdgeInsets.all(24.0),
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
                _errorMessage ?? tr('pickup.error'),
                textAlign: TextAlign.center,
                style:
                    (isDarkMode
                            ? AppTypography.dmSubTitleText(context)
                            : AppTypography.subTitleText(context))
                        .copyWith(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr('pickup.refresh')),
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.grey.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                tr('pickup.empty_state.title'),
                style: isDarkMode
                    ? AppTypography.dmSubTitleText(context)
                    : AppTypography.subTitleText(context),
              ),
              const SizedBox(height: 8),
              Text(
                tr('pickup.empty_state.message'),
                textAlign: TextAlign.center,
                style: isDarkMode
                    ? AppTypography.dmBodyText(
                        context,
                      ).copyWith(color: Colors.grey[400])
                    : AppTypography.bodyText(
                        context,
                      ).copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  NavigationManager.navigateToWithSlideTransition(
                    context,
                    const BookingScreen(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr('pickup.empty_state.button')),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _buildOrderCard(order, isDarkMode);
      },
    );
  }

  Widget _buildOrderCard(OrderListItem order, bool isDarkMode) {
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: isDarkMode
          ? AppColors.dmBackgroundColor
          : AppColors.backgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order code and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr('pickup.order_code')}: ${order.orderCode}',
                        style:
                            (isDarkMode
                                    ? AppTypography.dmSubTitleText(context)
                                    : AppTypography.subTitleText(context))
                                .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (order.createdAt != null)
                        Text(
                          '${tr('pickup.created_at')}: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt!)}',
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
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.02,
                    vertical: MediaQuery.of(context).size.height * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _translateOrderStatus(order.status),
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Order details
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${tr('booking.product_label')}: ',
                  style: isDarkMode
                      ? AppTypography.dmBodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500)
                      : AppTypography.bodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500),
                ),
                Expanded(
                  child: Text(
                    order.productName,
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.my_location_outlined,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${tr('booking.start_point_label')}: ',
                  style: isDarkMode
                      ? AppTypography.dmBodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500)
                      : AppTypography.bodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500),
                ),
                Expanded(
                  child: Text(
                    order.startPoint,
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.room_outlined,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${tr('booking.end_point_label')}: ',
                  style: isDarkMode
                      ? AppTypography.dmBodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500)
                      : AppTypography.bodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500),
                ),
                Expanded(
                  child: Text(
                    order.endpoint,
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${tr('booking.robot_label')}: ',
                  style: isDarkMode
                      ? AppTypography.dmBodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500)
                      : AppTypography.bodyText(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500),
                ),
                Expanded(
                  child: Text(
                    order.robotCode,
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action button (View Progress, Receive Order, or Pay)
            SizedBox(
              width: double.infinity,
              child: order.status.toLowerCase() == 'pending'
                  ? ElevatedButton.icon(
                      onPressed: null, // Disabled button
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(tr('pickup.status.pending')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  : order.status.toLowerCase() == 'delivered'
                  ? ElevatedButton.icon(
                      onPressed: () => _handleReceiveOrder(order),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(tr('pickup.receive_order')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  : order.status.toLowerCase() == 'finished' ||
                        order.status.toLowerCase() == 'completed'
                  ? ElevatedButton.icon(
                      onPressed: () => _handlePayOrder(order),
                      icon: const Icon(Icons.payment, size: 18),
                      label: Text(tr('pickup.pay_order')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _showTripProgress(order),
                      icon: const Icon(Icons.timeline, size: 18),
                      label: Text(tr('pickup.view_progress')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonColor,
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
}
