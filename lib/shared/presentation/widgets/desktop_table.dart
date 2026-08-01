import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';

/// A column heading for [DesktopTable]. [flex] must match the flex used by
/// the corresponding [Expanded] cell in each [DesktopTableRow].
class DesktopTableColumn {
  const DesktopTableColumn(this.label, {this.flex = 1});
  final String label;
  final int flex;
}

/// Desktop-dashboard data table: header row + bordered card + hairline row
/// dividers. The mobile-card equivalent of the same data stays in use below
/// [AppConstants.desktopBreakpoint] — pages choose which to render.
class DesktopTable extends StatelessWidget {
  const DesktopTable({super.key, required this.columns, required this.rows});

  final List<DesktopTableColumn> columns;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: colors.surfaceMuted,
            child: Row(
              children: [
                for (final column in columns)
                  Expanded(
                    flex: column.flex,
                    child: Text(
                      column.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One row of a [DesktopTable]. [cells] must be [Expanded] widgets whose
/// flex values line up with the table's [DesktopTableColumn]s.
class DesktopTableRow extends StatelessWidget {
  const DesktopTableRow({super.key, required this.cells, this.onTap});

  final List<Widget> cells;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: cells),
      ),
    );
  }
}
