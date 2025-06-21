import 'package:flutter/material.dart';
import '../app.dart';

/// A manager for showing snackbars consistently throughout the app
/// This prevents multiple snackbars from being shown at the same time
class SnackbarManager {
  static final SnackbarManager _instance = SnackbarManager._internal();

  factory SnackbarManager() {
    return _instance;
  }

  SnackbarManager._internal();

  // Track currently visible snackbar
  SnackBar? _currentSnackbar;
  bool _isSnackbarVisible = false;

  /// Show a snackbar with the given content and optional settings
  void showSnackBar({
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any existing snackbar
    if (_isSnackbarVisible) {
      rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    }

    // Create new snackbar
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      margin: const EdgeInsets.all(8),
      // Track when this snackbar is dismissed
      onVisible: () {
        _isSnackbarVisible = true;
      },
    );

    _currentSnackbar = snackBar;

    // Show the new snackbar and track when it's dismissed
    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar).closed.then((
      _,
    ) {
      if (_currentSnackbar == snackBar) {
        _isSnackbarVisible = false;
        _currentSnackbar = null;
      }
    });
  }

  /// Show a success snackbar
  void showSuccessSnackBar(String message) {
    showSnackBar(
      message: message,
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    );
  }

  /// Show an error snackbar
  void showErrorSnackBar(String message) {
    showSnackBar(
      message: message,
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
    );
  }

  /// Show a warning snackbar
  void showWarningSnackBar(String message) {
    showSnackBar(
      message: message,
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
    );
  }

  /// Show an info snackbar
  void showInfoSnackBar(String message) {
    showSnackBar(
      message: message,
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 2),
    );
  }
}
