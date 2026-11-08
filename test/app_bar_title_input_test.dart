import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'scaffold_slivers_test.dart' show phone, rows;

Widget _page({
  required bool sliver,
  required Widget title,
  Widget? largeTitle,
  ScrollController? scroll,
  bool rtl = false,
}) => CupertinoApp(
  home: Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: sliver
        ? CustomScrollView(
            controller: scroll,
            slivers: [
              LiquidPrismSliverAppBar(title: title, largeTitle: largeTitle),
              ...rows(),
            ],
          )
        : LiquidPrismScaffold(
            title: title,
            largeTitle: largeTitle,
            scrollController: scroll,
            slivers: rows(),
          ),
  ),
);

void main() {
  for (final sliver in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'visible title widgets keep their own input, sliver $sliver RTL $rtl',
        (tester) async {
          phone(tester);
          var taps = 0;
          for (final capsule in [false, true]) {
            await tester.pumpWidget(
              _page(
                sliver: sliver,
                rtl: rtl,
                title: capsule
                    ? LiquidPrismTitle(
                        onPressed: () => taps++,
                        child: const Text('Workspace'),
                      )
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => taps++,
                        child: const Text('Workspace'),
                      ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Workspace'));
            await tester.pumpAndSettle();
            expect(taps, capsule ? 2 : 1);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'only the visible title handles taps, focus and semantics, sliver $sliver',
      (tester) async {
        phone(tester);
        final semantics = tester.ensureSemantics();
        final scroll = ScrollController(),
            inlineFocus = FocusNode(),
            largeFocus = FocusNode();
        addTearDown(scroll.dispose);
        addTearDown(inlineFocus.dispose);
        addTearDown(largeFocus.dispose);
        var inlineTaps = 0, largeTaps = 0;
        await tester.pumpWidget(
          _page(
            sliver: sliver,
            scroll: scroll,
            title: LiquidPrismButton(
              label: 'Inline action',
              focusNode: inlineFocus,
              onPressed: () => inlineTaps++,
            ),
            largeTitle: LiquidPrismButton(
              label: 'Large action',
              focusNode: largeFocus,
              onPressed: () => largeTaps++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(inlineFocus.canRequestFocus, isFalse);
        expect(largeFocus.canRequestFocus, isTrue);
        expect(find.semantics.byLabel('Inline action'), findsNothing);
        await tester.tapAt(tester.getCenter(find.text('Inline action')));
        expect(inlineTaps, 0);
        await tester.tap(find.text('Large action'));
        await tester.pumpAndSettle();
        expect(largeTaps, 1);
        largeFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(largeTaps, 2);

        scroll.jumpTo(150);
        await tester.pumpAndSettle();
        expect(largeFocus.canRequestFocus, isFalse);
        expect(largeFocus.hasFocus, isFalse);
        expect(inlineFocus.canRequestFocus, isTrue);
        expect(find.semantics.byLabel('Large action'), findsNothing);
        await tester.tap(find.text('Inline action'));
        await tester.pumpAndSettle();
        expect(inlineTaps, 1);
        inlineFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(inlineTaps, 2);
        expect(largeTaps, 2);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
