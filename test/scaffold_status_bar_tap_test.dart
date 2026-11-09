import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  for (final rail in [false, true]) {
    for (final afterUp in [false, true]) {
      testWidgets(
        'app taps ignore duplicate status events: rail=$rail, afterUp=$afterUp',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = const Size(466, 874)
            ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
          addTearDown(tester.view.reset);
          final scroll = ScrollController(initialScrollOffset: 500);
          addTearDown(scroll.dispose);
          var titleTaps = 0;
          var actionTaps = 0;
          await tester.pumpWidget(
            CupertinoApp(
              home: LiquidPrismScaffold(
                placement: rail
                    ? GlassChromePlacement.rightRail
                    : GlassChromePlacement.bottom,
                title: LiquidPrismTitle(
                  child: const Text('Title'),
                  onPressed: () => titleTaps++,
                ),
                toolbar: [
                  GlassToolbarItem(
                    icon: const Icon(CupertinoIcons.add),
                    label: 'Action',
                    onPressed: () => actionTaps++,
                  ),
                ],
                scrollController: scroll,
                slivers: [SliverToBoxAdapter(child: SizedBox(height: 4000))],
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final target in [
            find.text('Title'),
            find.byIcon(CupertinoIcons.add),
          ]) {
            final gesture = await tester.startGesture(tester.getCenter(target));
            if (afterUp) await gesture.up();
            tester.simulateStatusBarTap();
            if (!afterUp) await gesture.up();
            await tester.pumpAndSettle();
            expect(scroll.offset, 500);
          }
          expect(titleTaps, 1);
          expect(actionTaps, 1);
          final first = await tester.startGesture(
            tester.getCenter(find.text('Title')),
            pointer: 3,
          );
          final second = await tester.startGesture(
            tester.getCenter(find.byIcon(CupertinoIcons.add)),
            pointer: 4,
          );
          await first.cancel();
          await tester.pump();
          tester.simulateStatusBarTap();
          await tester.pump();
          expect(scroll.offset, 500);
          await second.cancel();
          await tester.pumpAndSettle();
          // A later system-only tap still returns to the top.
          tester.simulateStatusBarTap();
          await tester.pumpAndSettle();
          expect(scroll.offset, 0);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
}
