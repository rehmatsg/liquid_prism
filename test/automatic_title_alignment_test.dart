import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets(
    'rail titles center without trailing actions and lead beside them',
    (tester) async {
      GlassToolbarItem item(GlassToolbarPlacement placement) =>
          GlassToolbarItem(
            label: 'Action',
            icon: const Icon(CupertinoIcons.ellipsis),
            placement: placement,
            onPressed: () {},
          );
      const trailing = SizedBox(width: 44, height: 44);
      const leading = GlassTitleAlignment.leading;
      const center = GlassTitleAlignment.center;
      for (final left in [true, false]) {
        await tester.pumpWidget(const SizedBox.shrink());
        final padding = FakeViewPadding(
          left: left ? 84 : 0,
          right: left ? 0 : 84,
          bottom: 34,
        );
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(466, 678)
          ..padding = padding
          ..viewPadding = padding;
        addTearDown(tester.view.reset);
        for (final (name, expected, title, trailingWidget, toolbar, explicit)
            in <
              (
                String,
                GlassTitleAlignment,
                Widget,
                Widget?,
                List<GlassToolbarContent>,
                GlassTitleAlignment?,
              )
            >[
              ('no actions', center, const Text('Inbox'), null, [], null),
              (
                'only bottom toolbar items',
                center,
                const Text('Inbox'),
                null,
                [item(GlassToolbarPlacement.bottom)],
                null,
              ),
              (
                'a trailing widget',
                leading,
                const Text('Inbox'),
                trailing,
                [],
                null,
              ),
              (
                'a top-trailing toolbar item',
                leading,
                const Text('Inbox'),
                null,
                [item(GlassToolbarPlacement.automatic)],
                null,
              ),
              (
                'explicit center beside actions',
                center,
                const Text('Inbox'),
                trailing,
                [],
                center,
              ),
              (
                'explicit leading without actions',
                leading,
                const Text('Inbox'),
                null,
                [],
                leading,
              ),
              (
                'a glass title beside actions',
                center,
                const LiquidPrismTitle(child: Text('Inbox')),
                trailing,
                [],
                null,
              ),
            ]) {
          await tester.pumpWidget(
            CupertinoApp(
              home: LiquidPrismScaffold(
                title: title,
                trailing: trailingWidget,
                toolbar: toolbar,
                navigationBarStyle: GlassNavigationBarStyle(
                  titleAlignment: explicit,
                ),
                body: const SizedBox.expand(key: Key('rail body')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final body = tester.element(find.byKey(const Key('rail body')));
          expect(
            LiquidPrismScaffold.placementOf(body),
            left
                ? GlassChromePlacement.leftRail
                : GlassChromePlacement.rightRail,
          );
          final inset = MediaQuery.paddingOf(body);
          final text = tester.getRect(find.text('Inbox'));
          final reason = '$name, left rail $left';
          if (expected == center) {
            expect(
              text.center.dx,
              closeTo((inset.left + 466 - inset.right) / 2, .01),
              reason: reason,
            );
          } else {
            expect(text.left, closeTo(inset.left + 16, .01), reason: reason);
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
