import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Reusable rounded icon container with category-specific tint and icon.
class CategoryBadge extends StatelessWidget {
  final String category;
  final double size;
  final double iconSize;

  const CategoryBadge({
    super.key,
    required this.category,
    this.size = 44,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppColors.getCategoryStyle(category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Icon(
          style.icon,
          color: style.color,
          size: iconSize,
        ),
      ),
    );
  }
}
