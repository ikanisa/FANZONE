import 'package:flutter/material.dart';

class ReviewDevicePreset {
  const ReviewDevicePreset({
    required this.name,
    required this.width,
    required this.height,
  });

  final String name;
  final double width;
  final double height;

  Size get size => Size(width, height);
}

abstract final class ReviewDevicePresets {
  static const pixel4a = ReviewDevicePreset(
    name: 'Pixel 4a',
    width: 393,
    height: 851,
  );
  static const androidCompact = ReviewDevicePreset(
    name: 'Android Compact',
    width: 360,
    height: 800,
  );
  static const iPhoneCompact = ReviewDevicePreset(
    name: 'iPhone Compact',
    width: 390,
    height: 844,
  );
  static const iPhoneLarge = ReviewDevicePreset(
    name: 'iPhone Large',
    width: 430,
    height: 932,
  );
  static const smallTablet = ReviewDevicePreset(
    name: 'Small Tablet',
    width: 768,
    height: 1024,
  );

  static const all = <ReviewDevicePreset>[
    pixel4a,
    androidCompact,
    iPhoneCompact,
    iPhoneLarge,
    smallTablet,
  ];
}
