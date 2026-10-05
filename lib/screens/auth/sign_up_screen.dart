import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/firebase/auth_service.dart';
import '../../state/auth_state_notifier.dart';
import 'sign_in_screen.dart';

// ---------------------------------------------------------------------------
// THEME
// Mirrors the palette used on SignInScreen so both auth screens feel like
// one flow. If you pull the login screen's _AuthTheme into a shared file
// later, this block can just import that instead of duplicating it.
// ---------------------------------------------------------------------------
class _AuthTheme {
  const _AuthTheme._();

  static const pageBackground = Color(0xFFF7F7F9);
  static const panelBackground = Colors.white;
  static const fieldFill = Color(0xFFF2F3F5);
  static const fieldBorder = Color(0xFFE6E7EB);

  static const textPrimary = Color(0xFF1E3A8A);
  static const textSecondary = Color(0xFF5B7FDE);

  static const accent = Color(0xFF2F6FED);
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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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

      // The screen may have been closed while the request was running.
      if (!mounted) return;

      // Sign-up succeeded — send the user back to the sign-in screen.
      _returnToSignIn();
    } on AuthFailure catch (e) {
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
    _returnToSignIn();
  }

  // This screen is normally opened from the sign-in screen, so going
  // back returns to it instead of stacking a second sign-in screen.
  void _returnToSignIn() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                _Header(onLoginTap: _isSubmitting ? null : _goToLogin),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Join Droobi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _AuthTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Create an account to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: _AuthTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SignUpPanel(
                  nameController: _nameController,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  confirmPasswordController: _confirmPasswordController,
                  isSubmitting: _isSubmitting,
                  obscurePassword: _obscurePassword,
                  obscureConfirmPassword: _obscureConfirmPassword,
                  errorMessage: _errorMessage,
                  onTogglePasswordVisibility: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  onToggleConfirmPasswordVisibility: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                  onSubmit: _isSubmitting ? null : _submit,
                  onConfirmSubmitted: (_) {
                    if (!_isSubmitting) _submit();
                  },
                  onLoginTap: _isSubmitting ? null : _goToLogin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft, heavily blurred circular glow — matches SignInScreen.
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

/// "Droobi" wordmark, "Sign Up" subtitle, and a Login pill button that
/// mirrors the SignUp pill on the login screen.
class _Header extends StatelessWidget {
  const _Header({required this.onLoginTap});

  final VoidCallback? onLoginTap;

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
                'Sign Up',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _AuthTheme.textSecondary,
                ),
              ),
            ],
          ),
          _LoginPill(onTap: onLoginTap),
        ],
      ),
    );
  }
}

class _LoginPill extends StatelessWidget {
  const _LoginPill({required this.onTap});

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
            'Login',
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

/// The white rounded bottom panel holding the sign-up form.
class _SignUpPanel extends StatelessWidget {
  const _SignUpPanel({
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isSubmitting,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.errorMessage,
    required this.onTogglePasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onSubmit,
    required this.onConfirmSubmitted,
    required this.onLoginTap,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isSubmitting;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final String? errorMessage;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final VoidCallback? onSubmit;
  final ValueChanged<String> onConfirmSubmitted;
  final VoidCallback? onLoginTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _AuthTheme.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: _AuthTheme.panelShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DADF),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            Semantics(
              header: true,
              child: const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _AuthTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'إنشاء حساب',
              style: TextStyle(fontSize: 13, color: _AuthTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            Semantics(
              textField: true,
              label: 'Full name',
              child: _RoundedField(
                controller: nameController,
                hintText: 'Full Name',
                textInputAction: TextInputAction.next,
                enabled: !isSubmitting,
              ),
            ),
            const SizedBox(height: 14),
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
                textInputAction: TextInputAction.next,
                enabled: !isSubmitting,
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
            const SizedBox(height: 14),
            Semantics(
              textField: true,
              label: 'Confirm password',
              child: _RoundedField(
                controller: confirmPasswordController,
                hintText: 'Confirm Password',
                obscureText: obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                enabled: !isSubmitting,
                onSubmitted: onConfirmSubmitted,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 20,
                    color: _AuthTheme.textSecondary,
                  ),
                  onPressed: onToggleConfirmPasswordVisibility,
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

            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AuthTheme.accent,
                  disabledBackgroundColor: _AuthTheme.accent.withOpacity(0.5),
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
                          semanticsLabel: 'Creating account',
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Sign Up',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(fontSize: 14, color: _AuthTheme.textSecondary),
                ),
                TextButton(
                  onPressed: onLoginTap,
                  style: TextButton.styleFrom(
                    foregroundColor: _AuthTheme.accent,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'Login',
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

/// Light-gray rounded field — same style as SignInScreen's fields.
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
        focusedBorder: _border(_AuthTheme.accent),
        disabledBorder: _border(_AuthTheme.fieldBorder),
      ),
    );
  }
}