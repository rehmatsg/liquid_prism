import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/system_chrome.dart';

void phone(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(402, 874)
    ..padding = const FakeViewPadding(top: 62, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(tester.view.reset);
}

List<Widget> rows([int count = 60]) => [
  SliverList.builder(
    itemCount: count,
    itemBuilder: (context, i) => SizedBox(height: 50, child: Text('Row $i')),
  ),
];

/// Lets a completed refresh show its mark and return.
Future<void> finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only a pull past the trigger refreshes', (tester) async {
    phone(tester);
    var refreshed = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          onRefresh: () async => refreshed++,
          slivers: rows(),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(refreshed, 0);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await finish(tester);
    expect(refreshed, 1);
  });

  testWidgets('a body scroll view refreshes too', (tester) async {
    phone(tester);
    var refreshed = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          onRefresh: () async => refreshed++,
          body: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [SizedBox(height: 50, child: Text('Only row'))],
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await finish(tester);
    expect(refreshed, 1);
  });

  testWidgets('a pull during a refresh does not start another', (tester) async {
    phone(tester);
    var refreshed = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          onRefresh: () {
            refreshed++;
            return pending.future;
          },
          slivers: rows(),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(refreshed, 1);
    expect(find.bySemanticsLabel('Refreshing'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(refreshed, 1);

    pending.complete();
    await finish(tester);
    expect(find.bySemanticsLabel('Refreshing'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await finish(tester);
    expect(refreshed, 2);
  });

  testWidgets('haptics mark the drop leaving, the trigger and the completion', (
    tester,
  ) async {
    phone(tester);
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          onRefresh: () async {},
          slivers: rows(),
        ),
      ),
    );
    // A slow pull crosses every step on the way to the trigger.
    await tester.timedDrag(
      find.byType(CustomScrollView),
      const Offset(0, 500),
      const Duration(milliseconds: 600),
    );
    await finish(tester);
    expect(haptics, hasLength(3));
    expect(haptics[0], contains('lightImpact'));
    expect(haptics[1], contains('mediumImpact'));
    expect(haptics[2], contains('success'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a pull over the completed mark refreshes again', (tester) async {
    phone(tester);
    var refreshed = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          onRefresh: () async => refreshed++,
          slivers: rows(),
        ),
      ),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    // Until the refresh's minimum spin has passed and the check is showing.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.bySemanticsLabel('Refreshing').evaluate().isEmpty) break;
    }
    expect(refreshed, 1);
    expect(find.bySemanticsLabel('Refreshing'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await finish(tester);
    expect(refreshed, 2);
  });

  testWidgets('the large title follows the pull', (tester) async {
    phone(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Inbox'),
          largeTitle: const Text('Large inbox'),
          scrollController: controller,
          onRefresh: () async {},
          slivers: rows(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rest = tester.getTopLeft(find.text('Large inbox')).dy;
    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, 30));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    final pulled = -controller.position.pixels;
    expect(pulled, greaterThan(20));
    expect(
      tester.getTopLeft(find.text('Large inbox')).dy,
      moreOrLessEquals(rest + pulled, epsilon: .5),
    );
    await gesture.up();
    await finish(tester);
    expect(tester.getTopLeft(find.text('Large inbox')).dy, rest);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the plugin reports the island or the notch', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    late MockStreamHandlerEventSink events;
    messenger
      ..setMockMethodCallHandler(
        const MethodChannel('liquid_prism/menus'),
        (call) async => 'iOS 27.2',
      )
      ..setMockStreamHandler(
        SystemChromeListener.channel,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            events = sink;
            sink.success({
              'supported': false,
              'island': [138.5, 14.0, 125.0, 36.5],
            });
          },
        ),
      );
    addTearDown(() {
      unawaited(SystemChromeListener.instance.reset());
      messenger.setMockMethodCallHandler(
        const MethodChannel('liquid_prism/menus'),
        null,
      );
    });
    unawaited(SystemChromeListener.instance.reset());

    final island = LiquidPrismSystemChrome.dynamicIsland;
    await tester.pump();
    await tester.pump();
    expect(island.value, const Rect.fromLTWH(138.5, 14, 125, 36.5));
    expect(SystemChromeListener.instance.notch.value, isNull);

    events.success({
      'supported': false,
      'notch': [114.0, 0.0, 162.0, 34.0],
    });
    await tester.pump();
    await tester.pump();
    expect(island.value, isNull);
    expect(
      SystemChromeListener.instance.notch.value,
      const Rect.fromLTWH(114, 0, 162, 34),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
