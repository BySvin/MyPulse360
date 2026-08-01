import 'package:flutter/material.dart';

import '../../../config/theme/app_radii.dart';
import '../../../config/theme/app_theme.dart';

/// iOS grouped inset-list container: optional uppercase header, rounded
/// card body, hairline dividers between [GroupedListTile] children.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, this.header, required this.children});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              header!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: colors.textSecondary,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadii.groupedList),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, indent: 16, color: colors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
