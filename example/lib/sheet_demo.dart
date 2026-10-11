import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

class SheetDemo extends StatefulWidget {
  const SheetDemo({super.key, this.standalone = false});
  final bool standalone;
  @override
  State<SheetDemo> createState() => _SheetDemoState();
}

class _SheetDemoState extends State<SheetDemo> {
  String? _result;
  GlassSheetDetent _detent = GlassSheetDetent.medium;
  Future<void> _open() async {
    final result = await showLiquidPrismSheet<String>(
      context: context,
      onDetentChanged: (value) {
        if (mounted) setState(() => _detent = value);
      },
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sheet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              LiquidPrismButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop('Done'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Drag the handle or scroll the content to expand. Slide down to dismiss.',
          ),
          const SizedBox(height: 20),
          CupertinoTextField(
            key: const ValueKey('sheet-field'),
            placeholder: 'Name',
            style: TextStyle(color: GlassColors.of(context).label),
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < 20; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text('Row $i'),
            ),
        ],
      ),
    );
    if (mounted) setState(() => _result = result ?? 'Dismissed');
  }

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TextStyle(color: GlassColors.of(context).label, fontSize: 17),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D8C8C), Color(0xFF0A1F54), Color(0xFFBFB30D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 24,
              children: [
                if (!widget.standalone)
                  LiquidPrismButton(
                    label: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                const Text(
                  'Sheet',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'A floating glass presentation with two resting heights.',
                ),
                LiquidPrismButton(
                  key: const ValueKey('open-sheet'),
                  label: 'Show sheet',
                  onPressed: _open,
                  child: const Text('Show sheet'),
                ),
                Text('Last detent: ${_detent.name}'),
                if (_result != null) Text(_result!),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
