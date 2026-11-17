import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final rawMobile = _mobileController.text.trim();
    final password = _passwordController.text.trim();

    final mobile = AppConstants.sanitizeMobile(rawMobile);

    if (mobile.isEmpty || password.isEmpty) {
      setState(() => _localError = 'Please enter mobile number and password');
      return;
    }

    if (mobile.length < 10) {
      setState(() => _localError = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _localError = null);
    final success = await ref.read(authProvider.notifier).login(mobile, password);
    if (!success && mounted) {
      final authError = ref.read(authProvider).errorMessage;
      String friendlyMessage = 'Login failed. Please verify credentials.';
      if (authError != null) {
        if (authError.contains('Invalid login credentials') || authError.contains('invalid_credentials')) {
          friendlyMessage = 'Invalid mobile number or password.';
        } else if (authError.contains('disabled')) {
          friendlyMessage = authError;
        } else if (authError.contains('network') || authError.contains('SocketException')) {
          friendlyMessage = 'Network connection issue. Please check your internet.';
        } else {
          friendlyMessage = authError.replaceAll(RegExp(r'AuthException\(message: |statusCode: \d+\)'), '').trim();
        }
      }
      setState(() => _localError = friendlyMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: GradientBackdrop(
          child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.pureWhite,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.darkBlue.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: AppConstants.borderSubtle),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Brand Headings
                  const Text(
                    'OpenSoftwares CRM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enterprise Internal Operations Suite',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppConstants.statusSuccess.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppConstants.statusSuccess.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: AppConstants.statusSuccess),
                          SizedBox(width: 5),
                          Text(
                            'Live Cloud Connected • Instant Updates Active',
                            style: TextStyle(
                              color: AppConstants.statusSuccess,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Error Banner
                  if (_localError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.statusDanger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppConstants.statusDanger.withOpacity(0.3)),
                      ),
                      child: Text(
                        _localError!,
                        style: const TextStyle(
                          color: AppConstants.statusDanger,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Mobile Input
                  const Text(
                    'Mobile Number',
                    style: TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'Enter 10-digit mobile number',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppConstants.darkBlue, size: 20),
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(
                        color: AppConstants.textBlack,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password Input
                  const Text(
                    'Password',
                    style: TextStyle(
                      color: AppConstants.textBlack,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppConstants.darkBlue, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppConstants.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login Button
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: 48),

                  // Developer Attribution Footer
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'Developed by',
                          style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                        ),
                        SizedBox(height: 2),
                        Text(
                          AppConstants.developerAttribution,
                          style: TextStyle(
                            color: AppConstants.darkBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
