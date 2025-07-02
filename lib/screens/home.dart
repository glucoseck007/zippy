import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:zippy/constants/screen_size.dart';
import 'package:zippy/models/entity/location/location.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/screens/booking/booking_screen.dart';
import 'package:zippy/screens/payment/payment_screen.dart';
import 'package:zippy/screens/pickup/pickup_screen.dart';
import 'package:zippy/utils/navigation_manager.dart';
import '../design/app_typography.dart';
import '../design/app_colors.dart';
import '../components/service_item.dart';
import '../components/custom_place_card.dart';
import '../components/navigation_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Add a GlobalKey for the Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Location> locations = [
    Location(
      name: 'Tòa Alpha',
      estimatedTime: 5,
      position: const LatLng(21.013227, 105.527038),
    ),
    Location(
      name: 'Tòa Beta',
      estimatedTime: 5,
      position: const LatLng(21.013858, 105.525462),
    ),
    Location(
      name: 'Tòa Gamma',
      estimatedTime: 5,
      position: const LatLng(21.013371, 105.523582),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<ServiceItem> services = [
      ServiceItem(
        text: tr('home.services.book'),
        onTap: () {
          NavigationManager.navigateToWithSlideTransition(
            context,
            BookingScreen(),
          );
        },
        icon: LucideIcons.truck,
        backgroundColor: Color(0xffFA4032),
        iconColor: Color(0xfffFEF3E2),
        textColor: Color(0xfffFEF3E2),
      ),
      ServiceItem(
        text: tr('home.services.pickup'),
        onTap: () {
          NavigationManager.navigateToWithSlideTransition(
            context,
            const PickupScreen(),
          );
        },
        icon: LucideIcons.package,
        backgroundColor: Color(0xffFA812F),
        iconColor: Color(0xfffFEF3E2),
        textColor: Color(0xfffFEF3E2),
      ),
      ServiceItem(
        text: tr('home.services.payment'),
        onTap: () {
          NavigationManager.navigateToWithSlideTransition(
            context,
            const PaymentScreen(),
          );
        },
        icon: LucideIcons.creditCard,
        backgroundColor: Color(0xffFAB12F),
        iconColor: Color(0xfffFEF3E2),
        textColor: Color(0xfffFEF3E2),
      ),
    ];
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.isDarkMode;
    // For now, user is null since the current auth provider doesn't track user data
    // This should be updated when user management is added to the auth provider
    const user = null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode
          ? AppColors.dmBackgroundColor
          : AppColors.backgroundColor,
      drawer: const AppNavigationDrawer(),
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
                    InkWell(
                      onTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: Container(
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
                      style: isDarkMode
                          ? AppTypography.dmBodyText
                          : AppTypography.bodyText,
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

              // Building List
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    CustomPlaceCard(
                      name: locations[0].name,
                      deliveryTime: '${locations[0].estimatedTime} min',
                      isFreeDelivery: true,
                      location: locations[0].position,
                    ),
                    CustomPlaceCard(
                      name: locations[1].name,
                      deliveryTime: '${locations[1].estimatedTime} min',
                      isFreeDelivery: true,
                      location: locations[1].position,
                    ),
                    CustomPlaceCard(
                      name: locations[2].name,
                      deliveryTime: '${locations[2].estimatedTime} min',
                      isFreeDelivery: true,
                      location: locations[2].position,
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
