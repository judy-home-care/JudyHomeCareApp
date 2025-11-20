import 'package:flutter/material.dart';
import 'nurse_dashboard_screen.dart';
import '../schedules/schedule_patients_screen.dart';
import 'nurse_patients_screen.dart';
import '../care_plans/care_plan_screen.dart';
import 'nurse_account_screen.dart';

class NurseNavigationHelper {
  static void navigateToIndex(
    BuildContext context,
    int index, {
    Map<String, dynamic>? nurseData,
  }) {
    switch (index) {
      case 0:
        // Home - Navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => NurseDashboardScreen(
              nurseData: nurseData ?? {},
            ),
          ),
        );
        break;
      case 1:
        // Patients - Navigate to patients screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => NursePatientsScreen(
              nurseData: nurseData ?? {},
            ),
          ),
        );
        break;
      case 2:
        // Schedule - Navigate to schedule screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SchedulePatientsScreen(
              nurseData: nurseData ?? {},
            ),
          ),
        );
        break;
      case 3:
        // Care Plans - Navigate to care plan screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CarePlansScreen(
              nurseData: nurseData ?? {},
            ),
          ),
        );
        break;
      case 4:
        // Account - Navigate to account screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => NurseAccountScreen(
              nurseData: nurseData ?? {},
            ),
          ),
        );
        break;
    }
  }
}