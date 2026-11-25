import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/firebase/auth_service.dart';
import '../../state/auth_state_notifier.dart';
import '../../widgets/page_header.dart';
import '../../widgets/page_help_button.dart';
import 'sign_up_screen.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

// ---------------------------------------------------------------------------
// THEME
// Light, off-white base with a soft ambient shadow + cyan glow behind the
// header, and a white elevated panel below — no solid black anywhere.
// ---------------------------------------------------------------------------
class _AuthTheme {
  const _AuthTheme._();

  static const pageBackground = AppColors.cream;
  static const panelBackground = AppColors.cream;
  static const fieldFill = AppColors.cream;
  static const fieldBorder = AppColors.cream;

  static const textPrimary = AppColors.brown;
  static const textSecondary = AppColors.brown;

  static const loginButton = AppColors.brown;
  static const error = AppColors.brown;

  static const ambientShadow = AppColors.brown;
  static const glowCyan = AppColors.brown;

  static const panelShadow = [
    BoxShadow(
      color: AppColors.brown,
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
                      children: [
                        Text(
                          context.tr('Welcome back', 'مرحبًا بعودتك'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(
                            'Sign in to keep exploring',
                            'سجّل الدخول لمواصلة الاستكشاف',
                          ),
                          style: const TextStyle(
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Same title style and row height as every page header.
              SizedBox(
                height: kToolbarHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PageTitle(context.tr('Droobi', 'دروبي')),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('Login', 'تسجيل الدخول'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _AuthTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const PageHelpButton(
                    title: 'Sign In',
                    titleAr: 'تسجيل الدخول',
                    description:
                'The Droobi/Login heading is at the top-left, the Sign Up pill is at the top-right, and the sign-in form is in a panel below. The Email and Password fields are stacked vertically; the Login button is below them.',
                    descriptionAr:
                'يظهر عنوان دروبي و«تسجيل الدخول» أعلى اليمين، وزر «إنشاء حساب» أعلى اليسار، ونموذج تسجيل الدخول في لوحة أسفلهما. حقلا البريد الإلكتروني وكلمة المرور مرتبان عموديًا، وزر «دخول» أسفلهما.',
                    tips: [
                  'In the form panel below the header, tap the Email field and type your registered email. The Password field is directly below it; tap it and enter your password.',
                  'Inside the Password field, tap the eye icon on the right to show or hide the password. Then tap the Login button below the fields to submit.',
                  'If an error message appears near the form, read it and check the details and internet connection before retrying. To create an account, tap the Sign Up pill in the top-right corner.',
                ],
              tipsAr: [
                  'في لوحة النموذج أسفل العنوان، اضغط حقل البريد الإلكتروني واكتب بريدك المسجل. يوجد حقل كلمة المرور تحته مباشرة؛ اضغطه وأدخل كلمة المرور.',
                  'داخل حقل كلمة المرور، اضغط رمز العين الموجود في الجهة اليسرى لإظهار كلمة المرور أو إخفائها. ثم اضغط زر «دخول» أسفل الحقول للإرسال.',
                  'إذا ظهرت رسالة خطأ قرب النموذج، اقرأها وتحقق من البيانات واتصال الإنترنت قبل إعادة المحاولة. لإنشاء حساب، اضغط زر «إنشاء حساب» أعلى يسار الشاشة.',
                ],
                  ),
                ],
              ),
              ],
            ),
          ),
          // Vertically centred on the title row.
          SizedBox(
            height: kToolbarHeight,
            child: Center(child: _SignUpPill(onTap: onSignUpTap)),
          ),
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
      color: AppColors.cream,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.brown, width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      shadowColor: AppColors.brown,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            context.tr('SignUp', 'إنشاء حساب'),
            style: const TextStyle(
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            Semantics(
              textField: true,
              label: context.tr('Email address', 'البريد الإلكتروني'),
              child: _RoundedField(
                controller: emailController,
                hintText: context.tr('Email', 'البريد الإلكتروني'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !isSubmitting,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              textField: true,
              label: context.tr('Password', 'كلمة المرور'),
              child: _RoundedField(
                controller: passwordController,
                hintText: context.tr('Password', 'كلمة المرور'),
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
                  context.localizeMessage(errorMessage!),
                  style: const TextStyle(color: _AuthTheme.error, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
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
                child: Text(
                  context.tr('Forgot password?', 'نسيت كلمة المرور؟'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                  foregroundColor: AppColors.cream,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: context.tr('Signing in', 'جارٍ تسجيل الدخول'),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cream),
                        ),
                      )
                    : Text(
                        context.tr('Login', 'دخول'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.tr("Don't have an account?", 'ليس لديك حساب؟'),
                  style: const TextStyle(fontSize: 14, color: _AuthTheme.textSecondary),
                ),
                TextButton(
                  onPressed: onSignUpTap,
                  style: TextButton.styleFrom(
                    foregroundColor: _AuthTheme.textPrimary,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    context.tr('Sign up', 'أنشئ حسابًا'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: color == AppColors.brown ? 2 : 1.5),
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
        suffixIcon: suffixIcon == null
            ? null
            : SizedBox(width: 48, height: 48, child: suffixIcon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}