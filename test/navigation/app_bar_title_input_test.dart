import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';
import 'package:liquid_prism/src/rendering/surface.dart';

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
              PrismSliverAppBar(title: title, largeTitle: largeTitle),
              ...rows(),
            ],
          )
        : PrismScaffold(
            title: title,
            largeTitle: largeTitle,
            scrollController: scroll,
            slivers: rows(),
          ),
  ),
);

void main() {
  for (final sliver in [false, true]) {
    testWidgets(
      'inline glass title matches icon button height, sliver $sliver',
      (tester) async {
        phone(tester);
        for (final row in [
          (subtitle: false, pressed: false, height: null),
          (subtitle: true, pressed: false, height: null),
          (subtitle: true, pressed: true, height: null),
          (subtitle: true, pressed: true, height: 60.0),
        ]) {
          for (final rail in sliver ? [false] : [false, true]) {
            final subtitle = row.subtitle ? const Text('Company') : null;
            final actions = [
              PrismToolbarItem(
                icon: const Icon(CupertinoIcons.ellipsis),
                label: 'Options',
                onPressed: () {},
              ),
            ];
            final title = PrismTitle(
              style: const PrismTitleStyle(leadingSize: 32),
              leading: const SizedBox.square(dimension: 32),
              onPressed: row.pressed ? () {} : null,
              child: const Text('Software Engineer'),
            );
            await tester.pumpWidget(
              CupertinoApp(
                home: PrismTheme(
                  data: PrismThemeData(
                    toolbar: PrismToolbarStyle(height: row.height),
                  ),
                  child: sliver
                      ? CustomScrollView(
                          slivers: [
                            PrismSliverAppBar(
                              title: title,
                              subtitle: subtitle,
                              toolbar: actions,
                            ),
                            ...rows(),
                          ],
                        )
                      : PrismScaffold(
                          placement: rail
                              ? PrismChromePlacement.rightRail
                              : PrismChromePlacement.bottom,
                          title: title,
                          subtitle: subtitle,
                          toolbar: actions,
                          slivers: rows(),
                        ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final titleGlass = find.descendant(
              of: find.byType(PrismTitle),
              matching: find.byType(RawPrismSurface),
            );
            final actionGlass = find.descendant(
              of: find.byType(PrismToolbar),
              matching: find.byType(RawPrismSurface),
            );
            expect(
              tester.getSize(titleGlass).height,
              tester.getSize(actionGlass).height,
            );
            expect(tester.takeException(), isNull);
          }
        }
      },
    );

    testWidgets(
      'subtitle stays inside inline avatar glass at large text, sliver $sliver',
      (tester) async {
        phone(tester);
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: sliver
                  ? CustomScrollView(
                      slivers: [
                        const PrismSliverAppBar(
                          title: PrismTitle(
                            style: PrismTitleStyle(leadingSize: 32),
                            leading: SizedBox(key: Key('logo')),
                            child: Text('Engineer'),
                          ),
                          subtitle: Text('SpaceX'),
                        ),
                        ...rows(),
                      ],
                    )
                  : PrismScaffold(
                      title: const PrismTitle(
                        style: PrismTitleStyle(leadingSize: 32),
                        leading: SizedBox(key: Key('logo')),
                        child: Text('Engineer'),
                      ),
                      subtitle: const Text('SpaceX'),
                      slivers: rows(),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final glass = find.descendant(
          of: find.byType(PrismTitle),
          matching: find.byType(RawPrismSurface),
        );
        final subtitle = find.text('SpaceX');
        expect(
          find.ancestor(of: subtitle, matching: find.byType(RawPrismSurface)),
          findsOneWidget,
        );
        final capsule = tester.getRect(glass);
        expect(capsule.contains(tester.getBottomRight(subtitle)), isTrue);
        expect(
          tester.getCenter(find.byKey(const Key('logo'))).dx,
          lessThan(tester.getTopLeft(find.text('Engineer')).dx),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'glass title retains its backdrop while revealing, sliver $sliver',
      (tester) async {
        phone(tester);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          _page(
            sliver: sliver,
            scroll: scroll,
            title: const PrismTitle(
              leading: SizedBox(key: Key('revealed logo')),
              child: Text('Workspace'),
            ),
            largeTitle: const Text('Large'),
          ),
        );
        await tester.pumpAndSettle();
        scroll.jumpTo(150);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final glass = find.descendant(
          of: find.byType(PrismTitle),
          matching: find.byType(RawPrismSurface),
        );
        expect(glass, findsOneWidget);
        final scopes = tester.widgetList<Opacity>(
          find.ancestor(of: glass, matching: find.byType(Opacity)),
        );
        expect(
          scopes.where((scope) => scope.opacity > 0 && scope.opacity < 1),
          isEmpty,
          reason:
              'an ancestor opacity isolates the live backdrop during reveal',
        );
        final filters = tester.widgetList<ImageFiltered>(
          find.ancestor(of: glass, matching: find.byType(ImageFiltered)),
        );
        expect(
          filters.where((filter) => filter.enabled),
          isEmpty,
          reason: 'an ancestor image filter isolates the backdrop',
        );
        expect(PrismPresence.of(tester.element(glass)), inExclusiveRange(0, 1));
        final logoOpacity = tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(const Key('revealed logo')),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity;
        expect(
          logoOpacity,
          closeTo(PrismPresence.of(tester.element(glass)), .001),
        );
        await tester.pumpAndSettle();
        expect(PrismPresence.of(tester.element(glass)), 1);
      },
    );
  }
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
                    ? PrismTitle(
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
            title: PrismButton(
              label: 'Inline action',
              focusNode: inlineFocus,
              onPressed: () => inlineTaps++,
            ),
            largeTitle: PrismButton(
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
