import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final num width;
  final num height;
  final Color backgroundColor;
  final String? title;
  final String? imagePath;

  const CustomCard({
    super.key,
    required this.width,
    required this.height,
    required this.backgroundColor,
    this.title,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      child: SizedBox(
        width: width.toDouble(),
        height: height.toDouble(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null && imagePath!.isNotEmpty)
              Image.asset(imagePath!, fit: BoxFit.cover),
            if (title != null && title!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(title!, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
