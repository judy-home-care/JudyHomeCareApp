import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'services/auth/auth_service.dart';
import 'services/preferences_service.dart';
import 'services/notification_service.dart';
import 'models/auth/auth_models.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/nurse/nurse_main_screen.dart';
import 'screens/patient/patient_main_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
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
  final _preferencesService = PreferencesService();

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
      
      // Add small delay to ensure storage is ready
      await Future.delayed(const Duration(milliseconds: 100));
      
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

  void _navigateToOnboarding() {
    print('📍 Navigating to onboarding screen');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
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

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => dashboardScreen),
    );
  }

  void _navigateToLogin() {
    print('📍 Navigating to login screen');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
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
    // Show empty white screen during initialization
    // The native splash will cover this until navigation happens
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.shrink(),
    );
  }
}