import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
    required this.onCountryChanged,
    required this.phoneHelpText,
    required this.phoneHelpIsError,
    this.buttonLabel = 'Send OTP',
  });

  final Color textColor;
  final Color muted;
  final bool isDark;
  final TextEditingController phoneController;
  final ValueChanged<String> onChanged;
  final bool canContinue;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final ValueChanged<CountryEntry> onCountryChanged;
  final CountryEntry selectedCountry;
  final String phoneHelpText;
  final bool phoneHelpIsError;
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
              title: 'WHATSAPP',
              textColor: textColor,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'Select your country code and enter a valid WhatsApp number.',
              style: TextStyle(fontSize: 14, color: muted, height: 1.45),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CountrySelectorButton(
                  selectedCountry: selectedCountry,
                  textColor: textColor,
                  muted: muted,
                  isDark: isDark,
                  onCountryChanged: onCountryChanged,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label:
                            'WhatsApp phone number for ${selectedCountry.countryName}',
                        textField: true,
                        child: TextField(
                          controller: phoneController,
                          autofocus: true,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\s-]'),
                            ),
                          ],
                          onChanged: onChanged,
                          onSubmitted: (_) {
                            if (canContinue) onNext();
                          },
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                          decoration: InputDecoration(
                            hintText: selectedCountry.preset.hint.isNotEmpty
                                ? selectedCountry.preset.hint
                                : 'Phone number',
                            hintStyle: TextStyle(color: muted),
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
                              borderSide: const BorderSide(
                                color: FzColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phoneHelpText,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: phoneHelpIsError ? FzColors.error : muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            OnboardingPrimaryButton(
              label: buttonLabel,
              onTap: canContinue ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountrySelectorButton extends StatelessWidget {
  const _CountrySelectorButton({
    required this.selectedCountry,
    required this.textColor,
    required this.muted,
    required this.isDark,
    required this.onCountryChanged,
  });

  final CountryEntry selectedCountry;
  final Color textColor;
  final Color muted;
  final bool isDark;
  final ValueChanged<CountryEntry> onCountryChanged;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? FzColors.darkBorder : FzColors.lightBorder;
    final surface = isDark ? FzColors.darkSurface2 : FzColors.lightSurface2;

    return Semantics(
      button: true,
      label:
          'Country code ${selectedCountry.countryName}, ${selectedCountry.preset.dialCode}',
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final country = await showCountryCodePicker(
              context,
              selected: selectedCountry,
            );
            if (country != null) onCountryChanged(country);
          },
          child: Container(
            width: 120,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Text(
                  selectedCountry.flagEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedCountry.preset.dialCode,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronDown, size: 16, color: muted),
              ],
            ),
          ),
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
    this.buttonLabel = 'Verify',
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
            OnboardingSectionTitle(title: 'OTP', textColor: textColor),
            const SizedBox(height: 8),
            Text(
              '6-digit code.',
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
