import 'package:flutter/material.dart';
import 'package:backpackhelp/HomeScreen.dart';
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
  static final List<Widget> _pages = [
    Homescreen(),
    ScanScreen(),
    Schedule()
  ];
  void _onitemtap(int index){
    setState(() {
      _selectedindex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedindex,
          selectedItemColor: primary_color,
          showSelectedLabels: true,
          onTap: _onitemtap,
          items: [
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.home,

                ),
                label: "Home"


            ),
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.search,

                ),
                label: "Scan"
            ),
            BottomNavigationBarItem(
                icon: Icon(
                  Icons.calendar_month,

                ),
                label: "Schedule"
            )


          ]
      ),
      body: _pages[_selectedindex],
    );
  }
}
