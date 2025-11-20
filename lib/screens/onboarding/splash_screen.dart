import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/app_colors.dart';
import 'services/auth/auth_service.dart';
import 'services/preferences_service.dart';
import 'models/auth/auth_models.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/nurse/nurse_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
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

class _AppInitializerState extends State<AppInitializer> {
  final _authService = AuthService();
  final _preferencesService = PreferencesService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // No delay needed - native splash already showed
    
    if (!mounted) return;

    try {
      // Quick check only - defer heavy operations
      final hasSeenOnboarding = await _preferencesService.hasSeenOnboarding();

      if (!hasSeenOnboarding) {
        _navigateToOnboarding();
        return;
      }

      // Check login status (lightweight)
      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        // Defer validation until after navigation to reduce loading time
        _navigateToDashboardWithValidation();
        return;
      }

      if (mounted) {
        _navigateToLogin();
      }
    } catch (e) {
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  Future<void> _navigateToDashboardWithValidation() async {
    try {
      final isValid = await _authService.validateToken();
      
      if (isValid) {
        final user = await _authService.getCurrentUser();
        
        if (user != null && mounted) {
          _navigateToDashboard(user);
          return;
        }
      }
      
      if (mounted) {
        _navigateToLogin();
      }
    } catch (e) {
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  void _navigateToDashboard(User user) {
    Widget dashboardScreen;

    switch (user.role) {
      case 'nurse':
        dashboardScreen = NurseDashboardScreen(
          nurseData: {
            'name': user.fullName,
            'id': user.id.toString(),
            'role': user.role,
            'email': user.email,
            'avatar_url': user.avatarUrl,
          },
        );
        break;
      case 'doctor':
        dashboardScreen = _buildComingSoonScreen('Doctor Dashboard', user);
        break;
      case 'admin':
      case 'superadmin':
        dashboardScreen = _buildComingSoonScreen('Admin Dashboard', user);
        break;
      case 'patient':
        dashboardScreen = _buildComingSoonScreen('Patient Dashboard', user);
        break;
      default:
        _navigateToLogin();
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => dashboardScreen),
    );
  }

  void _navigateToLogin() {
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
    // Minimal white screen during initialization
    // Native splash will show before this
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.shrink(), // Empty - navigation happens in initState
    );
  }
}