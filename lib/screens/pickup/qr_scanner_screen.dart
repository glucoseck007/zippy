import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zippy/design/app_colors.dart';
import 'package:zippy/design/app_typography.dart';
import 'package:zippy/providers/core/theme_provider.dart';
import 'package:zippy/screens/pickup/pickup_screen.dart';
import 'package:zippy/utils/navigation_manager.dart';
import 'package:zippy/widgets/pickup/otp_verification_dialog.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  final Function(String) onScanned;

  const QRScannerScreen({super.key, required this.onScanned});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;
  late BuildContext _navigatorContext;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save a reference to the navigator context
    _navigatorContext = context;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr('pickup.qr_scan.title')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on),
            iconSize: 32.0,
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flip_camera_ios),
            iconSize: 32.0,
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr('pickup.qr_scan.instruction'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return; // Prevent multiple scans

    final List<Barcode> barcodes = capture.barcodes;

    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          _isScanned = true;
        });

        // Stop the camera
        cameraController.stop();

        // Call the callback with scanned data
        widget.onScanned(barcode.rawValue!);

        // Navigate to pickup screen with slide transition
        if (mounted) {
          NavigationManager.navigateToWithSlideTransition(
            context,
            const PickupScreen(),
          );

          // Show OTP verification dialog after a short delay to ensure navigation is complete
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _showOTPVerificationDialog(barcode.rawValue!);
            }
          });
        }
      }
    }
  }

  void _showOTPVerificationDialog(String qrData) {
    // Parse the JSON data from QR code
    Map<String, dynamic>? parsedData;
    String orderCode = '';
    String tripCode = '';
    String robotCode = '';
    String timestamp = '';

    try {
      parsedData = jsonDecode(qrData);
      orderCode = parsedData?['orderCode'] ?? '';
      tripCode = parsedData?['tripCode'] ?? '';
      robotCode = parsedData?['robotCode'] ?? '';
      timestamp = parsedData?['timestamp'] ?? '';

      print(
        'QRScanner: Parsed QR data - orderCode: $orderCode, tripCode: $tripCode, robotCode: $robotCode',
      );
    } catch (e) {
      // If JSON parsing fails, treat the entire string as order code
      orderCode = qrData;
      print(
        'QRScanner: Failed to parse QR JSON, using as orderCode: $orderCode',
      );
    }

    final themeState = ref.read(themeProvider);
    final isDarkMode = themeState.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.dmCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tr('pickup.qr_scan.confirm_title'),
            style: isDarkMode
                ? AppTypography.dmHeading(context)
                : AppTypography.heading(context),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 60,
                color: isDarkMode ? AppColors.dmSuccessColor : Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                tr('pickup.qr_scan.confirm_message'),
                style: isDarkMode
                    ? AppTypography.dmBodyText(context)
                    : AppTypography.bodyText(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppColors.dmInputColor.withOpacity(0.5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode
                        ? AppColors.dmInputColor
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (orderCode.isNotEmpty) ...[
                      Text(
                        '${tr('pickup.qr_scan.order_code')}: $orderCode',
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (tripCode.isNotEmpty) ...[
                      Text(
                        '${tr('pickup.qr_scan.trip_code')}: $tripCode',
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (timestamp.isNotEmpty) ...[
                      Text(
                        '${tr('pickup.qr_scan.timestamp')}: ${_formatTimestamp(timestamp)}',
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? AppColors.dmDefaultColor.withOpacity(
                                          0.7,
                                        )
                                      : Colors.grey,
                                ),
                      ),
                    ],
                    // If no valid data was parsed, show the raw data
                    if (orderCode.isEmpty && tripCode.isEmpty) ...[
                      Text(
                        qrData,
                        style:
                            (isDarkMode
                                    ? AppTypography.dmBodyText(context)
                                    : AppTypography.bodyText(context))
                                .copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close confirmation dialog
                // Return to previous screen (this will go back to where QR scanner was called from)
              },
              child: Text(
                tr('pickup.qr_scan.cancel'),
                style:
                    (isDarkMode
                            ? AppTypography.dmBodyText(context)
                            : AppTypography.bodyText(context))
                        .copyWith(
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close confirmation dialog
                // Show OTP verification dialog using the order code and trip code
                _showOTPDialog(
                  orderCode.isNotEmpty ? orderCode : qrData,
                  tripCode,
                  robotCode,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? AppColors.dmButtonColor
                    : AppColors.buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(tr('pickup.qr_scan.confirm')),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return timestamp; // Return original if parsing fails
    }
  }

  void _showOTPDialog(String orderCode, String tripCode, String robotCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return OTPVerificationDialog(
          orderCode: orderCode,
          tripCode: tripCode,
          robotCode: robotCode,
          onSuccess: () {
            // Handle successful OTP verification
            // The success dialog will be shown and closed by the OTP dialog
            // We need to refresh the pickup screen after the success dialog is dismissed

            // Use a delayed callback to ensure all dialogs are closed
            Future.delayed(const Duration(milliseconds: 500), () {
              // Check if the widget is still mounted and context is still valid
              if (mounted && _navigatorContext.mounted) {
                try {
                  // Clear the navigation stack and navigate to a fresh pickup screen
                  Navigator.of(_navigatorContext).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const PickupScreen(),
                    ),
                    (route) => route.isFirst,
                  );
                } catch (e) {
                  // If navigation fails, fallback to simple replacement
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const PickupScreen(),
                      ),
                    );
                  }
                }
              }
            });
          },
        );
      },
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
