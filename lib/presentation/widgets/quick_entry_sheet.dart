import 'package:flutter/material.dart';

/// A bottom sheet that asks for one numeric value before saving — used by
/// Quick Add's Water/Weight/Activity rows so opening an item never silently
/// creates a record on its own (contract: the user always sees and
/// confirms the exact value before it's saved).
///
/// Returns the entered value, or `null` if the user cancelled/dismissed.
Future<double?> showNumericEntrySheet(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String unit,
  required double initial,
  required double min,
  required double max,
  required double step,
  List<double> presets = const [],
  int decimals = 0,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NumericEntrySheet(
      title: title,
      icon: icon,
      unit: unit,
      initial: initial,
      min: min,
      max: max,
      step: step,
      presets: presets,
      decimals: decimals,
    ),
  );
}

class _NumericEntrySheet extends StatefulWidget {
  const _NumericEntrySheet({
    required this.title,
    required this.icon,
    required this.unit,
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
    required this.presets,
    required this.decimals,
  });

  final String title;
  final IconData icon;
  final String unit;
  final double initial;
  final double min;
  final double max;
  final double step;
  final List<double> presets;
  final int decimals;

  @override
  State<_NumericEntrySheet> createState() => _NumericEntrySheetState();
}

class _NumericEntrySheetState extends State<_NumericEntrySheet> {
  late double _value = widget.initial;

  String _format(double v) => widget.decimals == 0
      ? v.round().toString()
      : v.toStringAsFixed(widget.decimals);

  void _adjust(double delta) {
    setState(() {
      _value = (_value + delta).clamp(widget.min, widget.max);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  key: const Key('quickEntryCloseButton'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  key: const Key('quickEntryDecrementButton'),
                  onPressed: _value > widget.min ? () => _adjust(-widget.step) : null,
                  icon: const Icon(Icons.remove),
                  iconSize: theme.iconTheme.size ?? 24,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _format(_value),
                        key: const Key('quickEntryValueText'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(widget.unit, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('quickEntryIncrementButton'),
                  onPressed: _value < widget.max ? () => _adjust(widget.step) : null,
                  icon: const Icon(Icons.add),
                  iconSize: theme.iconTheme.size ?? 24,
                ),
              ],
            ),
            Slider(
              value: _value,
              min: widget.min,
              max: widget.max,
              onChanged: (v) => setState(() => _value = v),
            ),
            if (widget.presets.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final preset in widget.presets)
                    ChoiceChip(
                      label: Text('${_format(preset)} ${widget.unit}'),
                      selected: _value == preset,
                      onSelected: (_) => setState(() => _value = preset),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('quickEntrySaveButton'),
              onPressed: () => Navigator.of(context).pop(_value),
              child: const Text('Save'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('quickEntryCancelButton'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sleep's entry needs hours *and* minutes rather than one plain number —
/// a dedicated sheet rather than stretching the generic one to fit two
/// units at once.
Future<double?> showSleepEntrySheet(
  BuildContext context, {
  required double initialHours,
}) {
  final wholeHours = initialHours.floor();
  final minutes = ((initialHours - wholeHours) * 60).round();
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SleepEntrySheet(initialHours: wholeHours, initialMinutes: minutes),
  );
}

class _SleepEntrySheet extends StatefulWidget {
  const _SleepEntrySheet({required this.initialHours, required this.initialMinutes});

  final int initialHours;
  final int initialMinutes;

  @override
  State<_SleepEntrySheet> createState() => _SleepEntrySheetState();
}

class _SleepEntrySheetState extends State<_SleepEntrySheet> {
  late int _hours = widget.initialHours;
  late int _minutes = widget.initialMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Sleep', style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SleepStepper(
                  key: const Key('sleepHoursStepper'),
                  label: 'hours',
                  value: _hours,
                  min: 0,
                  max: 16,
                  onChanged: (v) => setState(() => _hours = v),
                ),
                const SizedBox(width: 24),
                _SleepStepper(
                  key: const Key('sleepMinutesStepper'),
                  label: 'minutes',
                  value: _minutes,
                  min: 0,
                  max: 55,
                  step: 5,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('quickEntrySaveButton'),
              onPressed: () => Navigator.of(context).pop(_hours + _minutes / 60),
              child: const Text('Save'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('quickEntryCancelButton'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStepper extends StatelessWidget {
  const _SleepStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        Text(
          '$value',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(label, style: theme.textTheme.bodyMedium),
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    );
  }
}
