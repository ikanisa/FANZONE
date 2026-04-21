import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/colors.dart';
import 'country_code_picker.dart';
import 'onboarding_step_chrome.dart';

class OnboardingPhoneStep extends StatelessWidget {
  const OnboardingPhoneStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.phoneController,
    required this.onChanged,
    required this.canContinue,
    required this.onBack,
    required this.onNext,
    required this.selectedCountry,
    this.onGuest,
    this.guestLoading = false,
    this.buttonLabel = 'SEND OTP',
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final TextEditingController phoneController;
  final ValueChanged<String> onChanged;
  final bool canContinue;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback? onGuest;
  final bool guestLoading;
  final CountryEntry selectedCountry;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingBackButtonRow(onBack: onBack),
            const Spacer(),
            OnboardingSectionTitle(
              title: 'WHATSAPP LOGIN',
              textColor: textColor,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'We\'ll send you an OTP via WhatsApp. No names or emails required.',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? FzColors.darkSurface2
                          : FzColors.lightSurface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? FzColors.darkBorder
                            : FzColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      selectedCountry.dialCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                    ],
                    onChanged: onChanged,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: selectedCountry.hint.isNotEmpty
                          ? selectedCountry.hint
                          : 'Phone number',
                      filled: true,
                      fillColor: isDark
                          ? FzColors.darkSurface2
                          : FzColors.lightSurface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? FzColors.darkBorder
                              : FzColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? FzColors.darkBorder
                              : FzColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: FzColors.primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            OnboardingPrimaryButton(
              label: buttonLabel,
              onTap: canContinue ? onNext : null,
            ),
            if (onGuest != null) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: guestLoading ? null : onGuest,
                  child: Text(
                    guestLoading ? 'Loading...' : 'Continue as Guest',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OnboardingOtpStep extends StatelessWidget {
  const OnboardingOtpStep({
    super.key,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.otpControllers,
    required this.otpFocusNodes,
    required this.onOtpChanged,
    required this.canVerify,
    required this.onBack,
    required this.onNext,
    this.buttonLabel = 'VERIFY CODE',
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final List<TextEditingController> otpControllers;
  final List<FocusNode> otpFocusNodes;
  final VoidCallback onOtpChanged;
  final bool canVerify;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingBackButtonRow(onBack: onBack),
            const Spacer(),
            OnboardingSectionTitle(title: 'VERIFY OTP', textColor: textColor),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code sent to your WhatsApp.',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                6,
                (index) => SizedBox(
                  width: 48,
                  child: TextField(
                    controller: otpControllers[index],
                    focusNode: otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty &&
                          index < otpControllers.length - 1) {
                        otpFocusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        otpFocusNodes[index - 1].requestFocus();
                      }
                      onOtpChanged();
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark
                          ? FzColors.darkSurface2
                          : FzColors.lightSurface2,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? FzColors.darkBorder
                              : FzColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? FzColors.darkBorder
                              : FzColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: FzColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            OnboardingPrimaryButton(
              label: buttonLabel,
              onTap: canVerify ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}
