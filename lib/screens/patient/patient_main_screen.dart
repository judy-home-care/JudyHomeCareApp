import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'patient_dashboard_screen.dart' show PatientDashboardScreen, PatientDashboardScreenState;
import 'progress_note_screen.dart' show ProgressNoteScreen, ProgressNoteScreenState;
import 'patient_schedules_screen.dart' show PatientSchedulesScreen, PatientSchedulesScreenState;
import 'patient_care_plans_screen.dart' show PatientCarePlansScreen, PatientCarePlansScreenState;
import 'patient_bottom_navigation.dart';
import 'patient_account_screen.dart';

class PatientMainScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;
  final int initialIndex;

  const PatientMainScreen({
    Key? key,
    required this.patientData,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> {
  late int _currentIndex;
  late PageController _pageController;

  // ✅ GlobalKeys to access all cached screen states
  final GlobalKey<PatientDashboardScreenState> _dashboardKey = 
      GlobalKey<PatientDashboardScreenState>();
  final GlobalKey<ProgressNoteScreenState> _progressNotesKey = 
      GlobalKey<ProgressNoteScreenState>();
  final GlobalKey<PatientSchedulesScreenState> _schedulesKey = 
      GlobalKey<PatientSchedulesScreenState>();
  final GlobalKey<PatientCarePlansScreenState> _carePlansKey = 
      GlobalKey<PatientCarePlansScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    // Notify old page it's being hidden
    _notifyPageVisibility(_currentIndex, false);

    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);

    // Notify new page it's now visible
    _notifyPageVisibility(index, true);
  }

  void _onPageChanged(int index) {
    if (_currentIndex == index) return;

    // Notify old page it's being hidden
    _notifyPageVisibility(_currentIndex, false);

    setState(() {
      _currentIndex = index;
    });

    // Notify new page it's now visible
    _notifyPageVisibility(index, true);
  }

  // ✅ Updated to handle all four cached screens (Dashboard, Progress Notes, Schedules, Care Plans)
  void _notifyPageVisibility(int pageIndex, bool isVisible) {
    // Notify dashboard (index 0)
    if (pageIndex == 0 && _dashboardKey.currentState != null) {
      if (isVisible) {
        _dashboardKey.currentState!.onTabVisible();
      } else {
        _dashboardKey.currentState!.onTabHidden();
      }
    }
    
    // Notify progress notes (index 1)
    if (pageIndex == 1 && _progressNotesKey.currentState != null) {
      if (isVisible) {
        _progressNotesKey.currentState!.onTabVisible();
      } else {
        _progressNotesKey.currentState!.onTabHidden();
      }
    }
    
    // Notify schedules (index 2) - NEW
    if (pageIndex == 2 && _schedulesKey.currentState != null) {
      if (isVisible) {
        _schedulesKey.currentState!.onTabVisible();
      } else {
        _schedulesKey.currentState!.onTabHidden();
      }
    }
    
    // Notify care plans (index 3)
    if (pageIndex == 3 && _carePlansKey.currentState != null) {
      if (isVisible) {
        _carePlansKey.currentState!.onTabVisible();
      } else {
        _carePlansKey.currentState!.onTabHidden();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from going back to login
        if (_currentIndex != 0) {
          _onTabTapped(0);
          return false;
        }
        return false; // Disable back button on home tab
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const NeverScrollableScrollPhysics(), // Disable swipe
          children: [
            // Home - Dashboard (index 0)
            PatientDashboardScreen(
              key: _dashboardKey,
              patientData: widget.patientData,
              onTabChange: _onTabTapped,
            ),

            // Progress Notes (index 1) - ✅ With smart caching
            ProgressNoteScreen(
              key: _progressNotesKey,
            ),

            // Schedules (index 2) - ✅ NEW - With smart caching
            PatientSchedulesScreen(
              key: _schedulesKey,
            ),

            // Care Plans (index 3) - ✅ With smart caching
            PatientCarePlansScreen(
              key: _carePlansKey,
            ),

            // Account (index 4)
            PatientAccountScreen(
              patientData: widget.patientData,
            ),
          ],
        ),
        bottomNavigationBar: PatientBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}