import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/firebase/auth_service.dart';
import '../../state/auth_state_notifier.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // The confirm field is checked here. The Firebase call below is the
    // same as before and still receives only one password.
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: _nameController.text.trim(),
          );

      // Navigation happens automatically via the auth-gated app root.
    } on AuthFailure catch (e) {
      // The screen may have been closed while the request was running.
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _goToLogin() {
    if (_isSubmitting) return;

    // This screen is normally opened from the sign-in screen, so going
    // back returns to it instead of stacking a second sign-in screen.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const SignInScreen(),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 16,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE0E0E0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE0E0E0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF2F80ED),
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFFE0E0E0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ----------------------------------------------------------
                  // LOGO
                  // Decorative, so screen readers skip it.
                  // ----------------------------------------------------------
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const SizedBox(
                        width: 100,
                        height: 100,
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // ----------------------------------------------------------
                  // TITLE
                  // ----------------------------------------------------------
                  Semantics(
                    header: true,
                    child: const Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'إنشاء حساب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ----------------------------------------------------------
                  // FULL NAME
                  // ----------------------------------------------------------
                  Semantics(
                    textField: true,
                    label: 'Full name',
                    child: TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                      decoration: _inputDecoration('Full Name'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // EMAIL
                  // ----------------------------------------------------------
                  Semantics(
                    textField: true,
                    label: 'Email address',
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                      decoration: _inputDecoration('Email'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // PASSWORD
                  // ----------------------------------------------------------
                  Semantics(
                    textField: true,
                    label: 'Password',
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                      decoration: _inputDecoration('Password'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------
                  // CONFIRM PASSWORD
                  //
                  // Checked in _submit(): both passwords must match before
                  // the account is created.
                  // ----------------------------------------------------------
                  Semantics(
                    textField: true,
                    label: 'Confirm password',
                    child: TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      enabled: !_isSubmitting,
                      onSubmitted: (_) {
                        if (!_isSubmitting) {
                          _submit();
                        }
                      },
                      decoration: _inputDecoration('Confirm Password'),
                    ),
                  ),

                  // ----------------------------------------------------------
                  // ERROR MESSAGE
                  // ----------------------------------------------------------
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ----------------------------------------------------------
                  // SIGN UP BUTTON
                  // ----------------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F80ED),
                        disabledBackgroundColor: const Color(0xFF9FC5F8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Creating account',
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ----------------------------------------------------------
                  // LOGIN
                  // A real button: announced by screen readers and has a
                  // 48 x 48 minimum tap target.
                  // ----------------------------------------------------------
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSubmitting ? null : _goToLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2F80ED),
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2F80ED),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}