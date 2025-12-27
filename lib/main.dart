import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'utils/secure_storage.dart';
import 'services/auth/auth_service.dart';
import 'services/contact_person/contact_person_auth_service.dart';
import 'services/preferences_service.dart';
import 'services/notification_service.dart';
import 'services/app_version_service.dart';
import 'models/auth/auth_models.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/nurse/nurse_main_screen.dart';
import 'screens/patient/patient_main_screen.dart';
import 'screens/contact_person/patient_selector_screen.dart';
import 'screens/contact_person/contact_person_main_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized and preserve splash
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // 🔒 LOCK TO PORTRAIT MODE ONLY - Prevent screen rotation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI style (edge-to-edge handled natively in MainActivity.kt for Android 15+)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 🔥 Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
  
  // 📱 CRITICAL: Initialize PreferencesService BEFORE running app
  try {
    await PreferencesService().init();
    print('✅ PreferencesService initialized successfully');
  } catch (e) {
    print('❌ PreferencesService initialization failed: $e');
  }
  
  // 🔔 Initialize Notification Service
  try {
    await NotificationService().initialize();
    print('✅ Notification service initialized successfully');
  } catch (e) {
    print('❌ Notification service initialization failed: $e');
  }

  // 📱 Initialize App Version Service (for force update feature)
  try {
    await AppVersionService().initialize();
    print('✅ App Version service initialized successfully');
  } catch (e) {
    print('❌ App Version service initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Judy Home Healthcare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryGreen,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> with WidgetsBindingObserver {
  final _authService = AuthService();
  final _contactPersonAuthService = ContactPersonAuthService();
  final _preferencesService = PreferencesService();
  final _secureStorage = SecureStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed from background');
      // Optional: Refresh data when app comes back
      _authService.validateInBackground();
    } else if (state == AppLifecycleState.paused) {
      print('📱 App moved to background');
    }
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🚀 STARTING APP INITIALIZATION');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // Debug: Print all stored preferences
      await _preferencesService.debugPrintAll();

      // Check if user has seen onboarding
      final hasSeenOnboarding = await _preferencesService.hasSeenOnboarding();
      print('📱 Has seen onboarding: $hasSeenOnboarding');

      if (!hasSeenOnboarding) {
        print('➡️ Navigating to onboarding');
        if (mounted) {
          _navigateToOnboarding();
        }
        return;
      }

      // Check login status - LOCAL CHECK ONLY
      final isLoggedIn = await _authService.isLoggedIn();
      print('🔐 Is logged in: $isLoggedIn');

      if (isLoggedIn) {
        print('➡️ User is logged in, navigating to dashboard');
        // User has valid local token, navigate to dashboard immediately
        if (mounted) {
          await _navigateToDashboardDirectly();
        }
        return;
      }

      // Not logged in - go to login screen
      print('➡️ User not logged in, navigating to login');
      if (mounted) {
        _navigateToLogin();
      }
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ APP INITIALIZATION COMPLETE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stackTrace) {
      print('❌ App initialization error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  // Navigate directly to dashboard - NO BLOCKING API CALLS
  Future<void> _navigateToDashboardDirectly() async {
    try {
      // First check if this is a contact person session
      final userType = await _secureStorage.getUserType();
      print('🔄 User type: $userType');

      if (userType == 'contact_person') {
        // Handle contact person session restoration
        await _navigateToContactPersonDashboard();
        return;
      }

      // Regular user flow
      print('🔄 Getting current user...');
      final user = await _authService.getCurrentUser();

      if (user != null) {
        print('✅ User found: ${user.fullName} (${user.role})');

        if (mounted) {
          // Navigate to dashboard immediately
          _navigateToDashboard(user);

          // Validate token in background (completely non-blocking)
          // This NEVER forces a logout
          _authService.validateInBackground();
        }

        return;
      }

      print('❌ No user data found');
      // No user data found - go to login
      if (mounted) {
        _navigateToLogin();
      }
    } catch (e) {
      print('❌ Dashboard navigation error: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  // Navigate contact person to their dashboard
  Future<void> _navigateToContactPersonDashboard() async {
    try {
      print('🔄 Restoring contact person session...');

      final contactPerson = await _contactPersonAuthService.getStoredContactPerson();

      if (contactPerson == null) {
        print('❌ No contact person data found');
        if (mounted) {
          _navigateToLogin();
        }
        return;
      }

      print('✅ Contact person found: ${contactPerson.name}');

      // Check if they had a patient selected
      final selectedPatientId = await _contactPersonAuthService.getSelectedPatientId();

      if (selectedPatientId != null) {
        // Find the selected patient
        final selectedPatient = contactPerson.linkedPatients.firstWhere(
          (p) => p.id == selectedPatientId,
          orElse: () => contactPerson.linkedPatients.first,
        );

        print('✅ Restoring with selected patient: ${selectedPatient.name}');

        FlutterNativeSplash.remove();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ContactPersonMainScreen(
                contactPersonData: {
                  'id': contactPerson.id.toString(),
                  'name': contactPerson.name,
                  'phone': contactPerson.phone,
                  'email': contactPerson.email,
                  'avatar': contactPerson.avatar,
                  'role': 'contact_person',
                  'selectedPatientId': selectedPatient.id.toString(),
                  'selectedPatientName': selectedPatient.name,
                  'selectedPatientAge': selectedPatient.age,
                  'selectedPatientPhone': selectedPatient.phone,
                  'selectedPatientAvatar': selectedPatient.avatar,
                  'selectedPatientRelationship': selectedPatient.relationship,
                  'selectedPatientIsPrimary': selectedPatient.isPrimary,
                  'linkedPatients': contactPerson.linkedPatients
                      .map((p) => p.toJson())
                      .toList(),
                },
              ),
            ),
          );
        }
      } else {
        // No patient selected, go to patient selector
        print('➡️ Navigating to patient selector');
        FlutterNativeSplash.remove();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PatientSelectorScreen(
                contactPerson: contactPerson,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Contact person dashboard navigation error: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToOnboarding() {
    print('📍 Navigating to onboarding screen');
    FlutterNativeSplash.remove();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  void _navigateToDashboard(User user) {
    Widget dashboardScreen;

    switch (user.role) {
      case 'nurse':
        print('📍 Navigating to nurse main screen');
        dashboardScreen = NurseMainScreen(
          nurseData: {
            'name': user.fullName,
            'firstName': user.firstName,
            'lastName': user.lastName,
            'phone': user.phone,
            'gender': user.gender,
            'dob': user.dateOfBirth,
            'avatar': user.avatarUrl,
            'ghanaCardNumber': user.ghanaCardNumber,
            'licenseNumber': user.licenseNumber,
            'specialization': user.specialization,
            'yearsOfExperience': user.yearsOfExperience,
            'id': user.id.toString(),
            'role': user.role,
            'email': user.email,
            'avatar_url': user.avatarUrl,
          },
          initialIndex: 0,
        );
        break;

      case 'patient':
        print('📍 Navigating to patient main screen');
        dashboardScreen = PatientMainScreen(
          patientData: {
            'name': user.fullName,
            'firstName': user.firstName,
            'lastName': user.lastName,
            'phone': user.phone,
            'gender': user.gender,
            'dob': user.dateOfBirth,
            'avatar': user.avatarUrl,
            'id': user.id.toString(),
            'role': user.role,
            'email': user.email,
          },
          initialIndex: 0,
        );
        break;

      case 'doctor':
        print('📍 Navigating to doctor dashboard (coming soon)');
        dashboardScreen = _buildComingSoonScreen('Doctor Dashboard', user);
        break;

      case 'admin':
      case 'superadmin':
        print('📍 Navigating to admin dashboard (coming soon)');
        dashboardScreen = _buildComingSoonScreen('Admin Dashboard', user);
        break;

      default:
        print('❌ Unknown role: ${user.role}');
        _navigateToLogin();
        return;
    }

    FlutterNativeSplash.remove();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => dashboardScreen),
      );
    }
  }

  void _navigateToLogin() {
    print('📍 Navigating to login screen');
    FlutterNativeSplash.remove();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  Widget _buildComingSoonScreen(String title, User user) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_rounded,
                size: 80,
                color: AppColors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                '$title Coming Soon',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Welcome, ${user.firstName}!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  await _authService.logout();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep showing splash screen while initializing
    // Don't render anything that would trigger auto-dismiss
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox.shrink(),
      ),
    );
  }
}