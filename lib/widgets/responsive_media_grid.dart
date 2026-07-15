import 'package:flutter/material.dart';

/// A responsive poster grid that scales from 2 to 8 columns.
class ResponsiveMediaGrid extends StatelessWidget {
  const ResponsiveMediaGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.spacing = 16,
    this.targetItemWidth = 160,
    this.childAspectRatio = 0.56,
    this.minColumns = 2,
    this.maxColumns = 8,
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final double targetItemWidth;
  final double childAspectRatio;
  final int minColumns;
  final int maxColumns;
  final ScrollPhysics physics;
  final bool shrinkWrap;

  static int calculateColumnCount(
    double width, {
    double targetItemWidth = 160,
    double spacing = 16,
    int minColumns = 2,
    int maxColumns = 8,
  }) {
    if (width <= 0) return minColumns;
    final rawColumns = ((width + spacing) / (targetItemWidth + spacing))
        .floor();
    return rawColumns.clamp(minColumns, maxColumns);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            (constraints.maxWidth - resolvedPadding.horizontal).clamp(
              0.0,
              double.infinity,
            );
        final columns = calculateColumnCount(
          availableWidth,
          targetItemWidth: targetItemWidth,
          spacing: spacing,
          minColumns: minColumns,
          maxColumns: maxColumns,
        );

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
