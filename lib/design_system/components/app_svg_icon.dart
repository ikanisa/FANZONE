import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens/app_colors.dart';
import 'app_icons.dart';

class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = AppColors.text,
  });

  final AppIconName name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final path = AppIcons.svg(name);
    if (path == null) {
      return Icon(AppIcons.data(name), size: size, color: color);
    }

    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
