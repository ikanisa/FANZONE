import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/runtime/app_runtime_state.dart';
import '../../theme/colors.dart';

class FzOfflineBanner extends StatelessWidget {
  const FzOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appRuntime.isOffline,
      builder: (context, isOffline, child) {
        if (!isOffline) return const SizedBox.shrink();

        return Material(
          color: FzColors.warning,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.wifiOff,
                    size: 14,
                    color: FzColors.darkBg,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode — viewing cached data',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FzColors.darkBg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
