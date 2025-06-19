import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/models/location.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../design/app_typography.dart';
import '../design/app_colors.dart';
import '../components/service_item.dart';
import '../components/custom_place_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ServiceItem> services = [
    ServiceItem(
      text: tr('home.services.book'),
      onTap: () {},
      icon: LucideIcons.truck,
      backgroundColor: Color(0xff9ACBD0),
      iconColor: Color(0xfffF2EFE7),
      textColor: Color(0xfffF2EFE7),
    ),
    ServiceItem(
      text: tr('home.services.pickup'),
      onTap: () {},
      icon: LucideIcons.package,
      backgroundColor: Color(0xff48A6A7),
      iconColor: Color(0xfffF2EFE7),
      textColor: Color(0xfffF2EFE7),
    ),
    ServiceItem(
      text: tr('home.services.payment'),
      onTap: () {},
      icon: LucideIcons.creditCard,
      backgroundColor: Color(0xff006A71),
      iconColor: Color(0xfffF2EFE7),
      textColor: Color(0xfffF2EFE7),
    ),
  ];

  final List<Location> locations = [
    Location(name: 'Rose Garden', estimatedTime: 20),
    Location(name: 'Tasty Treats', estimatedTime: 20),
    Location(name: 'Spice Paradise', estimatedTime: 20),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.dmBackgroundColor
          : Colors.grey.shade100,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Bar Section
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.dmCardColor
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Delivery Location
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('home.welcome'),
                    style: isDarkMode
                        ? AppTypography.dmTitleText
                        : AppTypography.titleText,
                  ),
                  const SizedBox(height: 4),
                ],
              ),

              // Greeting
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text:
                          'Hey ${user?.fullName.split(' ').first ?? 'Guest'}, ',
                      style: isDarkMode
                          ? AppTypography.dmBodyText.copyWith(fontSize: 16)
                          : AppTypography.bodyText.copyWith(fontSize: 16),
                    ),
                    TextSpan(
                      text: tr('home.hru'),
                      style: isDarkMode
                          ? AppTypography.dmTitleText.copyWith(fontSize: 16)
                          : AppTypography.titleText.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.dmInputColor
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_city,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('home.search_placeholder'),
                      style: AppTypography.bodyText,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Services Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('home.services.title'),
                    style: isDarkMode
                        ? AppTypography.dmTitleText
                        : AppTypography.titleText,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Services List
              SizedBox(
                height: ScreenSize.height(context) * 0.1,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    // Get the existing service item
                    final serviceItem = services[index];
                    // Return a new service item with updated isSelected and onTap

                    return ServiceItem(
                      text: serviceItem.text,
                      textColor: serviceItem.textColor,
                      icon: serviceItem.icon, // Keep the icon from the list
                      backgroundColor: serviceItem.backgroundColor,
                      iconColor: serviceItem.iconColor,
                      onTap: () {
                        serviceItem.onTap();
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Open Restaurants
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('home.near_by'),
                    style: isDarkMode
                        ? AppTypography.dmTitleText
                        : AppTypography.titleText,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Restaurant List
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    CustomPlaceCard(
                      name: locations[0].name,
                      deliveryTime: '${locations[0].estimatedTime} min',
                      isFreeDelivery: true,
                    ),
                    CustomPlaceCard(
                      name: locations[1].name,
                      deliveryTime: '${locations[1].estimatedTime} min',
                      isFreeDelivery: true,
                    ),
                    CustomPlaceCard(
                      name: locations[2].name,
                      deliveryTime: '${locations[2].estimatedTime} min',
                      isFreeDelivery: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
