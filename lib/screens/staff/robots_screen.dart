import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/core/theme_provider.dart';

class RobotsScreen extends ConsumerStatefulWidget {
  const RobotsScreen({super.key});

  @override
  ConsumerState<RobotsScreen> createState() => _RobotsScreenState();
}

class _RobotsScreenState extends ConsumerState<RobotsScreen> {
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status filter chips
            Row(
              children: [
                _buildStatusChip('All', true, isDarkMode),
                const SizedBox(width: 8),
                _buildStatusChip('Online', false, isDarkMode),
                const SizedBox(width: 8),
                _buildStatusChip('Offline', false, isDarkMode),
                const SizedBox(width: 8),
                _buildStatusChip('Busy', false, isDarkMode),
              ],
            ),
            const SizedBox(height: 16),

            // Robots list
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Mock data
                itemBuilder: (context, index) {
                  return _buildRobotCard(
                    robotId: 'ROBOT-${(index + 1).toString().padLeft(3, '0')}',
                    status: index % 3 == 0
                        ? 'Online'
                        : index % 3 == 1
                        ? 'Busy'
                        : 'Offline',
                    batteryLevel: 85 - (index * 10),
                    currentLocation: 'Zone ${String.fromCharCode(65 + index)}',
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, bool isDarkMode) {
    return Container(
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
    );
  }

  Widget _buildRobotCard({
    required String robotId,
    required String status,
    required int batteryLevel,
    required String currentLocation,
    required bool isDarkMode,
  }) {
    Color statusColor = status == 'Online'
        ? Colors.green
        : status == 'Busy'
        ? Colors.orange
        : Colors.red;

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
                  robotId,
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
                    status,
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
                  Icons.battery_std,
                  color: batteryLevel > 50 ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$batteryLevel%',
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
                Text(
                  currentLocation,
                  style: isDarkMode
                      ? AppTypography.dmBodyText(context)
                      : AppTypography.bodyText(context),
                ),
              ],
            ),
            if (status == 'Busy') ...[
              const SizedBox(height: 8),
              Text(
                'Current Task: Delivering Order #12345',
                style:
                    (isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context))
                        .copyWith(color: Colors.orange, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
