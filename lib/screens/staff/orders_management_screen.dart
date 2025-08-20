import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/models/entity/staff/order.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/services/staff/staff_order_service.dart';

class OrdersManagementScreen extends ConsumerStatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  ConsumerState<OrdersManagementScreen> createState() =>
      _OrdersManagementScreenState();
}

class _OrdersManagementScreenState
    extends ConsumerState<OrdersManagementScreen> {
  List<StaffOrder> _orders = [];
  List<StaffOrder> _filteredOrders = [];
  String _selectedStatus = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await StaffOrderService.getAllOrders();
      setState(() {
        _orders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterOrders(String status) {
    setState(() {
      _selectedStatus = status;
      if (status == 'All') {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders
            .where(
              (order) =>
                  order.status.toUpperCase() == status.toUpperCase() ||
                  (status == 'Pending' &&
                      order.status.toUpperCase() == 'PENDING') ||
                  (status == 'In Progress' &&
                      order.status.toUpperCase() == 'IN_PROGRESS') ||
                  (status == 'Delivered' &&
                      order.status.toUpperCase() == 'DELIVERED') ||
                  (status == 'Finished' &&
                      order.status.toUpperCase() == 'FINISHED'),
            )
            .toList();
      }
    });
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
        backgroundColor: isDarkMode
            ? AppColors.dmBackgroundColor
            : AppColors.backgroundColor,
        elevation: 0,
        title: Text(
          tr('staff.orders.title'),
          style: isDarkMode
              ? AppTypography.dmHeading(context)
              : AppTypography.heading(context),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip('All', _selectedStatus == 'All', isDarkMode),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'Pending',
                    _selectedStatus == 'Pending',
                    isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'In Progress',
                    _selectedStatus == 'In Progress',
                    isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'Delivered',
                    _selectedStatus == 'Delivered',
                    isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'Finished',
                    _selectedStatus == 'Finished',
                    isDarkMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Orders list
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.buttonColor,
                      ),
                    )
                  : _filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: isDarkMode
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('staff.orders.no_orders'),
                            style: isDarkMode
                                ? AppTypography.dmBodyText(context)
                                : AppTypography.bodyText(context),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return _buildOrderCard(order, isDarkMode);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _filterOrders(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.buttonColor
              : isDarkMode
              ? AppColors.dmCardColor
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : isDarkMode
                ? Colors.white70
                : Colors.black87,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(StaffOrder order, bool isDarkMode) {
    Color statusColor = _getStatusColor(order.status);
    DateTime? orderTime = DateTime.tryParse(order.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? AppColors.dmCardColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.orderCode,
                  style: isDarkMode
                      ? AppTypography.dmTitleText(context)
                      : AppTypography.titleText(context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getDisplayStatus(order.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.productName,
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.location_on,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  order.endpoint,
                  style: isDarkMode
                      ? AppTypography.dmBodyText(context)
                      : AppTypography.bodyText(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  orderTime != null
                      ? DateFormat('MMM dd, HH:mm').format(orderTime)
                      : order.createdAt,
                  style: isDarkMode
                      ? AppTypography.dmBodyText(context)
                      : AppTypography.bodyText(context),
                ),
                if (order.robotCode != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.smart_toy,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.robotCode!,
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                ],
              ],
            ),
            if (order.price > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '\$${order.price.toStringAsFixed(2)}',
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          )
                        : AppTypography.bodyText(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                  ),
                ],
              ),
            ],
            if (order.status.toUpperCase() == 'PENDING') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        tr('staff.orders.approve'),
                        style: AppTypography.buttonText(
                          context,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAssignRobotDialog(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonColor,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        tr('staff.orders.assign_robot'),
                        style: AppTypography.buttonText(
                          context,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'FINISHED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDisplayStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return 'In Progress';
      case 'DELIVERED':
        return 'Delivered';
      case 'FINISHED':
        return 'Finished';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Future<void> _approveOrder(StaffOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final themeState = ref.read(themeProvider);
        final isDarkMode = themeState.isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tr('staff.orders.approve_order'),
            style: isDarkMode
                ? AppTypography.dmHeading(context)
                : AppTypography.heading(context),
          ),
          content: Text(
            '${tr('staff.orders.approve_confirmation')} ${order.orderCode}?',
            style: isDarkMode
                ? AppTypography.dmBodyText(context)
                : AppTypography.bodyText(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                tr('common.cancel'),
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(tr('staff.orders.approve')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final success = await StaffOrderService.approveOrder(order.orderId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${order.orderCode} approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadOrders(); // Refresh the list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve order ${order.orderCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAssignRobotDialog(StaffOrder order) {
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
            tr('staff.orders.assign_robot_title'),
            style: isDarkMode
                ? AppTypography.dmHeading(context)
                : AppTypography.heading(context),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tr('staff.orders.assign_robot_message')} ${order.orderCode}',
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
              ),
              const SizedBox(height: 16),
              // Robot selection list (mock data for now)
              ...List.generate(
                3,
                (index) => ListTile(
                  leading: Icon(Icons.smart_toy, color: Colors.green),
                  title: Text(
                    'ROBOT-${(index + 1).toString().padLeft(3, '0')}',
                  ),
                  subtitle: Text(
                    'Battery: ${85 - (index * 10)}% | Zone ${String.fromCharCode(65 + index)}',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _assignRobot(
                      order,
                      'ROBOT-${(index + 1).toString().padLeft(3, '0')}',
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('common.cancel'),
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignRobot(StaffOrder order, String robotCode) async {
    try {
      final success = await StaffOrderService.assignRobot(
        order.orderId,
        robotCode,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${order.orderCode} assigned to $robotCode'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrders(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign robot to ${order.orderCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning robot: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
