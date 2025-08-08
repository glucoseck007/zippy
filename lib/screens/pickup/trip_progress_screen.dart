import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/services/api_client.dart';

class TripProgressScreen extends ConsumerStatefulWidget {
  final String tripCode;
  final String orderCode;

  const TripProgressScreen({
    super.key,
    required this.tripCode,
    required this.orderCode,
  });

  @override
  ConsumerState<TripProgressScreen> createState() => _TripProgressScreenState();
}

class _TripProgressScreenState extends ConsumerState<TripProgressScreen>
    with TickerProviderStateMixin {
  Timer? _progressTimer;
  double _progress = 0.0;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  late AnimationController _robotAnimationController;
  late Animation<double> _robotAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startProgressUpdates();
  }

  void _setupAnimations() {
    _robotAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _robotAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _robotAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _robotAnimationController.repeat(reverse: true);
  }

  void _startProgressUpdates() {
    _fetchProgress();
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchProgress();
    });
  }

  Future<void> _fetchProgress() async {
    try {
      final response = await ApiClient.get('/trip/progress/${widget.tripCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // Parse the nested response structure
            if (jsonData['success'] == true && jsonData['data'] != null) {
              final data = jsonData['data'];
              _progress = (data['progress'] ?? 0.0).toDouble() / 100.0;
            } else {
              _progress = 0.0;
            }
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to fetch progress';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Network error occurred';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _robotAnimationController.dispose();
    super.dispose();
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
          tr('pickup.trip_progress.title'),
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
              tr('pickup.trip_progress.loading'),
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
                _errorMessage ?? tr('pickup.trip_progress.error'),
                textAlign: TextAlign.center,
                style:
                    (isDarkMode
                            ? AppTypography.dmSubTitleText(context)
                            : AppTypography.subTitleText(context))
                        .copyWith(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                  _fetchProgress();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr('pickup.trip_progress.retry')),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Trip information card
          Card(
            color: isDarkMode ? AppColors.dmCardColor : Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: isDarkMode
                            ? AppColors.dmButtonColor
                            : AppColors.buttonColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tr('pickup.order_code')}: ${widget.orderCode}',
                        style:
                            (isDarkMode
                                    ? AppTypography.dmSubTitleText(context)
                                    : AppTypography.subTitleText(context))
                                .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        color: isDarkMode
                            ? AppColors.dmButtonColor
                            : AppColors.buttonColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${tr('pickup.trip_code')}: ${widget.tripCode}',
                        style: isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Progress visualization
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Progress bar container with robot positioned above
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Column(
                      children: [
                        // Space for robot and arrow
                        const SizedBox(height: 120),

                        // Progress bar
                        Container(
                          width: double.infinity,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.grey[600]!
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[100],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDarkMode
                                    ? AppColors.dmSuccessColor
                                    : AppColors.successColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Robot and arrow positioned based on progress
                    Positioned(
                      top: 0,
                      left:
                          _progress *
                          (MediaQuery.of(context).size.width -
                              48 -
                              80), // Account for padding and robot width
                      child: Column(
                        children: [
                          // Robot with animation
                          AnimatedBuilder(
                            animation: _robotAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _robotAnimation.value * 10),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? AppColors.dmButtonColor
                                        : AppColors.buttonColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isDarkMode
                                                    ? AppColors.dmButtonColor
                                                    : AppColors.buttonColor)
                                                .withOpacity(0.3),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.smart_toy,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          // Arrow pointing down
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 30,
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Progress percentage
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  style:
                      (isDarkMode
                              ? AppTypography.dmHeading(context)
                              : AppTypography.heading(context))
                          .copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.dmSuccessColor
                                : AppColors.successColor,
                          ),
                ),

                const SizedBox(height: 8),

                Text(
                  tr('pickup.trip_progress.progress_label'),
                  style: isDarkMode
                      ? AppTypography.dmBodyText(
                          context,
                        ).copyWith(color: Colors.grey[400])
                      : AppTypography.bodyText(
                          context,
                        ).copyWith(color: Colors.grey[600]),
                ),

                const SizedBox(height: 40),

                // Status message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        (isDarkMode
                                ? AppColors.dmSuccessColor
                                : AppColors.successColor)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          (isDarkMode
                                  ? AppColors.dmSuccessColor
                                  : AppColors.successColor)
                              .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.delivery_dining,
                        color: isDarkMode
                            ? AppColors.dmSuccessColor
                            : AppColors.successColor,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _progress >= 1.0
                            ? tr('pickup.trip_progress.completed')
                            : tr('pickup.trip_progress.in_progress'),
                        textAlign: TextAlign.center,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? AppColors.dmSuccessColor
                                      : AppColors.successColor,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
