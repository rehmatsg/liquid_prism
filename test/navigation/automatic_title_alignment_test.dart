import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets('folded rail titles lead unless set or glass', (tester) async {
    PrismToolbarItem item(PrismToolbarPlacement placement) => PrismToolbarItem(
      label: 'Action',
      icon: const Icon(CupertinoIcons.ellipsis),
      placement: placement,
      onPressed: () {},
    );
    const trailing = SizedBox(width: 44, height: 44);
    const leading = PrismTitleAlignment.leading;
    const center = PrismTitleAlignment.center;
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
              PrismTitleAlignment,
              Widget,
              Widget?,
              List<PrismToolbarContent>,
              PrismTitleAlignment?,
            )
          >[
            ('no actions', leading, const Text('Inbox'), null, [], null),
            (
              'only bottom toolbar items',
              leading,
              const Text('Inbox'),
              null,
              [item(PrismToolbarPlacement.bottom)],
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
              [item(PrismToolbarPlacement.automatic)],
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
              const PrismTitle(child: Text('Inbox')),
              trailing,
              [],
              null,
            ),
          ]) {
        await tester.pumpWidget(
          CupertinoApp(
            home: PrismScaffold(
              title: title,
              trailing: trailingWidget,
              toolbar: toolbar,
              navigationBarStyle: PrismNavigationBarStyle(
                titleAlignment: explicit,
              ),
              body: const SizedBox.expand(key: Key('rail body')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final body = tester.element(find.byKey(const Key('rail body')));
        expect(
          PrismScaffold.placementOf(body),
          left ? PrismChromePlacement.leftRail : PrismChromePlacement.rightRail,
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
  });
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
        Widget app(double actionWidth, {PrismTitleAlignment? alignment}) {
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
          final style = PrismNavigationBarStyle(titleAlignment: alignment);
          return CupertinoApp(
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: sliver
                  ? CustomScrollView(
                      slivers: [
                        PrismSliverAppBar(
                          title: title,
                          trailing: trailing,
                          navigationBarStyle: style,
                          automaticallyImplyLeading: false,
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                      ],
                    )
                  : PrismScaffold(
                      title: title,
                      trailing: trailing,
                      navigationBarStyle: style,
                      automaticallyImplyLeading: false,
                      body: const SizedBox.expand(),
                    ),
            ),
          );
        }

        await tester.pumpWidget(app(44));
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byKey(titleKey)).dx, closeTo(201, .01));

        await tester.pumpWidget(app(144));
        await tester.pumpAndSettle();
        final title = tester.getRect(find.byKey(titleKey));
        expect(title.width, 150);
        expect(rtl ? title.right : title.left, closeTo(rtl ? 386 : 16, .01));
        await tester.tapAt(
          Offset(rtl ? title.left + 5 : title.right - 5, title.center.dy),
        );
        expect(taps, 1);

        await tester.pumpWidget(
          app(144, alignment: PrismTitleAlignment.center),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byKey(titleKey)).dx, closeTo(201, .01));
        expect(tester.getSize(find.byKey(titleKey)).width, lessThan(150));

        await tester.pumpWidget(
          app(0, alignment: PrismTitleAlignment.automatic),
        );
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.byKey(titleKey)).dx, closeTo(201, .01));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('default title alignment by device, sheet and action count', (
    tester,
  ) async {
    PrismToolbarItem item(String label) => PrismToolbarItem(
      label: label,
      icon: const Icon(CupertinoIcons.star),
      onPressed: () {},
    );
    void view(Size size, FakeViewPadding padding) {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size
        ..padding = padding
        ..viewPadding = padding;
    }

    addTearDown(tester.view.reset);
    const phone = Size(402, 874);
    const phonePadding = FakeViewPadding(top: 62, bottom: 34);
    const folded = Size(466, 678);
    const unfolded = Size(951, 669);
    const railPadding = FakeViewPadding(right: 84, bottom: 34);
    for (final (name, size, padding, actions, sheet, centered)
        in <(String, Size, FakeViewPadding, int, bool, bool)>[
          ('iPhone, one action', phone, phonePadding, 1, false, true),
          ('iPhone, two actions', phone, phonePadding, 2, false, false),
          ('folded Duo sheet', folded, railPadding, 1, true, true),
          (
            'folded Duo sheet, two actions',
            folded,
            railPadding,
            2,
            true,
            false,
          ),
          ('unfolded Duo, one action', unfolded, railPadding, 1, false, true),
          ('unfolded Duo, two actions', unfolded, railPadding, 2, false, false),
        ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      view(size, padding);
      await tester.pumpWidget(
        CupertinoApp(
          home: PrismScaffold(
            title: const Text('Inbox'),
            sheet: sheet,
            toolbar: [for (var i = 0; i < actions; i++) item('Action $i')],
            body: const SizedBox.expand(key: Key('body')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final body = tester.element(find.byKey(const Key('body')));
      final inset = MediaQuery.paddingOf(body);
      final text = tester.getRect(find.text('Inbox'));
      if (centered) {
        expect(
          text.center.dx,
          closeTo((inset.left + size.width - inset.right) / 2, .01),
          reason: name,
        );
      } else {
        expect(text.left, closeTo(inset.left + 16, .01), reason: name);
      }
      expect(tester.takeException(), isNull, reason: name);
    }
  });
}
