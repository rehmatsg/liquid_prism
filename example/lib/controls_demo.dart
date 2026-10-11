import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

/// Public API examples; the same fixture is used for native control validation.
class ControlsDemo extends StatefulWidget {
  const ControlsDemo({super.key, this.standalone = false});
  final bool standalone;
  @override
  State<ControlsDemo> createState() => _ControlsDemoState();
}

class _ControlsDemoState extends State<ControlsDemo> {
  bool _enabled = false;
  double _value = .4;
  int _segment = 0;
  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    return DefaultTextStyle(
      style: TextStyle(color: colors.label, fontSize: 17),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D8C8C),
                  Color(0xFF0A1F54),
                  Color(0xFFBFB30D),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 28,
                children: [
                  if (!widget.standalone)
                    LiquidPrismButton(
                      label: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  const Text(
                    'Native controls',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Switch',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  LiquidPrismSwitch(
                    key: const ValueKey('switch'),
                    label: 'Switch',
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                  const Text(
                    'Slider',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(
                    width: 300,
                    child: LiquidPrismSlider(
                      key: const ValueKey('slider'),
                      label: 'Slider',
                      value: _value,
                      onChanged: (value) => setState(() => _value = value),
                    ),
                  ),
                  const Text(
                    'Segmented',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(
                    width: 300,
                    child: LiquidPrismSegmentedControl<int>(
                      key: const ValueKey('segments'),
                      label: 'Segmented',
                      selectedValue: _segment,
                      onValueChanged: (value) =>
                          setState(() => _segment = value),
                      children: const {
                        0: Text('First'),
                        1: Text('Second'),
                        2: Text('Third'),
                      },
                    ),
                  ),
                  const Text(
                    'Disabled',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Row(
                    children: [
                      LiquidPrismSwitch(
                        value: true,
                        onChanged: null,
                        label: 'Disabled switch',
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 180,
                        child: LiquidPrismSlider(
                          value: .4,
                          onChanged: null,
                          label: 'Disabled slider',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    width: 300,
                    child: LiquidPrismSegmentedControl<int>(
                      selectedValue: 1,
                      onValueChanged: null,
                      label: 'Disabled segments',
                      children: {
                        0: Text('First'),
                        1: Text('Second'),
                        2: Text('Third'),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
