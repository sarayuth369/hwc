import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/accessibility/accessibility_mode_controller.dart';
import 'confirmation_dialog.dart';

/// The single Senior Mode switch used everywhere in the app (contract 4) —
/// there is no separate "senior settings screen" duplicating this control.
class SeniorModeToggle extends StatelessWidget {
  const SeniorModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccessibilityModeController>();
    return SwitchListTile(
      key: const Key('seniorModeSwitch'),
      title: const Text('Senior Mode'),
      subtitle: const Text('Bigger text, higher contrast, simpler screens'),
      value: controller.isSenior,
      onChanged: (enabled) async {
        final confirmed = await showConfirmationDialog(
          context,
          title: enabled ? 'Turn on Senior Mode?' : 'Turn off Senior Mode?',
          message: enabled
              ? 'Text and buttons will get bigger and easier to read.'
              : 'The app will go back to the standard layout.',
        );
        if (confirmed) {
          await context.read<AccessibilityModeController>().toggle();
        }
      },
    );
  }
}
