import 'package:flutter/material.dart';
import '../../models/contact_person/contact_person_models.dart';
import 'contact_person_dashboard_screen.dart';
import 'contact_person_progress_notes_screen.dart';
import 'contact_person_schedules_screen.dart';
import 'contact_person_care_plans_screen.dart';
import 'contact_person_account_screen.dart';
import 'contact_person_bottom_navigation.dart';

class ContactPersonMainScreen extends StatefulWidget {
  final ContactPersonUser contactPerson;
  final LinkedPatient selectedPatient;
  final int initialIndex;

  const ContactPersonMainScreen({
    Key? key,
    required this.contactPerson,
    required this.selectedPatient,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<ContactPersonMainScreen> createState() => _ContactPersonMainScreenState();
}

class _ContactPersonMainScreenState extends State<ContactPersonMainScreen> {
  late int _currentIndex;
  late PageController _pageController;

  // GlobalKeys to access all cached screen states
  final GlobalKey<ContactPersonDashboardScreenState> _dashboardKey =
      GlobalKey<ContactPersonDashboardScreenState>();
  final GlobalKey<ContactPersonProgressNotesScreenState> _progressNotesKey =
      GlobalKey<ContactPersonProgressNotesScreenState>();
  final GlobalKey<ContactPersonSchedulesScreenState> _schedulesKey =
      GlobalKey<ContactPersonSchedulesScreenState>();
  final GlobalKey<ContactPersonCarePlansScreenState> _carePlansKey =
      GlobalKey<ContactPersonCarePlansScreenState>();

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

    // Notify schedules (index 2)
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
            ContactPersonDashboardScreen(
              key: _dashboardKey,
              contactPerson: widget.contactPerson,
              selectedPatient: widget.selectedPatient,
              onTabChange: _onTabTapped,
            ),

            // Progress Notes (index 1)
            ContactPersonProgressNotesScreen(
              key: _progressNotesKey,
              patientId: widget.selectedPatient.id,
            ),

            // Schedules (index 2)
            ContactPersonSchedulesScreen(
              key: _schedulesKey,
              patientId: widget.selectedPatient.id,
            ),

            // Care Plans (index 3)
            ContactPersonCarePlansScreen(
              key: _carePlansKey,
              patientId: widget.selectedPatient.id,
            ),

            // Account (index 4)
            ContactPersonAccountScreen(
              contactPerson: widget.contactPerson,
              selectedPatient: widget.selectedPatient,
            ),
          ],
        ),
        bottomNavigationBar: ContactPersonBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}
