import 'package:flutter/material.dart';
import 'package:aquagas/theme/app_colors.dart';

/// Logo widget for Sign In screen
class SignInLogo extends StatelessWidget {
  const SignInLogo({super.key});

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates the logo's paint layer from the rest of
    // the (scrolling, animating) form so it's never re-rasterized
    // unless the logo itself changes.
    return RepaintBoundary(
      child: Image.asset(
        'assets/assets/images/logo.png',
        height: 100,
        semanticLabel: 'AquaGas Logo',
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            width: 100,
            decoration: const BoxDecoration(
              color: AppColors.green100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop,
              size: 50,
              color: AppColors.green600,
            ),
          );
        },
      ),
    );
  }
}

/// Header text for Sign In screen
class SignInHeader extends StatelessWidget {
  const SignInHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Text(
          'Welcome to AquaGas',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: AppColors.slate800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Enter your email and password to sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required String hint,
  required IconData icon,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.slate100),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: AppColors.slate500),
    suffixIcon: suffixIcon,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.green500, width: 1.6),
    ),
    errorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.red500, width: 1.4),
    ),
    focusedErrorBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.red500, width: 1.6),
    ),
    filled: true,
    fillColor: AppColors.slate100.withOpacity(0.4),
  );
}

/// Email input field with validation
class SignInEmailField extends StatelessWidget {
  final TextEditingController controller;

  const SignInEmailField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: _fieldDecoration(
        label: 'Email',
        hint: 'Enter your email',
        icon: Icons.email_outlined,
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const <String>[AutofillHints.email],
      // Validates as the user types (after their first interaction with
      // the field) instead of only on submit — catches typos earlier
      // without being noisy on a field the user hasn't touched yet.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validateEmail,
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }
}

/// Password input field with visibility toggle.
///
/// Visibility state is passed in as a [ValueListenable] so toggling
/// "show password" only rebuilds this field, not the whole form.
class SignInPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final ValueListenable<bool> obscurePassword;
  final VoidCallback onToggleVisibility;
  final VoidCallback onSubmit;

  const SignInPasswordField({
    super.key,
    required this.controller,
    required this.obscurePassword,
    required this.onToggleVisibility,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: obscurePassword,
      builder: (context, obscure, _) {
        return TextFormField(
          controller: controller,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.password],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _fieldDecoration(
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.slate500,
              ),
              onPressed: onToggleVisibility,
              tooltip: obscure ? 'Show password' : 'Hide password',
            ),
          ),
          validator: _validatePassword,
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.trim().length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}

/// Remember Me checkbox and Forgot Password link row.
///
/// Both flags come in as [ValueListenable]s so a checkbox tap doesn't
/// force the sign-in / Google buttons (or vice versa) to rebuild.
class SignInRememberMeRow extends StatelessWidget {
  final ValueListenable<bool> rememberMe;
  final ValueListenable<bool> isLoading;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onForgotPassword;

  const SignInRememberMeRow({
    super.key,
    required this.rememberMe,
    required this.isLoading,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        ValueListenableBuilder<bool>(
          valueListenable: rememberMe,
          builder: (context, checked, _) {
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onRememberMeChanged(!checked),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Checkbox(
                      value: checked,
                      onChanged: onRememberMeChanged,
                      activeColor: AppColors.green600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Text(
                      'Remember Me',
                      style: TextStyle(fontSize: 14, color: AppColors.slate800),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: isLoading,
          builder: (context, loading, _) {
            return TextButton(
              onPressed: loading ? null : onForgotPassword,
              style: TextButton.styleFrom(foregroundColor: AppColors.green600),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Primary Sign In button with gradient.
///
/// Orange gradient replaced with the shared AquaGas green
/// ([AppColors.greenHeader]). Adds a subtle press animation for tactile
/// feedback, and only rebuilds when [isLoading] actually changes.
class SignInButton extends StatefulWidget {
  final double height;
  final ValueListenable<bool> isLoading;
  final VoidCallback onPressed;

  const SignInButton({
    super.key,
    required this.height,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<SignInButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isLoading,
      builder: (context, loading, _) {
        return GestureDetector(
          onTapDown: loading ? null : (_) => setState(() => _scale = 0.97),
          onTapUp: loading ? null : (_) => setState(() => _scale = 1.0),
          onTapCancel: loading ? null : () => setState(() => _scale = 1.0),
          onTap: loading ? null : widget.onPressed,
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 100),
            child: SizedBox(
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: loading
                      ? LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade500],
                        )
                      : AppColors.greenHeader,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: loading ? null : AppColors.softShadow(),
                ),
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Divider with "Or continue with" text
class SignInDivider extends StatelessWidget {
  const SignInDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Divider(color: AppColors.slate100, thickness: 1.4),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Or continue with',
            style: TextStyle(
              color: AppColors.slate500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.slate100, thickness: 1.4),
        ),
      ],
    );
  }
}

/// Google Sign In button
class GoogleSignInButton extends StatelessWidget {
  final double height;
  final ValueListenable<bool> isLoading;
  final VoidCallback onPressed;

  const GoogleSignInButton({
    super.key,
    required this.height,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLoading,
      builder: (context, loading, _) {
        return SizedBox(
          height: height,
          child: OutlinedButton.icon(
            onPressed: loading ? null : onPressed,
            icon: loading
                ? const SizedBox.shrink()
                : Image.asset(
                    'assets/google_logo.png',
                    height: 24,
                    width: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.g_mobiledata, size: 28);
                    },
                  ),
            label: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Sign in with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800,
                    ),
                  ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(
                color: loading ? Colors.grey.shade300 : AppColors.slate100,
                width: 1.5,
              ),
              backgroundColor: Colors.white,
              elevation: 1,
            ),
          ),
        );
      },
    );
  }
}

/// Sign Up link with styled text
class SignUpLink extends StatelessWidget {
  final ValueListenable<bool> isLoading;
  final VoidCallback onPressed;

  const SignUpLink({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLoading,
      builder: (context, loading, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "Don't have an account? ",
              style: TextStyle(fontSize: 15, color: AppColors.slate500),
            ),
            TextButton(
              onPressed: loading ? null : onPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.green600,
              ),
              child: const Text(
                'Sign up',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}