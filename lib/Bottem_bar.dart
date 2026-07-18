import 'package:flutter/material.dart';
import 'package:backpackhelp/checklist.dart';
import 'package:backpackhelp/HomeScreen.dart';
import 'package:backpackhelp/reminders.dart';
import 'package:backpackhelp/Scan.dart';
import 'package:backpackhelp/Schedule.dart';

import 'constants.dart';

class bottom_bar extends StatefulWidget {
  const bottom_bar({super.key});

  @override
  State<bottom_bar> createState() => _bottom_barState();
}

class _bottom_barState extends State<bottom_bar> {
  int _selectedindex = 0;
  static const List<Widget> _pages = [
    Homescreen(),
    ChecklistScreen(),
    RemindersScreen(),
    ScanScreen(),
    Schedule(),
  ];
  void _onitemtap(int index) {
    setState(() {
      _selectedindex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: NavigationBar(
              selectedIndex: _selectedindex,
              onDestinationSelected: _onitemtap,
              height: 64,
              backgroundColor: AppColors.surface,
              indicatorColor: primary_color.withValues(alpha: 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: "Home",
                ),
                NavigationDestination(
                  icon: Icon(Icons.playlist_add_check_outlined),
                  selectedIcon: Icon(Icons.playlist_add_check),
                  label: "Checklist",
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none),
                  selectedIcon: Icon(Icons.notifications_active),
                  label: "Reminders",
                ),
                NavigationDestination(
                  icon: Icon(Icons.sensors_outlined),
                  selectedIcon: Icon(Icons.sensors),
                  label: "Scan",
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: "Schedule",
                ),
              ],
            ),
          ),
        ),
      ),
      body: _pages[_selectedindex],
    );
  }
}
