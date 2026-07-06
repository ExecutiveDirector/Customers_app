import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Phone input section widget
class PhoneInputSection extends StatelessWidget {
  final ThemeData theme;
  final double buttonHeight;
  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final String initialCountryCode;
  final bool isPhoneValid;
  final bool isLoading;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onPhoneSubmitted;
  final VoidCallback onSendOTP;

  const PhoneInputSection({
    super.key,
    required this.theme,
    required this.buttonHeight,
    required this.phoneController,
    required this.phoneFocusNode,
    required this.initialCountryCode,
    required this.isPhoneValid,
    required this.isLoading,
    required this.onCountryChanged,
    required this.onPhoneChanged,
    required this.onPhoneSubmitted,
    required this.onSendOTP,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Enter your phone number',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll send you a verification code',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        IntlPhoneField(
          controller: phoneController,
          focusNode: phoneFocusNode,
          initialCountryCode: initialCountryCode,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter your phone number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            errorText: isPhoneValid ? null : 'Invalid phone number format',
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          onCountryChanged: (country) => onCountryChanged(country.code),
          onChanged: (phone) => onPhoneChanged(phone.completeNumber),
          onSubmitted: (String value) => onPhoneSubmitted(),
          keyboardType: TextInputType.phone,
          disableLengthCheck: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: isLoading || !isPhoneValid ? null : onSendOTP,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Send OTP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// OTP input section widget
class OTPInputSection extends StatelessWidget {
  final ThemeData theme;
  final double buttonHeight;
  final TextEditingController otpController;
  final FocusNode otpFocusNode;
  final int otpLength;
  final bool isOTPValid;
  final bool isLoading;
  final int resendSecondsLeft;
  final ValueChanged<String> onOTPChanged;
  final ValueChanged<String> onOTPCompleted;
  final VoidCallback onPasteOTP;
  final VoidCallback onResendOTP;
  final VoidCallback onChangeNumber;
  final VoidCallback onVerifyOTP;

  const OTPInputSection({
    super.key,
    required this.theme,
    required this.buttonHeight,
    required this.otpController,
    required this.otpFocusNode,
    required this.otpLength,
    required this.isOTPValid,
    required this.isLoading,
    required this.resendSecondsLeft,
    required this.onOTPChanged,
    required this.onOTPCompleted,
    required this.onPasteOTP,
    required this.onResendOTP,
    required this.onChangeNumber,
    required this.onVerifyOTP,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Enter verification code',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to your phone',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 24),
        PinCodeTextField(
          controller: otpController,
          focusNode: otpFocusNode,
          appContext: context,
          length: otpLength,
          animationType: AnimationType.fade,
          keyboardType: TextInputType.number,
          enableActiveFill: true,
          autoFocus: true,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(8),
            fieldHeight: 50,
            fieldWidth: 40,
            activeFillColor: isOTPValid ? Colors.white : Colors.red.shade50,
            selectedFillColor: Colors.white,
            inactiveFillColor: Colors.grey.shade100,
            activeColor: isOTPValid ? theme.primaryColor : Colors.red,
            inactiveColor: Colors.grey.shade300,
            selectedColor: theme.primaryColor,
            borderWidth: 2,
          ),
          animationDuration: const Duration(milliseconds: 200),
          backgroundColor: Colors.transparent,
          onChanged: onOTPChanged,
          onCompleted: onOTPCompleted,
        ),
        if (!isOTPValid)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Invalid OTP code. Please try again.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TextButton.icon(
              onPressed: onPasteOTP,
              icon: const Icon(Icons.paste, size: 18),
              label: const Text('Paste'),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            TextButton(
              onPressed: resendSecondsLeft > 0 ? null : onResendOTP,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                resendSecondsLeft > 0
                    ? 'Resend in ${resendSecondsLeft}s'
                    : 'Resend OTP',
                style: TextStyle(
                  color: resendSecondsLeft > 0
                      ? Colors.grey
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: (isLoading ||
                    !isOTPValid ||
                    otpController.text.length != otpLength)
                ? null
                : onVerifyOTP,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Verify OTP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: onChangeNumber,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Change Phone Number',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
