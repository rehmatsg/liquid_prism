import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_prism/src/title.dart' show titleCompositionSpring;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

double paintedWidth(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return (box.localToGlobal(Offset(box.size.width, 0)) -
          box.localToGlobal(Offset.zero))
      .distance;
}

void main() {
  testWidgets('inline logos retain their own layout size and corner geometry', (
    tester,
  ) async {
    for (final size in [22.0, 32.0, 40.0]) {
      const logoKey = Key('sized-logo');
      await tester.pumpWidget(
        CupertinoApp(
          home: LiquidPrismScaffold(
            title: LiquidPrismTitle(
              style: GlassTitleStyle(leadingSize: size, avatarSize: 96),
              leading: SizedBox.square(
                dimension: size,
                child: ClipRSuperellipse(
                  key: logoKey,
                  borderRadius: BorderRadius.circular(size * 2 / 9),
                  child: const ColoredBox(color: Color(0xFF000000)),
                ),
              ),
              child: const Text('Company'),
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(logoKey)), Size.square(size));
      expect(paintedWidth(tester, find.byKey(logoKey)), closeTo(size, .01));
    }
  });

  test('title spring matches sampled SwiftUI snappy motion', () {
    final simulation = SpringSimulation(
      titleCompositionSpring.description,
      0,
      1,
      0,
    );
    // Public SwiftUI Spring samples from tool/title_motion_probe/main.swift.
    final samples = {
      .05: .31406960,
      .10: .71463901,
      .15: .93397586,
      .20: 1.00944991,
      .25: 1.01951009,
      .35: 1.00447578,
    };
    for (final sample in samples.entries) {
      expect(simulation.x(sample.key), closeTo(sample.value, 1e-7));
    }
  });

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
      expect(tester.getSize(find.byKey(key)), Size.square(value ? 22 : 64));
      expect(
        paintedWidth(tester, find.byKey(key)),
        lessThan(expandedSize.width),
      );
      expect(paintedWidth(tester, find.byKey(key)), greaterThan(22));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
  });

  testWidgets(
    'avatar overshoots once visibly before settling in either position',
    (tester) async {
      var inline = false;
      late StateSetter update;
      const avatar = SizedBox(key: Key('spring-avatar'));
      await tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
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
      for (final targetInline in [true, false]) {
        update(() => inline = targetInline);
        await tester.pump();
        final sizes = <double>[];
        for (var frame = 0; frame < 60; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          sizes.add(
            paintedWidth(tester, find.byKey(const Key('spring-avatar'))),
          );
          final avatarBox = tester.renderObject<RenderBox>(
            find.byKey(const Key('spring-avatar')),
          );
          final center = avatarBox.localToGlobal(
            avatarBox.size.center(Offset.zero),
          );
          final titleTop = tester.getTopLeft(find.byType(LiquidPrismTitle)).dy;
          final progress = (64 - sizes.last) / (64 - 22);
          expect(center.dy - titleTop, closeTo(32 + (22 - 32) * progress, .1));
        }
        final target = targetInline ? 22.0 : 64.0;
        final overshoots = sizes
            .map((size) => targetInline ? target - size : size - target)
            .toList();
        expect(overshoots.any((amount) => amount > .5), isTrue);
        var visibleBounces = 0;
        var pastTarget = false;
        for (final amount in overshoots) {
          if (amount > .25 && !pastTarget) visibleBounces++;
          pastTarget = amount > .25;
        }
        expect(visibleBounces, 1);
        expect(sizes.last, closeTo(target, .1));
        expect(tester.takeException(), isNull);
      }
    },
  );

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
