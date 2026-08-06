import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'status_indicator.dart';

class FuturisticAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const FuturisticAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.neonCyan.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Orbitron',
                letterSpacing: 2,
                color: AppTheme.neonCyan,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            const StatusIndicator(label: 'ONLINE', active: true),
          ],
        ),
        actions: actions ??
            [
              IconButton(
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () {},
              ),
            ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}