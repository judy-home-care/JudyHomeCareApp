class OnboardingData {
  final String title;
  final String image;
  final String description;

  OnboardingData({
    required this.title,
    required this.image,
    required this.description,
  });
}

// Static data for onboarding screens
class OnboardingContent {
  static List<OnboardingData> getOnboardingData() {
    return [
      OnboardingData(
        title: 'Compassionate care right in your home',
        image: 'assets/images/doctor11.webp',
        description: 'Receive professional and personalized healthcare without leaving your home',
      ),
      OnboardingData(
        title: 'Trusted nurses and caregivers available',
        image: 'assets/images/doctor6.webp',
        description: 'Get access to skilled caregivers who treat you with dignity and respect',
      ),
      OnboardingData(
        title: 'Convenient and reliable healthcare support',
        image: 'assets/images/doctor10.webp',
        description: 'Enjoy reliable care that brings comfort, safety, and peace of mind daily',
      ),
    ];
  }
}
