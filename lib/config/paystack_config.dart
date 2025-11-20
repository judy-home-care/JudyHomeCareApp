// lib/config/paystack_config.dart

/// Paystack Configuration
/// 
/// IMPORTANT: Configure these settings in your Paystack Dashboard:
/// 1. Go to Settings → API Keys & Webhooks
/// 2. Set Callback URL to match PAYSTACK_CALLBACK_URL below
/// 3. Add Webhook URL for payment notifications
class PaystackConfig {
  /// Paystack Callback URL
  /// 
  /// This MUST match the callback URL configured in your Paystack dashboard.
  /// Steps to configure:
  /// 1. Login to Paystack Dashboard (https://dashboard.paystack.com)
  /// 2. Go to Settings → API Keys & Webhooks
  /// 3. Under "Callback URL", enter: https://judyhomecare.com/payment/callback
  /// 4. Save changes
  /// 
  /// For development/testing:
  /// - Use ngrok: https://[your-ngrok-url]/api/webhooks/paystack
  /// - Or use your staging server URL
  static const String PAYSTACK_CALLBACK_URL = 'https://judyhomecare.com/payment/callback';
  
  /// Alternative callback URLs for different environments
  static const String PAYSTACK_CALLBACK_URL_DEV = 'https://dev.judyhomecare.com/payment/callback';
  static const String PAYSTACK_CALLBACK_URL_STAGING = 'https://staging.judyhomecare.com/payment/callback';
  
  /// Get callback URL based on environment
  static String getCallbackUrl() {
    // You can add environment detection logic here
    // For now, return production URL
    return PAYSTACK_CALLBACK_URL;
  }
  
  /// Webhook URL (configured in Paystack dashboard)
  /// This is where Paystack sends payment notifications
  static const String WEBHOOK_URL = 'https://judyhomecare.com/api/webhooks/paystack';
  
  /// Payment channels to enable
  /// These must also be activated in your Paystack account
  static const List<String> PAYMENT_CHANNELS = [
    'mobile_money',
    'card',
    'bank',
    'bank_transfer',
  ];
  
  /// Supported currencies
  static const String DEFAULT_CURRENCY = 'GHS';
  
  /// Payment timeout (in seconds)
  static const int PAYMENT_TIMEOUT = 900; // 15 minutes
}

/// Configuration Instructions:
/// 
/// 1. PAYSTACK DASHBOARD SETUP:
///    - Login to https://dashboard.paystack.com
///    - Go to Settings → API Keys & Webhooks
///    - Set Callback URL to your production URL
///    - Add Webhook URL for payment events
///    - Enable required payment channels (Mobile Money, Card, Bank)
/// 
/// 2. MOBILE MONEY ACTIVATION:
///    Mobile Money requires additional activation:
///    - Complete business verification (KYC)
///    - Verify Ghana-based business registration
///    - Link verified bank account
///    - Contact Paystack support to activate Mobile Money
///    - Wait for activation confirmation (usually 1-3 business days)
/// 
/// 3. TESTING:
///    - Use test API keys for development
///    - Test cards: 4084084084084081 (CVV: 408, PIN: 0000, OTP: 123456)
///    - Test mobile money: 0240000000 (MTN), 0500000000 (Vodafone)
/// 
/// 4. PRODUCTION:
///    - Switch to live API keys
///    - Update callback URLs to production URLs
///    - Ensure all payment channels are activated
///    - Monitor webhook events in Paystack dashboard