/// Countries whose phone numbers are accepted for login / registration.
/// Shared by the login, sign-up, registration and forgot-password screens.
///
/// The backend passes any international number through as +<digits>, so a
/// country only needs to be listed here (and on the portal's country-code
/// dropdowns) to be supported.
const List<Map<String, String>> kSupportedCountries = [
  {'name': 'Ghana', 'code': '+233', 'flag': '🇬🇭'},
  {'name': 'Nigeria', 'code': '+234', 'flag': '🇳🇬'},
  {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
  {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
  {'name': 'France', 'code': '+33', 'flag': '🇫🇷'},
  {'name': 'Germany', 'code': '+49', 'flag': '🇩🇪'},
  {'name': 'Netherlands', 'code': '+31', 'flag': '🇳🇱'},
  {'name': 'Belgium', 'code': '+32', 'flag': '🇧🇪'},
  {'name': 'Italy', 'code': '+39', 'flag': '🇮🇹'},
  {'name': 'Spain', 'code': '+34', 'flag': '🇪🇸'},
  {'name': 'Portugal', 'code': '+351', 'flag': '🇵🇹'},
  {'name': 'Switzerland', 'code': '+41', 'flag': '🇨🇭'},
  {'name': 'Ireland', 'code': '+353', 'flag': '🇮🇪'},
  {'name': 'South Africa', 'code': '+27', 'flag': '🇿🇦'},
];
