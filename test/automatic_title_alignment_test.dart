import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets(
    'rail text titles lead by default and respect explicit centering',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      for (final placement in [
        GlassChromePlacement.leftRail,
        GlassChromePlacement.rightRail,
      ]) {
        for (final centered in [false, true]) {
          await tester.pumpWidget(
            CupertinoApp(
              home: LiquidPrismScaffold(
                placement: placement,
                title: const Text('Inbox'),
                navigationBarStyle: centered
                    ? const GlassNavigationBarStyle(
                        titleAlignment: GlassTitleAlignment.center,
                      )
                    : null,
                body: const SizedBox.expand(key: Key('rail body')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final title = tester.getRect(find.text('Inbox'));
          if (centered) {
            expect(title.left, greaterThan(150));
          } else {
            expect(
              title.left,
              closeTo(
                MediaQuery.paddingOf(
                      tester.element(find.byKey(const Key('rail body'))),
                    ).left +
                    16,
                .01,
              ),
            );
          }
        }
      }
    },
  );
  for (final sliver in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets('automatic title uses remaining room before truncating '
          '(sliver $sliver, RTL $rtl)', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(402, 874)
          ..padding = const FakeViewPadding(top: 62, bottom: 34)
          ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
        addTearDown(tester.view.reset);
        const titleKey = Key('interactive title');
        var taps = 0;
        Widget app(double actionWidth, {GlassTitleAlignment? alignment}) {
          final title = GestureDetector(
            onTap: () => taps++,
            child: const SizedBox(
              key: titleKey,
              width: 150,
              height: 30,
              child: ColoredBox(color: Color(0xFF000000)),
            ),
          );
          final trailing = SizedBox(width: actionWidth, height: 44);
          final style = GlassNavigationBarStyle(titleAlignment: alignment);
          return CupertinoApp(
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: sliver
                  ? CustomScrollView(
                      slivers: [
                        LiquidPrismSliverAppBar(
                          title: title,
                          trailing: trailing,
                          navigationBarStyle: style,
                          automaticallyImplyLeading: false,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                      ],
                    )
                  : LiquidPrismScaffold(
                      title: title,
                      trailing: trailing,
                      navigationBarStyle: style,
                      automaticallyImplyLeading: false,
                      body: const SizedBox.expand(),
                    ),
            ),
          );
        }

        // A single narrow action leaves enough symmetric room.
        await tester.pumpWidget(app(44));
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byKey(titleKey)).dx, closeTo(201, .01));

        // More trailing controls must move the title to the leading side,
        // using the free space instead of cutting it down to the centre gap.
        await tester.pumpWidget(app(144));
        await tester.pumpAndSettle();
        final title = tester.getRect(find.byKey(titleKey));
        expect(title.width, 150);
        expect(rtl ? title.right : title.left, closeTo(rtl ? 386 : 16, .01));
        await tester.tapAt(
          Offset(rtl ? title.left + 5 : title.right - 5, title.center.dy),
        );
        expect(taps, 1);

        // Explicit centering retains its centered/truncated layout.
        await tester.pumpWidget(
          app(144, alignment: GlassTitleAlignment.center),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byKey(titleKey)).dx, closeTo(201, .01));
        expect(tester.getSize(find.byKey(titleKey)).width, lessThan(150));

        // Removing the wide controls restores automatic centering.
        await tester.pumpWidget(
          app(0, alignment: GlassTitleAlignment.automatic),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byKey(titleKey)).dx, closeTo(201, .01));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
