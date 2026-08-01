import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';

/// iOS "large title" nav bar pattern — a back chevron/trailing action row
/// plus an oversized title beneath, echoing the design's IOSNavBar.
class LargeTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LargeTitleAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(100);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const Spacer(),
                  ...actions,
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: colors.textPrimary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
