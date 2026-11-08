// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/src/scroll_edge.dart';

void main() {
  testWidgets(
    'scroll metrics arriving during layout rebuild on the next frame',
    (tester) async {
      final progress = ValueNotifier(0.0);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              ScrollEdgeProgressBuilder(
                listenable: progress,
                progress: () => progress.value,
                builder: (context, value) => Text('Edge $value'),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  progress.value = .2;
                  progress.value = .8;
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(find.text('Edge 0.8'), findsOneWidget);
      expect(tester.takeException(), isNull);

      progress.value = .4;
      await tester.pump();
      expect(find.text('Edge 0.4'), findsOneWidget);
    },
  );
}
