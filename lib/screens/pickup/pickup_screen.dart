import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/models/response/order/order_list_response.dart';
import 'package:zippy/models/response/trip/trip_response.dart';
import 'package:zippy/providers/auth/auth_provider.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/screens/booking/booking_screen.dart';
import 'package:zippy/screens/pickup/qr_scanner_screen.dart';
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
      case 'active':
      case 'in_progress':
        return tr('pickup.status.active');
      case 'completed':
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
      case 'in_progress':
      case 'in_transit':
        return Colors.blue;
      case 'completed':
      case 'delivered':
        return Colors.green;
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
        return Icons.local_shipping;
      case 'completed':
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  void _showTripProgress(OrderListItem order) {
    showDialog(
      context: context,
      builder: (context) => _TripProgressDialog(
        orderCode: order.orderCode,
        onClose: () => Navigator.pop(context),
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
    // Validate QR code (you can add validation logic here)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ConfirmPickupDialog(
          orderCode: order.orderCode,
          onSuccess: () {
            _loadOrders(); // Refresh the orders list
          },
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
              ? AppTypography.dmHeading.copyWith(fontWeight: FontWeight.w500)
              : AppTypography.heading.copyWith(fontWeight: FontWeight.w500),
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
                  ? AppTypography.dmBodyText
                  : AppTypography.bodyText,
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
                            ? AppTypography.dmSubTitleText
                            : AppTypography.subTitleText)
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
                    ? AppTypography.dmSubTitleText
                    : AppTypography.subTitleText,
              ),
              const SizedBox(height: 8),
              Text(
                tr('pickup.empty_state.message'),
                textAlign: TextAlign.center,
                style: isDarkMode
                    ? AppTypography.dmBodyText.copyWith(color: Colors.grey[400])
                    : AppTypography.bodyText.copyWith(color: Colors.grey[600]),
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
                                    ? AppTypography.dmSubTitleText
                                    : AppTypography.subTitleText)
                                .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (order.createdAt != null)
                        Text(
                          '${tr('pickup.created_at')}: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt!)}',
                          style: isDarkMode
                              ? AppTypography.dmBodyText.copyWith(
                                  color: Colors.grey[400],
                                )
                              : AppTypography.bodyText.copyWith(
                                  color: Colors.grey[600],
                                ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
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
                                    ? AppTypography.dmBodyText
                                    : AppTypography.bodyText)
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
                      ? AppTypography.dmBodyText.copyWith(
                          fontWeight: FontWeight.w500,
                        )
                      : AppTypography.bodyText.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                ),
                Expanded(
                  child: Text(
                    order.productName,
                    style: isDarkMode
                        ? AppTypography.dmBodyText
                        : AppTypography.bodyText,
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
                  '${tr('booking.room_label')}: ',
                  style: isDarkMode
                      ? AppTypography.dmBodyText.copyWith(
                          fontWeight: FontWeight.w500,
                        )
                      : AppTypography.bodyText.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                ),
                Expanded(
                  child: Text(
                    order.endpoint,
                    style: isDarkMode
                        ? AppTypography.dmBodyText
                        : AppTypography.bodyText,
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
                      ? AppTypography.dmBodyText.copyWith(
                          fontWeight: FontWeight.w500,
                        )
                      : AppTypography.bodyText.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                ),
                Expanded(
                  child: Text(
                    order.robotCode,
                    style: isDarkMode
                        ? AppTypography.dmBodyText
                        : AppTypography.bodyText,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action button (View Progress or Receive Order)
            SizedBox(
              width: double.infinity,
              child: order.status.toLowerCase() == 'delivered'
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

class _TripProgressDialog extends ConsumerStatefulWidget {
  final String orderCode;
  final VoidCallback onClose;

  const _TripProgressDialog({required this.orderCode, required this.onClose});

  @override
  ConsumerState<_TripProgressDialog> createState() =>
      _TripProgressDialogState();
}

class _TripProgressDialogState extends ConsumerState<_TripProgressDialog> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  TripData? _tripData;

  @override
  void initState() {
    super.initState();
    _loadTripData();
  }

  Future<void> _loadTripData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final response = await TripService.getTripByOrderCode(widget.orderCode);

      if (mounted) {
        if (response != null && response.success && response.data != null) {
          setState(() {
            _tripData = response.data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _hasError = true;
            _errorMessage =
                response?.message ?? tr('pickup.trip_details.error');
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = tr('pickup.trip_details.error');
          _isLoading = false;
        });
      }
    }
  }

  String _translateTripStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return tr('pickup.status.pending');
      case 'active':
      case 'in_progress':
        return tr('pickup.status.active');
      case 'completed':
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
      case 'in_progress':
      case 'in_transit':
        return Colors.blue;
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    bool isDarkMode = themeState.isDarkMode;

    return AlertDialog(
      title: Text(tr('pickup.trip_details.title')),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildDialogContent(isDarkMode),
      ),
      actions: [
        TextButton(
          onPressed: widget.onClose,
          child: Text(tr('booking.common.ok')),
        ),
      ],
    );
  }

  Widget _buildDialogContent(bool isDarkMode) {
    if (_isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(tr('pickup.trip_details.loading')),
        ],
      );
    }

    if (_hasError || _tripData == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? tr('pickup.trip_details.not_found'),
            textAlign: TextAlign.center,
            style: isDarkMode
                ? AppTypography.dmBodyText.copyWith(color: Colors.red)
                : AppTypography.bodyText.copyWith(color: Colors.red),
          ),
        ],
      );
    }

    final trip = _tripData!;
    final statusColor = _getStatusColor(trip.status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(
          tr('pickup.trip_details.trip_code'),
          trip.tripCode,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          tr('pickup.trip_details.end_point'),
          trip.endPoint,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          tr('pickup.trip_details.robot_code'),
          trip.robotCode,
          isDarkMode,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tr('pickup.trip_details.status')}: ',
              style: isDarkMode
                  ? AppTypography.dmBodyText.copyWith(
                      fontWeight: FontWeight.w600,
                    )
                  : AppTypography.bodyText.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                _translateTripStatus(trip.status),
                style:
                    (isDarkMode
                            ? AppTypography.dmBodyText
                            : AppTypography.bodyText)
                        .copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
              ),
            ),
          ],
        ),
        if (trip.startTime != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            tr('pickup.trip_details.start_time'),
            DateFormat('dd/MM/yyyy HH:mm:ss').format(trip.startTime!),
            isDarkMode,
          ),
        ],
        if (trip.endTime != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            tr('pickup.trip_details.end_time'),
            DateFormat('dd/MM/yyyy HH:mm:ss').format(trip.endTime!),
            isDarkMode,
          ),
        ],
        if (trip.estimatedArrival != null) ...[
          const SizedBox(height: 12),
          _buildDetailRow(
            tr('pickup.trip_details.estimated_arrival'),
            trip.estimatedArrival!,
            isDarkMode,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: isDarkMode
              ? AppTypography.dmBodyText.copyWith(fontWeight: FontWeight.w600)
              : AppTypography.bodyText.copyWith(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: isDarkMode
                ? AppTypography.dmBodyText
                : AppTypography.bodyText,
          ),
        ),
      ],
    );
  }
}
