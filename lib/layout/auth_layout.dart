import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:zippy/design/app_typography.dart';

class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key});

  @override
  State<AuthLayout> createState() => _AuthLayout();
}

class _AuthLayout extends State<AuthLayout> {

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(tr('login'), style: AppTypography.heading),
              Text(tr('login_subtitle'), style: AppTypography.titleText)
            ],
          ),
        ),
      ),
    );
  }
}
