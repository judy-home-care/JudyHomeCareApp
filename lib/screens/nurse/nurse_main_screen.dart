import 'package:flutter/material.dart';
import 'nurse_dashboard_screen.dart';
import 'nurse_patients_screen.dart';
import '../schedules/schedule_patients_screen.dart';
import '../care_plans/care_plan_screen.dart';
import 'nurse_account_screen.dart';
import 'nurse_bottom_navigation.dart';

class NurseMainScreen extends StatefulWidget {
  final Map<String, dynamic> nurseData;
  final int initialIndex;
  
  const NurseMainScreen({
    Key? key,
    required this.nurseData,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<NurseMainScreen> createState() => _NurseMainScreenState();
}

class _NurseMainScreenState extends State<NurseMainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  late final List<Widget> _screens;
  
  final GlobalKey _dashboardKey = GlobalKey();
  final GlobalKey _patientsKey = GlobalKey();
  final GlobalKey _scheduleKey = GlobalKey();
  final GlobalKey _carePlansKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    
    _currentIndex = widget.initialIndex;
    
    // Initialize screens with tab change callback
    _screens = [
      NurseDashboardScreen(
        key: _dashboardKey,
        nurseData: widget.nurseData,
        onTabChange: _onTabChanged, // Pass callback
      ),
      NursePatientsScreen(
        key: _patientsKey,
        nurseData: widget.nurseData,
      ),
      SchedulePatientsScreen(
        key: _scheduleKey,
        nurseData: widget.nurseData,
      ),
      CarePlansScreen(
        key: _carePlansKey,
        nurseData: widget.nurseData,
      ),
      NurseAccountScreen(
        nurseData: widget.nurseData,
      ),
    ];
    
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyTabVisibility(_currentIndex, true);
    });
    
    debugPrint('🎯 NurseMainScreen initialized with ${_screens.length} tabs');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - notifying current tab: ${_getTabName(_currentIndex)}');
      _notifyTabVisibility(_currentIndex, true);
    }
  }

  void _onTabChanged(int index) {
    if (_currentIndex == index) {
      debugPrint('📍 Already on ${_getTabName(index)} - triggering refresh');
      _notifyTabVisibility(index, true, forceRefresh: true);
      return;
    }
    
    _notifyTabVisibility(_currentIndex, false);
    
    final oldIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
    });
    
    _notifyTabVisibility(_currentIndex, true);
    
    debugPrint('🔄 Switched from ${_getTabName(oldIndex)} to ${_getTabName(index)}');
  }

  void _notifyTabVisibility(int index, bool isVisible, {bool forceRefresh = false}) {
    try {
      switch (index) {
        case 0: // Dashboard
          final state = _dashboardKey.currentState;
          if (state != null && state is State) {
            if (isVisible) {
              (state as dynamic).onTabVisible();
              if (forceRefresh) {
                (state as dynamic).loadDashboard(forceRefresh: true);
              }
            } else {
              (state as dynamic).onTabHidden();
            }
          }
          break;
          
        case 1: // Patients
          final state = _patientsKey.currentState;
          if (state != null && state is State) {
            if (isVisible) {
              (state as dynamic).onTabVisible();
              if (forceRefresh) {
                (state as dynamic).loadPatients(forceRefresh: true);
              }
            } else {
              (state as dynamic).onTabHidden();
            }
          }
          break;
          
        case 2: // Schedule
          final state = _scheduleKey.currentState;
          if (state != null && state is State) {
            if (isVisible) {
              (state as dynamic).onTabVisible();
              if (forceRefresh) {
                // Trigger refresh if needed
              }
            } else {
              (state as dynamic).onTabHidden();
            }
          }
          break;
          
        case 3: // Care Plans
          final state = _carePlansKey.currentState;
          if (state != null && state is State) {
            if (isVisible) {
              (state as dynamic).onTabVisible();
              if (forceRefresh) {
                // Trigger refresh if needed
              }
            } else {
              (state as dynamic).onTabHidden();
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Error notifying tab $index visibility: $e');
    }
  }

  String _getTabName(int index) {
    switch (index) {
      case 0: return 'Dashboard';
      case 1: return 'Patients';
      case 2: return 'Schedule';
      case 3: return 'Care Plans';
      case 4: return 'Account';
      default: return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          _onTabChanged(0);
          return false;
        }
        return await _showExitConfirmation(context) ?? false;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NurseBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _onTabChanged,
        ),
      ),
    );
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Exit App',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to exit?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF199A8E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}