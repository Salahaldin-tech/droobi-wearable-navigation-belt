import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/firebase/auth_service.dart';
import '../../state/auth_state_notifier.dart';
import 'sign_up_screen.dart';

// ---------------------------------------------------------------------------
// THEME
// Light, off-white base with a soft ambient shadow + cyan glow behind the
// header, and a white elevated panel below — no solid black anywhere.
// ---------------------------------------------------------------------------
class _AuthTheme {
  const _AuthTheme._();

  static const pageBackground = Color(0xFFF7F7F9);
  static const panelBackground = Colors.white;
  static const fieldFill = Color(0xFFF2F3F5);
  static const fieldBorder = Color(0xFFE6E7EB);

  static const textPrimary = Color(0xFF1E3A8A);
  static const textSecondary = Color(0xFF5B7FDE);

  static const loginButton = Color(0xFF2F6FED);
  static const error = Color(0xFFE0483E);

  static const ambientShadow = Color(0xFF2B2E36);
  static const glowCyan = Color(0xFF34D8D1);

  static const panelShadow = [
    BoxShadow(
      color: Color(0x1F16181D),
      blurRadius: 40,
      offset: Offset(0, -8),
    ),
  ];
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Navigation happens automatically through the
      // auth-gated app root watching authStateProvider.
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

  void _openSignUp() {
    if (_isSubmitting) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SignUpScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AuthTheme.pageBackground,
      body: Stack(
        children: [
          // -------------------------------------------------------------
          // AMBIENT BACKGROUND: soft dark blur + cyan glow, both blurred
          // to a diffuse haze rather than a hard-edged block.
          // -------------------------------------------------------------
          const Positioned(
            top: -60,
            left: -40,
            right: -40,
            height: 320,
            child: _BlurredGlow(
              color: _AuthTheme.ambientShadow,
              opacity: 0.16,
              blurSigma: 70,
            ),
          ),
          Positioned(
            top: 20,
            left: MediaQuery.of(context).size.width / 2 - 110,
            child: const _BlurredGlow(
              color: _AuthTheme.glowCyan,
              opacity: 0.22,
              blurSigma: 60,
              width: 220,
              height: 220,
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(onSignUpTap: _isSubmitting ? null : _openSignUp),
                Expanded(
                  flex: 28,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _AuthTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Sign in to keep exploring',
                          style: TextStyle(
                            fontSize: 14,
                            color: _AuthTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 72,
                  child: _LoginPanel(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isSubmitting: _isSubmitting,
                    obscurePassword: _obscurePassword,
                    errorMessage: _errorMessage,
                    onTogglePasswordVisibility: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    onSubmit: _isSubmitting ? null : _submit,
                    onPasswordSubmitted: (_) {
                      if (!_isSubmitting) _submit();
                    },
                    onSignUpTap: _isSubmitting ? null : _openSignUp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft, heavily blurred circular glow used behind the header to create
/// the diffuse ambient-shadow / glow effect from the reference — never a
/// solid block of color.
class _BlurredGlow extends StatelessWidget {
  const _BlurredGlow({
    required this.color,
    required this.opacity,
    required this.blurSigma,
    this.width,
    this.height,
  });

  final Color color;
  final double opacity;
  final double blurSigma;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              shape: width == null ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: width == null ? BorderRadius.circular(200) : null,
              color: color.withOpacity(opacity),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Brilliance." wordmark, "Login" subtitle, and the SignUp pill button.
class _Header extends StatelessWidget {
  const _Header({required this.onSignUpTap});

  final VoidCallback? onSignUpTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Droobi',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _AuthTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Login',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _AuthTheme.textSecondary,
                ),
              ),
            ],
          ),
          _SignUpPill(onTap: onSignUpTap),
        ],
      ),
    );
  }
}

class _SignUpPill extends StatelessWidget {
  const _SignUpPill({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      shadowColor: const Color(0x1A16181D),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            'SignUp',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _AuthTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The large white rounded "bottom sheet" style panel holding the form.
class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.emailController,
    required this.passwordController,
    required this.isSubmitting,
    required this.obscurePassword,
    required this.errorMessage,
    required this.onTogglePasswordVisibility,
    required this.onSubmit,
    required this.onPasswordSubmitted,
    required this.onSignUpTap,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final bool obscurePassword;
  final String? errorMessage;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback? onSubmit;
  final ValueChanged<String> onPasswordSubmitted;
  final VoidCallback? onSignUpTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _AuthTheme.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: _AuthTheme.panelShadow,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DADF),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            Semantics(
              textField: true,
              label: 'Email address',
              child: _RoundedField(
                controller: emailController,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !isSubmitting,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              textField: true,
              label: 'Password',
              child: _RoundedField(
                controller: passwordController,
                hintText: 'Password',
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                enabled: !isSubmitting,
                onSubmitted: onPasswordSubmitted,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: _AuthTheme.textSecondary,
                  ),
                  onPressed: onTogglePasswordVisibility,
                ),
              ),
            ),

            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: _AuthTheme.error, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        // Forgot-password functionality is not changed
                        // because there is currently no existing reset
                        // function in the original SignInScreen.
                      },
                style: TextButton.styleFrom(
                  foregroundColor: _AuthTheme.loginButton,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AuthTheme.loginButton,
                  disabledBackgroundColor: _AuthTheme.loginButton.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Signing in',
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 28),

            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  "Don't have an account?",
                  style: TextStyle(fontSize: 14, color: _AuthTheme.textSecondary),
                ),
                TextButton(
                  onPressed: onSignUpTap,
                  style: TextButton.styleFrom(
                    foregroundColor: _AuthTheme.textPrimary,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'Sign up',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Light-gray rounded field used for both email and password.
class _RoundedField extends StatelessWidget {
  const _RoundedField({
    required this.controller,
    required this.hintText,
    required this.enabled,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: _AuthTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFB0B3BA), fontSize: 15),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _AuthTheme.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _border(_AuthTheme.fieldBorder),
        enabledBorder: _border(_AuthTheme.fieldBorder),
        focusedBorder: _border(_AuthTheme.textPrimary),
        disabledBorder: _border(_AuthTheme.fieldBorder),
      ),
    );
  }
}