import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/providers/robot/robot_provider.dart';
import 'package:zippy/models/entity/robot/robot.dart' as RobotModel;

class RobotsScreen extends ConsumerStatefulWidget {
  const RobotsScreen({super.key});

  @override
  ConsumerState<RobotsScreen> createState() => _RobotsScreenState();
}

class _RobotsScreenState extends ConsumerState<RobotsScreen> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Load robots when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(robotProvider.notifier).loadRobots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;
    final robotState = ref.watch(robotProvider);

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
          tr('staff.robots.title'),
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
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(robotProvider.notifier).loadRobots();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status filter chips
            Row(
              children: [
                _buildStatusChip('All', _selectedFilter == 'All', isDarkMode),
                const SizedBox(width: 8),
                _buildStatusChip(
                  'Online',
                  _selectedFilter == 'Online',
                  isDarkMode,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  'Offline',
                  _selectedFilter == 'Offline',
                  isDarkMode,
                ),
                const SizedBox(width: 8),
                _buildStatusChip('Busy', _selectedFilter == 'Busy', isDarkMode),
              ],
            ),
            const SizedBox(height: 16),

            // Robots list based on state
            Expanded(child: _buildRobotsList(robotState, isDarkMode)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, bool isDarkMode) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
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

  Widget _buildRobotsList(robotState, bool isDarkMode) {
    // Loading state
    if (robotState.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              tr('staff.robots.loading'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
            ),
          ],
        ),
      );
    }

    // Error state
    if (robotState.isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              robotState.errorMessage ?? tr('staff.robots.error_loading'),
              style: isDarkMode
                  ? AppTypography.dmBodyText(context)
                  : AppTypography.bodyText(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(robotProvider.notifier).loadRobots();
              },
              child: Text(tr('staff.robots.retry')),
            ),
          ],
        ),
      );
    }

    // Loaded state
    if (robotState.isLoaded) {
      final List<RobotModel.Robot> allRobots = [
        ...robotState.freeRobots.cast<RobotModel.Robot>(),
        ...robotState.busyRobots.cast<RobotModel.Robot>(),
      ];

      // Filter robots based on selected filter
      final filteredRobots = _filterRobots(allRobots);

      if (filteredRobots.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 64,
                color: Colors.grey.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'All'
                    ? tr('staff.robots.no_robots')
                    : tr(
                        'staff.robots.no_robots_filter',
                        args: [_selectedFilter],
                      ),
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: filteredRobots.length,
        itemBuilder: (context, index) {
          final robot = filteredRobots[index];
          return _buildRobotCard(robot: robot, isDarkMode: isDarkMode);
        },
      );
    }

    // Initial state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            tr('staff.robots.tap_refresh'),
            style: isDarkMode
                ? AppTypography.dmBodyText(context)
                : AppTypography.bodyText(context),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(robotProvider.notifier).loadRobots();
            },
            child: Text(tr('staff.robots.load_robots')),
          ),
        ],
      ),
    );
  }

  List<RobotModel.Robot> _filterRobots(List<RobotModel.Robot> robots) {
    switch (_selectedFilter) {
      case 'Online':
        return robots
            .where((robot) => robot.online && robot.status == 'free')
            .toList();
      case 'Offline':
        return robots.where((robot) => !robot.online).toList();
      case 'Busy':
        return robots
            .where((robot) => robot.online && robot.status != 'free')
            .toList();
      default: // 'All'
        return robots;
    }
  }

  Widget _buildRobotCard({
    required RobotModel.Robot robot,
    required bool isDarkMode,
  }) {
    // Determine robot status for display
    String displayStatus;
    Color statusColor;

    if (!robot.online) {
      displayStatus = 'Offline';
      statusColor = Colors.red;
    } else if (robot.status == 'free') {
      displayStatus = 'Online';
      statusColor = Colors.green;
    } else {
      displayStatus = 'Busy';
      statusColor = Colors.orange;
    }

    // Get container stats
    final totalContainers = robot.freeContainers.length;
    final availableContainers = robot.freeContainers
        .where((c) => c.isAvailable)
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? AppColors.dmCardColor : Colors.white,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              robot.displayName,
              style: isDarkMode
                  ? AppTypography.dmTitleText(context)
                  : AppTypography.titleText(context),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayStatus,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Robot info row
              Row(
                children: [
                  Icon(
                    Icons.battery_std,
                    color: (robot.batteryLevel ?? 75) > 50
                        ? Colors.green
                        : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${robot.batteryLevel ?? 75}%',
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      robot.currentLocation ??
                          tr('staff.robots.unknown_location'),
                      style: isDarkMode
                          ? AppTypography.dmBodyText(context)
                          : AppTypography.bodyText(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Container summary row
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tr(
                      'staff.robots.containers_summary',
                      args: [
                        availableContainers.toString(),
                        totalContainers.toString(),
                      ],
                    ),
                    style: isDarkMode
                        ? AppTypography.dmBodyText(context)
                        : AppTypography.bodyText(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          // Container details section
          if (totalContainers > 0) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('staff.robots.container_details'),
                style:
                    (isDarkMode
                            ? AppTypography.dmSubTitleText(context)
                            : AppTypography.subTitleText(context))
                        .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ...robot.freeContainers.map(
              (container) => _buildContainerRow(container, isDarkMode),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr('staff.robots.no_containers'),
                    style:
                        (isDarkMode
                                ? AppTypography.dmBodyText(context)
                                : AppTypography.bodyText(context))
                            .copyWith(color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContainerRow(RobotModel.Container container, bool isDarkMode) {
    final isAvailable = container.isAvailable;
    final statusColor = isAvailable ? Colors.green : Colors.red;
    final statusText = isAvailable
        ? tr('staff.robots.available')
        : tr('staff.robots.occupied');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.inventory_2, color: statusColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    container.displayName,
                    style:
                        (isDarkMode
                                ? AppTypography.dmBodyText(context)
                                : AppTypography.bodyText(context))
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (!isAvailable && container.occupiedBy != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      tr(
                        'staff.robots.occupied_by',
                        args: [container.occupiedBy!],
                      ),
                      style:
                          (isDarkMode
                                  ? AppTypography.dmBodyText(context)
                                  : AppTypography.bodyText(context))
                              .copyWith(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
