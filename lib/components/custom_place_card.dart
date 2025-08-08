import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../providers/core/theme_provider.dart';
import './mini_map_widget.dart';

class CustomPlaceCard extends ConsumerWidget {
  final String name;
  final String? description;
  final double? rating;
  final String deliveryTime;
  final bool isFreeDelivery;
  final String? imageUrl; // Optional image URL for restaurant image
  final LatLng?
  location; // Optional LatLng for displaying a map instead of an image

  const CustomPlaceCard({
    super.key,
    required this.name,
    this.description,
    this.rating,
    required this.deliveryTime,
    this.isFreeDelivery = false,
    this.imageUrl,
    this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProviderState = ref.watch(themeProvider);
    final isDarkMode = themeProviderState.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.dmCardColor : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withAlpha(51) // 0.2 opacity = 51/255
                : Colors.black.withAlpha(13), // 0.05 opacity = 13/255
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant image or map
          location != null
              ? MiniMapWidget(
                  location: location!,
                  height: 150,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                )
              : Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.dmCardColor
                        : AppColors.cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    image: imageUrl != null && imageUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: isDarkMode
                      ? AppTypography.dmTitleText(context)
                      : AppTypography.titleText(context),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // const Icon(
                    //   Icons.star,
                    //   color: AppColors.buttonColor,
                    //   size: 20,
                    // ),
                    // const SizedBox(width: 4),
                    // Text(
                    //   rating.toString(),
                    //   style:
                    //       (isDarkMode
                    //               ? AppTypography.dmBodyText
                    //               : AppTypography.bodyText)
                    //           .copyWith(fontWeight: FontWeight.bold),
                    // ),
                    // const SizedBox(width: 12),
                    if (isFreeDelivery) ...[
                      Icon(
                        Icons.delivery_dining,
                        color: isDarkMode
                            ? AppColors.dmSuccessColor
                            : AppColors.successColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Free',
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  color: isDarkMode
                                      ? AppColors.dmSuccessColor
                                      : AppColors.successColor,
                                ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                      Icons.timer,
                      color: isDarkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deliveryTime,
                      style: isDarkMode
                          ? AppTypography.dmBodyText(context)
                          : AppTypography.bodyText(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
