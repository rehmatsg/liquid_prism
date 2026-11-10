import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/system_chrome.dart';
import 'package:liquid_prism/src/refresh.dart';

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
  for (final mode in ['compact', 'accessory', 'large', 'custom', 'none']) {
    testWidgets('refresh presentation for $mode header', (tester) async {
      phone(tester);
      final pending = Completer<void>();
      await tester.pumpWidget(
        CupertinoApp(
          home: LiquidPrismScaffold(
            title: mode == 'accessory' || mode == 'none'
                ? null
                : const Text('Feed'),
            largeTitle: mode == 'large' ? const Text('Feed') : null,
            header: mode == 'custom' ? const SizedBox(height: 100) : null,
            accessory: mode == 'accessory'
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(80),
                    child: SizedBox(
                      height: 80,
                      child: Text('Search and filters'),
                    ),
                  )
                : null,
            onRefresh: () => pending.future,
            slivers: rows(),
          ),
        ),
      );
      final rowStart = tester.getTopLeft(find.text('Row 0')).dy;
      final gesture = await tester.startGesture(const Offset(200, 350));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      final paintFinder = find.descendant(
        of: find.byType(GlassRefreshLayer),
        matching: find.byType(CustomPaint),
      );
      List<Invocation> record() {
        final canvas = TestRecordingCanvas();
        tester
            .widget<CustomPaint>(paintFinder)
            .painter!
            .paint(canvas, tester.getSize(paintFinder));
        return canvas.invocations.map((v) => v.invocation).toList();
      }

      final calls = record();
      final compact = mode == 'compact' || mode == 'accessory';
      expect(calls.any((c) => c.memberName == #scale), compact);
      if (compact) {
        final layer = calls.firstWhere((c) => c.memberName == #saveLayer);
        final bounds = layer.positionalArguments[0] as Rect;
        final opacity = (layer.positionalArguments[1] as Paint).color.a;
        expect(opacity, inExclusiveRange(0, 1));
        expect(bounds.center.dy, greaterThan(rowStart));
        expect(
          bounds.center.dy,
          lessThan(tester.getTopLeft(find.text('Row 0')).dy),
        );
      }
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (compact) {
        // Keep room below the pinned header after the scroll bounce finishes.
        expect(
          tester.getTopLeft(find.text('Row 0')).dy - rowStart,
          closeTo(GlassRefreshLayerState.trigger, 1),
        );
      }
      pending.complete();
      await finish(tester);
      expect(tester.getTopLeft(find.text('Row 0')).dy, closeTo(rowStart, 1));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

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

  testWidgets('haptics mark emergence, arming, release and completion', (
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
    expect(haptics, hasLength(4));
    expect(haptics[0], contains('lightImpact'));
    expect(haptics[1], contains('mediumImpact'));
    expect(haptics[2], contains('lightImpact'));
    expect(haptics[3], contains('success'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('release feedback waits for an armed release and fires once', (
    tester,
  ) async {
    phone(tester);
    final events = <GlassHapticKind>[];
    final pending = Completer<void>();
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismTheme(
          data: LiquidPrismThemeData(
            haptics: GlassHaptics((_, event) => events.add(event.kind)),
          ),
          child: LiquidPrismScaffold(
            onRefresh: () => pending.future,
            slivers: rows(),
          ),
        ),
      ),
    );
    var gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(events, isNot(contains(GlassHapticKind.refreshArmed)));
    expect(events, isNot(contains(GlassHapticKind.refreshReleased)));
    // Releasing below the threshold must stay silent.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(events, isNot(contains(GlassHapticKind.refreshReleased)));

    gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    expect(events, contains(GlassHapticKind.refreshArmed));
    expect(events, isNot(contains(GlassHapticKind.refreshReleased)));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      events.where((e) => e == GlassHapticKind.refreshReleased),
      hasLength(1),
    );
    // A pull during the in-flight refresh cannot commit it a second time.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      events.where((e) => e == GlassHapticKind.refreshReleased),
      hasLength(1),
    );
    pending.complete();
    await finish(tester);
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

  testWidgets('a controller starts a refresh and joins a running one', (
    tester,
  ) async {
    phone(tester);
    var refreshed = 0;
    final pending = Completer<void>();
    final controller = LiquidPrismRefreshController();
    addTearDown(controller.dispose);
    final states = <bool>[];
    controller.addListener(() => states.add(controller.isRefreshing));
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          refreshController: controller,
          onRefresh: () {
            refreshed++;
            return pending.future;
          },
          slivers: rows(),
        ),
      ),
    );
    var finished = 0;
    unawaited(controller.refresh().then((_) => finished++));
    unawaited(controller.refresh().then((_) => finished++));
    await tester.pump(const Duration(milliseconds: 400));
    expect(refreshed, 1);
    expect(controller.isRefreshing, isTrue);
    expect(find.bySemanticsLabel('Refreshing'), findsOneWidget);
    expect(finished, 0);

    pending.complete();
    await finish(tester);
    expect(finished, 2);
    expect(controller.isRefreshing, isFalse);
    expect(states, [true, false]);
  });

  testWidgets('a controller does nothing without onRefresh', (tester) async {
    phone(tester);
    final controller = LiquidPrismRefreshController();
    addTearDown(controller.dispose);
    await controller.refresh();
    await tester.pumpWidget(
      CupertinoApp(
        home: LiquidPrismScaffold(
          title: const Text('Feed'),
          refreshController: controller,
          slivers: rows(),
        ),
      ),
    );
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(controller.isRefreshing, isFalse);
  });

  testWidgets(
    'the haptics hook replaces native feedback; false skips the success',
    (tester) async {
      phone(tester);
      final native = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            native.add(call.arguments as String);
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
      final events = <GlassHapticEvent>[];
      var succeed = true;
      final controller = LiquidPrismRefreshController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: LiquidPrismTheme(
            data: LiquidPrismThemeData(
              haptics: GlassHaptics((context, event) => events.add(event)),
            ),
            child: LiquidPrismScaffold(
              title: const Text('Feed'),
              refreshController: controller,
              onRefresh: () async => succeed,
              slivers: rows(),
            ),
          ),
        ),
      );
      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, 500),
        const Duration(milliseconds: 600),
      );
      await finish(tester);
      expect(
        events.every((e) => e.component == GlassHapticComponent.refresh),
        isTrue,
      );
      expect(events.map((e) => e.kind), [
        GlassHapticKind.refreshPulled,
        GlassHapticKind.refreshArmed,
        GlassHapticKind.refreshReleased,
        GlassHapticKind.refreshSucceeded,
      ]);

      // A refresh from code that reports failure: armed, then failed.
      events.clear();
      succeed = false;
      unawaited(controller.refresh());
      await finish(tester);
      expect(events.map((e) => e.kind), [
        GlassHapticKind.refreshArmed,
        GlassHapticKind.refreshFailed,
      ]);
      expect(native, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('a failed refresh plays no success haptic by default', (
    tester,
  ) async {
    phone(tester);
    final native = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          native.add(call.arguments as String);
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
          onRefresh: () async => false,
          slivers: rows(),
        ),
      ),
    );
    await tester.timedDrag(
      find.byType(CustomScrollView),
      const Offset(0, 500),
      const Duration(milliseconds: 600),
    );
    await finish(tester);
    expect(native, hasLength(3));
    expect(native.last, contains('lightImpact'));
    expect(native.any((event) => event.contains('success')), isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('switching onRefresh keeps the page state', (tester) async {
    phone(tester);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var builds = 0;
    Widget page({required bool refresh}) => CupertinoApp(
      home: LiquidPrismScaffold(
        // No bar and no bottom bar: nothing else needs the scroll listener.
        onRefresh: refresh ? () async {} : null,
        body: ListView(
          controller: scroll,
          children: [
            StatefulBuilder(
              builder: (context, setState) {
                builds++;
                return CupertinoTextField(focusNode: focus);
              },
            ),
            for (var i = 0; i < 40; i++)
              SizedBox(height: 50, child: Text('Row $i')),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page(refresh: false));
    focus.requestFocus();
    await tester.pump();
    scroll.jumpTo(20);
    await tester.pump();
    final state = tester.state(find.byType(Scrollable).first);
    final field = tester.state(find.byType(CupertinoTextField));

    for (final refresh in [true, false, true]) {
      await tester.pumpWidget(page(refresh: refresh));
      await tester.pump();
      expect(tester.state(find.byType(Scrollable).first), same(state));
      expect(tester.state(find.byType(CupertinoTextField)), same(field));
      expect(scroll.offset, 20);
      expect(focus.hasFocus, isTrue);
    }
    expect(builds, greaterThan(0));

    // Disabled, a pull does nothing; enabled again, it refreshes.
    await tester.pumpWidget(page(refresh: false));
    scroll.jumpTo(0);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await finish(tester);
    expect(find.bySemanticsLabel('Refreshing'), findsNothing);
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
