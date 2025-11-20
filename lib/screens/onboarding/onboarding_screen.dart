import 'package:flutter/material.dart';
import 'login_signup_screen.dart';
import '../../models/onboarding/onboarding_data.dart';
import '../../services/preferences_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late final List<OnboardingData> _onboardingData;
  int _currentPage = 0;
  bool _isNavigating = false; // Prevent double navigation
  
  // Cache these values once instead of recalculating
  late final double _screenHeight;
  late final double _imageSize;
  late final double _containerSize;
  late final double _titleFontSize;
  late final double _descriptionFontSize;
  late final double _topSpacing;
  late final double _titleSpacing;
  late final double _descriptionSpacing;
  late final double _bottomSpacing;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _onboardingData = OnboardingContent.getOnboardingData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache all size calculations once
    _screenHeight = MediaQuery.of(context).size.height;
    _imageSize = _screenHeight > 700 ? 260.0 : 220.0;
    _containerSize = _imageSize + 40;
    _titleFontSize = _screenHeight > 700 ? 28.0 : 24.0;
    _descriptionFontSize = _screenHeight > 700 ? 15.0 : 14.0;
    _topSpacing = _screenHeight > 700 ? 20.0 : 10.0;
    _titleSpacing = _screenHeight > 700 ? 40.0 : 30.0;
    _descriptionSpacing = _screenHeight > 700 ? 16.0 : 12.0;
    _bottomSpacing = _screenHeight > 700 ? 30.0 : 20.0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // CRITICAL: Save onboarding completion before navigating
  Future<void> _completeOnboarding() async {
    if (_isNavigating) return; // Prevent double navigation
    
    setState(() {
      _isNavigating = true;
    });

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🎯 COMPLETING ONBOARDING');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final prefsService = PreferencesService();
      
      // Save onboarding completion flag
      await prefsService.setOnboardingCompleted();
      
      // Verify it was saved
      final hasSeenOnboarding = await prefsService.hasSeenOnboarding();
      print('✅ Onboarding completion verified: $hasSeenOnboarding');
      
      // Debug: Print all preferences
      await prefsService.debugPrintAll();
      
      // Small delay to ensure save is complete on iOS
      await Future.delayed(const Duration(milliseconds: 150));
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      // Navigate to login/signup screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => LoginSignupScreen(),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error completing onboarding: $e');
      print('Stack trace: $stackTrace');
      
      setState(() {
        _isNavigating = false;
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete onboarding. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _nextPage() {
    if (_isNavigating) return; // Prevent navigation if already processing
    
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      // Last page - complete onboarding
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    if (_isNavigating) return; // Prevent navigation if already processing
    
    // Complete onboarding when skipping
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Static top bar
            _TopBar(onSkip: _skipOnboarding),

            // Optimized PageView with cacheExtent
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  if (_currentPage != index) {
                    setState(() {
                      _currentPage = index;
                    });
                  }
                },
                // Reduce cache extent to minimize off-screen rendering
                physics: const ClampingScrollPhysics(),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  // Pass cached dimensions to avoid recalculation
                  return _SimplifiedOnboardingPage(
                    data: _onboardingData[index],
                    pageIndex: index,
                    imageSize: _imageSize,
                    containerSize: _containerSize,
                    titleFontSize: _titleFontSize,
                    descriptionFontSize: _descriptionFontSize,
                    topSpacing: _topSpacing,
                    titleSpacing: _titleSpacing,
                    descriptionSpacing: _descriptionSpacing,
                    bottomSpacing: _bottomSpacing,
                  );
                },
              ),
            ),

            // Simplified bottom section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Simple dots without individual animations
                  SizedBox(
                    height: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingData.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 32 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? const Color(0xFF199A8E)
                                : const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Simple button without unnecessary rebuilds
                  GestureDetector(
                    onTap: _isNavigating ? null : _nextPage, // Disable if navigating
                    child: Opacity(
                      opacity: _isNavigating ? 0.6 : 1.0,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF199A8E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: _isNavigating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _currentPage == _onboardingData.length - 1
                                          ? 'Get Started'
                                          : 'Continue',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Const top bar widget
class _TopBar extends StatelessWidget {
  final VoidCallback onSkip;

  const _TopBar({required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite,
                    color: Color(0xFF199A8E),
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Judy Home HealthCare',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onSkip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simplified page with pre-calculated dimensions
class _SimplifiedOnboardingPage extends StatelessWidget {
  final OnboardingData data;
  final int pageIndex;
  final double imageSize;
  final double containerSize;
  final double titleFontSize;
  final double descriptionFontSize;
  final double topSpacing;
  final double titleSpacing;
  final double descriptionSpacing;
  final double bottomSpacing;

  const _SimplifiedOnboardingPage({
    required this.data,
    required this.pageIndex,
    required this.imageSize,
    required this.containerSize,
    required this.titleFontSize,
    required this.descriptionFontSize,
    required this.topSpacing,
    required this.titleSpacing,
    required this.descriptionSpacing,
    required this.bottomSpacing,
  });

  // Pre-defined visuals to avoid recreation
  static const List<_PageVisuals> _visualsList = [
    _PageVisuals(
      icon: Icons.medical_services_rounded,
      backgroundColor: Color(0xFFE8F5F4),
      iconColor: Color(0xFF199A8E),
      accentColor: Color(0xFF199A8E),
    ),
    _PageVisuals(
      icon: Icons.health_and_safety_rounded,
      backgroundColor: Color(0xFFE3F2FD),
      iconColor: Color(0xFF2196F3),
      accentColor: Color(0xFF2196F3),
    ),
    _PageVisuals(
      icon: Icons.local_hospital_rounded,
      backgroundColor: Color(0xFFF3E5F5),
      iconColor: Color(0xFF9C27B0),
      accentColor: Color(0xFF9C27B0),
    ),
    _PageVisuals(
      icon: Icons.favorite_rounded,
      backgroundColor: Color(0xFFFFEBEE),
      iconColor: Color(0xFFE91E63),
      accentColor: Color(0xFFE91E63),
    ),
  ];

@override
Widget build(BuildContext context) {
  final visuals = pageIndex < _visualsList.length 
      ? _visualsList[pageIndex] 
      : _visualsList.last;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24.0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // Prevents scrolling unless needed
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1), // Flexible top spacing
                  
                  // Simplified icon container
                  RepaintBoundary(
                    child: Container(
                      width: containerSize,
                      height: containerSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFE5E5E5),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Small accent circle
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: visuals.accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          // Main icon
                          Center(
                            child: Container(
                              width: imageSize,
                              height: imageSize,
                              decoration: BoxDecoration(
                                color: visuals.backgroundColor,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Icon(
                                visuals.icon,
                                size: 120,
                                color: visuals.iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 1), // Flexible spacing
                  
                  // Text content
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                      height: 1.2,
                      letterSpacing: -1,
                    ),
                  ),
                  
                  SizedBox(height: descriptionSpacing * 0.8), // Slightly reduced
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      data.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: descriptionFontSize,
                        color: const Color(0xFF666666),
                        height: 1.5,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const Spacer(flex: 1), // Flexible spacing
                  
                  // Static feature pills
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FeaturePill(icon: Icons.verified_outlined, label: 'Verified'),
                      SizedBox(width: 8),
                      _FeaturePill(icon: Icons.security_outlined, label: 'Secure'),
                      SizedBox(width: 8),
                      _FeaturePill(icon: Icons.support_agent_outlined, label: '24/7'),
                    ],
                  ),
                  
                  const Spacer(flex: 1), // Flexible bottom spacing
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
}

// Simplified page visuals
class _PageVisuals {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color accentColor;

  const _PageVisuals({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.accentColor,
  });
}

// Simplified feature pill
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB3E0DC),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFF199A8E),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF199A8E),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}