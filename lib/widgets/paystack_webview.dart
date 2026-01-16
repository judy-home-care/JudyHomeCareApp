// lib/widgets/paystack_webview.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Reusable WebView widget for Paystack payments
///
/// Used for:
/// - Care service payments
/// - Wallet deposits
///
/// Returns true if payment was successful, false if cancelled/failed
class PaystackPaymentWebView extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final String title;
  final String cancelMessage;

  const PaystackPaymentWebView({
    Key? key,
    required this.authorizationUrl,
    required this.reference,
    this.title = 'Complete Payment',
    this.cancelMessage = 'Are you sure you want to cancel this payment?',
  }) : super(key: key);

  @override
  State<PaystackPaymentWebView> createState() => _PaystackPaymentWebViewState();
}

class _PaystackPaymentWebViewState extends State<PaystackPaymentWebView> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isLoading = true;
  bool _paymentDetectedAsSuccessful = false;
  Timer? _successCheckTimer;

  @override
  void dispose() {
    _successCheckTimer?.cancel();
    super.dispose();
  }

  /// Periodically check page content for success message
  void _startSuccessCheck() {
    _successCheckTimer?.cancel();
    _successCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_paymentDetectedAsSuccessful || _webViewController == null) {
        timer.cancel();
        return;
      }

      try {
        final pageContent = await _webViewController!.evaluateJavascript(
          source: "document.body.innerText"
        );

        if (pageContent != null) {
          final content = pageContent.toString().toLowerCase();
          if (content.contains('payment successful') ||
              content.contains('transaction successful') ||
              content.contains('payment complete')) {
            log('✅ [WebView] Success detected via periodic check!');
            timer.cancel();
            setState(() => _paymentDetectedAsSuccessful = true);
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) Navigator.pop(context, true);
          }
        }
      } catch (e) {
        // Ignore errors during periodic check
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If payment was successful, just close without confirmation
        if (_paymentDetectedAsSuccessful) {
          Navigator.pop(context, true);
          return;
        }

        // Otherwise, confirm before closing
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Payment?'),
            content: Text(widget.cancelMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        );

        if (shouldPop == true && context.mounted) {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
            onPressed: () async {
              final shouldCancel = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Cancel Payment?'),
                  content: Text(widget.cancelMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('No, Continue'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Yes, Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );

              if (shouldCancel == true && mounted) {
                Navigator.pop(context, false);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.authorizationUrl),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useOnLoadResource: true,
                useShouldOverrideUrlLoading: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                log('🌐 [WebView] Created for payment: ${widget.reference}');
                // Start periodic success check
                _startSuccessCheck();
              },
              onLoadStart: (controller, url) {
                log('🔄 [WebView] Load started: $url');
              },
              onLoadStop: (controller, url) async {
                setState(() => _isLoading = false);
                log('✅ [WebView] Load stopped: $url');

                final urlString = url.toString().toLowerCase();

                // Check if payment was successful - Paystack success indicators
                if (urlString.contains('success') ||
                    urlString.contains('successful') ||
                    urlString.contains('payment/callback') ||
                    urlString.contains('trxref=${widget.reference.toLowerCase()}') ||
                    urlString.contains('reference=${widget.reference.toLowerCase()}') ||
                    urlString.contains('status=success')) {
                  log('✅ [WebView] Payment success detected via URL');
                  setState(() => _paymentDetectedAsSuccessful = true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) Navigator.pop(context, true);
                  return;
                } else if (urlString.contains('cancel') ||
                           urlString.contains('cancelled') ||
                           urlString.contains('failed') ||
                           urlString.contains('error') ||
                           urlString.contains('status=failed')) {
                  log('❌ [WebView] Payment failed or cancelled');
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (mounted) Navigator.pop(context, false);
                  return;
                }

                // Check page title
                try {
                  final pageTitle = await controller.getTitle();
                  log('📄 [WebView] Page title: $pageTitle');

                  if (pageTitle != null &&
                      (pageTitle.toLowerCase().contains('success') ||
                       pageTitle.toLowerCase().contains('complete') ||
                       pageTitle.toLowerCase().contains('approved') ||
                       pageTitle.toLowerCase().contains('transaction successful'))) {
                    log('✅ [WebView] Success detected via page title');
                    setState(() => _paymentDetectedAsSuccessful = true);
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) Navigator.pop(context, true);
                    return;
                  }
                } catch (e) {
                  log('⚠️ [WebView] Could not read page title: $e');
                }

                // Check page content for "Payment Successful" text
                try {
                  await Future.delayed(const Duration(milliseconds: 500));
                  final pageContent = await controller.evaluateJavascript(
                    source: "document.body.innerText"
                  );

                  if (pageContent != null) {
                    final contentStr = pageContent.toString();
                    final previewLength = contentStr.length > 200 ? 200 : contentStr.length;
                    log('📝 [WebView] Page content check: ${contentStr.substring(0, previewLength)}...');

                    final content = contentStr.toLowerCase();
                    if (content.contains('payment successful') ||
                        content.contains('transaction successful') ||
                        content.contains('payment complete') ||
                        content.contains('transaction complete')) {
                      log('✅ [WebView] Success detected via page content!');
                      setState(() => _paymentDetectedAsSuccessful = true);
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) Navigator.pop(context, true);
                      return;
                    }
                  }
                } catch (e) {
                  log('⚠️ [WebView] Could not read page content: $e');
                }
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                  _isLoading = progress < 100;
                });
              },
              onLoadError: (controller, url, code, message) {
                log('💥 [WebView] Load error: $message (Code: $code)');
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url.toString();
                log('🔗 [WebView] URL loading: $url');

                // Allow navigation
                return NavigationActionPolicy.ALLOW;
              },
            ),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading secure payment page...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_progress < 1.0 && !_isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF199A8E)),
                ),
              ),
            // Show "Continue" button when payment is successful
            if (_paymentDetectedAsSuccessful)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, true),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF199A8E), Color(0xFF147A70)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Payment Successful - Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
    );
  }
}
