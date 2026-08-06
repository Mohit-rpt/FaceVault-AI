// lib/navigation/app_shell.dart

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/persons/persons_screen.dart';
import '../features/registration/registration_screen.dart';
import '../features/recognition/recognition_screen.dart';
import '../features/camera/camera_screen.dart';
import '../features/unknown/unknown_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    _NavItem(icon: Icons.people_outline, label: 'Persons'),
    _NavItem(icon: Icons.person_add_outlined, label: 'Register'),
    _NavItem(icon: Icons.face, label: 'Recognition'),
    _NavItem(icon: Icons.videocam_outlined, label: 'Camera'),
    _NavItem(icon: Icons.help_outline, label: 'Unknown'),
    _NavItem(icon: Icons.analytics_outlined, label: 'Analytics'),
    _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  final List<Widget> _pages = const [
    DashboardScreen(),
    PersonsScreen(),
    RegistrationScreen(),
    RecognitionScreen(),
    CameraScreen(),
    UnknownScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border(
              top: BorderSide(
                color: AppTheme.neonCyan.withOpacity(0.2),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonCyan.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _navItems.length,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemBuilder: (context, index) {
              final isSelected = _currentIndex == index;
              final item = _navItems[index];
              return GestureDetector(
                onTap: () => _onNavTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.neonCyan.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.neonCyan
                          : Colors.white12,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.neonCyan.withOpacity(0.4),
                              blurRadius: 10,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected ? AppTheme.neonCyan : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? AppTheme.neonCyan : Colors.white54,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}