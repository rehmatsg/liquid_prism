import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  for (final rtl in [false, true]) {
    testWidgets('title composition retargets and keeps one action, RTL=$rtl', (
      tester,
    ) async {
      var mode = 0;
      var taps = 0;
      late StateSetter update;
      await tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: LiquidPrismScaffold(
                  title: LiquidPrismTitle(
                    avatar: mode == 0
                        ? const SizedBox(
                            key: Key('above'),
                            width: 64,
                            height: 64,
                          )
                        : null,
                    leading: mode == 1
                        ? const SizedBox(
                            key: Key('inline'),
                            width: 22,
                            height: 22,
                          )
                        : null,
                    semanticLabel: 'Open conversation',
                    onPressed: () => taps++,
                    child: const Text('Conversation'),
                  ),
                  accessory: const PreferredSize(
                    preferredSize: Size.fromHeight(30),
                    child: SizedBox(key: Key('accessory')),
                  ),
                  body: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      double headerBottom() =>
          tester.getTopLeft(find.byKey(const Key('accessory'))).dy;
      final expanded = headerBottom();
      update(() => mode = 1);
      await tester.pump();
      expect(headerBottom(), closeTo(expanded, .01));
      await tester.pump(const Duration(milliseconds: 80));
      final intermediate = headerBottom();
      expect(intermediate, lessThan(expanded));
      await tester.tap(find.text('Conversation'));
      expect(taps, 1);
      update(() => mode = 0);
      await tester.pump();
      expect(headerBottom(), closeTo(intermediate, .01));
      await tester.pumpAndSettle();
      expect(headerBottom(), closeTo(expanded, .01));
      for (final next in [1, 2, 0]) {
        update(() => mode = next);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Conversation'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(taps, 4);
      expect(find.bySemanticsLabel('Open conversation'), findsOneWidget);
      update(() => mode = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a keyed avatar can move between slots during a transition', (
    tester,
  ) async {
    final key = GlobalKey();
    var inline = false;
    late StateSetter update;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            final avatar = SizedBox(key: key);
            return LiquidPrismScaffold(
              title: LiquidPrismTitle(
                avatar: inline ? null : avatar,
                leading: inline ? avatar : null,
                child: const Text('Title'),
              ),
              body: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final element = key.currentContext;
    final expandedSize = tester.getSize(find.byKey(key));
    for (final value in [true, false, true]) {
      update(() => inline = value);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(key), findsOneWidget);
      expect(key.currentContext, same(element));
      expect(
        tester.getSize(find.byKey(key)).width,
        lessThan(expandedSize.width),
      );
      expect(tester.getSize(find.byKey(key)).width, greaterThan(22));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion snaps compositions including a running spring', (
    tester,
  ) async {
    var mode = 0;
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: LiquidPrismScaffold(
                title: LiquidPrismTitle(
                  avatar: mode == 0 ? const SizedBox() : null,
                  child: const Text('Title'),
                ),
                accessory: const PreferredSize(
                  preferredSize: Size.fromHeight(30),
                  child: SizedBox(key: Key('accessory')),
                ),
                body: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => mode = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    update(() => reduced = true);
    await tester.pump();
    final position = tester.getTopLeft(find.byKey(const Key('accessory')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(find.byKey(const Key('accessory'))), position);
    expect(tester.takeException(), isNull);
  });
}
