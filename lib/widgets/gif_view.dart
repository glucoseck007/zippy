import 'package:flutter/material.dart';

/// A widget that displays a GIF image with animation control and color customization
///
/// This is a custom implementation to replace the outdated `gif` package
/// that has compatibility issues with newer Flutter versions.
///
/// You can customize the color of the GIF by setting the `color` property:
/// ```dart
/// GifView(
///   image: AssetImage('assets/my_gif.gif'),
///   color: Colors.blue, // This will tint the GIF blue
///   colorBlendMode: BlendMode.srcIn, // Controls how the color is applied
/// )
/// ```
class GifView extends StatefulWidget {
  final ImageProvider image;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final bool autoPlay;
  final Duration? duration;
  final bool loop;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? color; // Added color property
  final BlendMode? colorBlendMode; // Added blend mode for the color

  const GifView({
    super.key,
    required this.image,
    this.fit,
    this.width,
    this.height,
    this.autoPlay = true,
    this.duration,
    this.loop = true,
    this.placeholder,
    this.errorWidget,
    this.color, // Optional color tint for the GIF
    this.colorBlendMode, // Blend mode to use with the color
  });

  @override
  State<GifView> createState() => _GifViewState();
}

class _GifViewState extends State<GifView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ImageInfo? _imageInfo;
  bool _isLoaded = false;
  bool _hasError = false;
  ImageStream? _imageStream;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? const Duration(milliseconds: 1000),
    );

    if (widget.autoPlay) {
      _controller.repeat();
    }

    _loadImage();
  }

  void _loadImage() {
    final ImageStream imageStream = widget.image.resolve(
      const ImageConfiguration(),
    );

    _imageStream = imageStream;
    imageStream.addListener(
      ImageStreamListener(_updateImage, onError: _onError),
    );
  }

  void _updateImage(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _imageInfo = imageInfo;
      _isLoaded = true;

      // Use a fixed default duration if not specified
      // Modern Flutter doesn't expose frameCount for GIFs
      if (widget.duration == null) {
        // Use a reasonable default duration for GIFs
        _controller.duration = const Duration(milliseconds: 1000);
        if (widget.autoPlay && !_controller.isAnimating) {
          _controller.repeat();
        }
      }
    });
  }

  void _onError(Object exception, StackTrace? stackTrace) {
    setState(() {
      _hasError = true;
    });
    debugPrint('Error loading GIF: $exception');
  }

  @override
  void dispose() {
    _controller.dispose();
    _imageStream?.removeListener(
      ImageStreamListener(_updateImage, onError: _onError),
    );
    super.dispose();
  }

  @override
  void didUpdateWidget(GifView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.image != oldWidget.image) {
      _isLoaded = false;
      _hasError = false;
      _loadImage();
    }

    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && widget.errorWidget != null) {
      return widget.errorWidget!;
    }

    if (!_isLoaded) {
      return widget.placeholder ??
          const Center(child: CircularProgressIndicator());
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return RawImage(
          image: _imageInfo?.image,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          color: widget.color,
          colorBlendMode:
              widget.colorBlendMode ??
              BlendMode.srcIn, // Apply the color with blend mode
        );
      },
    );
  }
}
