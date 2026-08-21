import 'package:flutter/material.dart';
import 'therapist_dashboard_screen.dart';
import 'therapist_account_screen.dart';
import 'therapist_bottom_navigation.dart';
import '../nurse/nurse_patients_screen.dart';

/// Main shell for physiotherapists and speech therapists.
///
/// Tabs:
///   0 — Dashboard (assigned patients, sessions, recent notes)
///   1 — Patients (reuses the nurse patients screen in therapist mode:
///       Details · Vitals · Daily Notes (free text) · Care Plan · History)
///   2 — Account
///
/// `therapistData` is the same loose map the nurse shell uses, including
/// `role` ('physiotherapist' | 'speech_therapist').
class TherapistMainScreen extends StatefulWidget {
  final Map<String, dynamic> therapistData;
  final int initialIndex;

  const TherapistMainScreen({
    Key? key,
    required this.therapistData,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<TherapistMainScreen> createState() => _TherapistMainScreenState();
}

class _TherapistMainScreenState extends State<TherapistMainScreen>
    with WidgetsBindingObserver {
  late int _currentIndex;
  late final List<Widget> _screens;

  final GlobalKey _dashboardKey = GlobalKey();
  final GlobalKey _patientsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _screens = [
      TherapistDashboardScreen(
        key: _dashboardKey,
        therapistData: widget.therapistData,
        onTabChange: _onTabChanged,
      ),
      NursePatientsScreen(
        key: _patientsKey,
        nurseData: widget.therapistData, // role inside drives therapist mode
      ),
      TherapistAccountScreen(
        therapistData: widget.therapistData,
      ),
    ];

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyTabVisibility(_currentIndex, true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifyTabVisibility(_currentIndex, true);
    }
  }

  void _onTabChanged(int index) {
    if (_currentIndex == index) {
      _notifyTabVisibility(index, true, forceRefresh: true);
      return;
    }

    _notifyTabVisibility(_currentIndex, false);
    setState(() => _currentIndex = index);
    _notifyTabVisibility(_currentIndex, true);
  }

  void _notifyTabVisibility(int index, bool isVisible, {bool forceRefresh = false}) {
    try {
      switch (index) {
        case 0:
          final state = _dashboardKey.currentState;
          if (state != null) {
            if (isVisible) {
              (state as dynamic).onTabVisible();
              if (forceRefresh) (state as dynamic).loadDashboard(forceRefresh: true);
            } else {
              (state as dynamic).onTabHidden();
            }
          }
          break;
        case 1:
          final state = _patientsKey.currentState;
          if (state != null) {
            if (isVisible) {
              (state as dynamic).onTabVisible();
              if (forceRefresh) (state as dynamic).loadPatients(forceRefresh: true);
            } else {
              (state as dynamic).onTabHidden();
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('⚠️ Error notifying therapist tab $index visibility: $e');
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
        bottomNavigationBar: TherapistBottomNavigation(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Exit App',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF199A8E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
