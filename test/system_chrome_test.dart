import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/system_chrome.dart' show SystemChromeListener;

/// The unfolded iPhone Duo bent like a book: the fold at the window's center.
const _fold = [455.5, 0.0, 40.0, 669.0, 20.0, 0.0, 20.0, 0.0, 1.0];

void main() {
  test('parses edges, margins and inactive regions', () {
    final chrome = GlassSystemChrome.fromMap({
      'supported': true,
      'verticalBarEdge': 'right',
      'occlusions': [
        [867.0, 0.0, 84.0, 120.0, 0.0, 0.0, 0.0, 0.0, 1.0],
        [677.0, 21.0, 58.0, 37.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      ],
      'divisions': [
        [455.5, 0.0, 40.0, 669.0, 20.0, 0.0, 20.0, 0.0, 0.0],
      ],
    })!;
    expect(chrome.verticalBarEdge, AxisDirection.right);
    expect(chrome.occlusions.map((r) => r.active), [true, false]);
    expect(
      chrome.divisions.single.reserved,
      const Rect.fromLTWH(475.5, 0, 0, 669),
    );
    expect(chrome.displayFeatures, isEmpty, reason: 'the fold is flat');
    expect(GlassSystemChrome.fromMap({'supported': false}), isNull);
    final optedOut = GlassSystemChrome.fromMap({
      'supported': true,
      'verticalBarEdge': 'right',
      'verticalBarBehavior': 'disabled',
    })!;
    expect(optedOut.verticalBarEdge, AxisDirection.right);
    expect(optedOut.hasVerticalBar, isFalse);
  });

  group('with the plugin', () {
    late List<MethodCall> calls;
    setUp(() => calls = []);

    Future<void> report(
      WidgetTester tester,
      Map<String, Object?> chrome,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger
        ..setMockMethodCallHandler(
          const MethodChannel('liquid_prism/menus'),
          (call) async => 'iOS 27.1',
        )
        ..setMockMethodCallHandler(const MethodChannel('liquid_prism/system'), (
          call,
        ) async {
          calls.add(call);
          return true;
        })
        ..setMockStreamHandler(
          SystemChromeListener.channel,
          MockStreamHandler.inline(
            onListen: (_, sink) => sink.success({'supported': true, ...chrome}),
          ),
        );
      addTearDown(() {
        // The stream mock stays installed so the asynchronous cancel that
        // reset() starts still reaches a handler.
        unawaited(SystemChromeListener.instance.reset());
        messenger
          ..setMockMethodCallHandler(
            const MethodChannel('liquid_prism/menus'),
            null,
          )
          ..setMockMethodCallHandler(
            const MethodChannel('liquid_prism/system'),
            null,
          );
      });
      unawaited(SystemChromeListener.instance.reset());
    }

    testWidgets('an app-level scope keeps dialogs out of the fold', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(951, 669);
      addTearDown(tester.view.reset);
      await report(tester, {
        'verticalBarEdge': 'right',
        'divisions': [_fold],
      });
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigator,
          builder: (context, child) => LiquidPrismSystemChrome(child: child!),
          home: const SizedBox.expand(),
        ),
      );
      await tester.pump();
      final context = navigator.currentContext!;
      expect(
        LiquidPrismSystemChrome.of(context)?.verticalBarEdge,
        AxisDirection.right,
      );

      unawaited(
        showCupertinoDialog<void>(
          context: context,
          builder: (_) => const CupertinoAlertDialog(title: Text('Saved')),
        ),
      );
      await tester.pumpAndSettle();
      final dialog = tester.getRect(find.byType(CupertinoAlertDialog));
      // DisplayFeatureSubScreen puts the dialog on one side of the fold.
      expect(
        dialog.right <= 455.5 || dialog.left >= 495.5,
        isTrue,
        reason: '$dialog',
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the scaffold reuses an app-level scope', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(951, 669);
      addTearDown(tester.view.reset);
      await report(tester, {
        'verticalBarEdge': 'right',
        'divisions': [_fold],
      });
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => LiquidPrismSystemChrome(child: child!),
          home: const LiquidPrismScaffold(body: SizedBox.expand(key: _body)),
        ),
      );
      await tester.pump();
      final features = MediaQuery.of(tester.element(find.byKey(_body)))
          .displayFeatures;
      expect(features, hasLength(1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('vertical bar behavior goes to the plugin', (tester) async {
      await report(tester, const {});
      expect(
        await LiquidPrismSystemChrome.setVerticalBarBehavior(
          GlassVerticalBarBehavior.disabled,
        ),
        isTrue,
      );
      expect(calls.single.method, 'setVerticalBarBehavior');
      expect(calls.single.arguments, {'behavior': 'disabled'});
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('without the plugin there is no report and no opt-out', (
    tester,
  ) async {
    await tester.pumpWidget(
      const LiquidPrismSystemChrome(child: SizedBox.expand(key: _body)),
    );
    expect(
      LiquidPrismSystemChrome.of(tester.element(find.byKey(_body))),
      isNull,
    );
    final applied = await tester.runAsync(
      () => LiquidPrismSystemChrome.setVerticalBarBehavior(
        GlassVerticalBarBehavior.disabled,
      ),
    );
    expect(applied, isFalse);
    unawaited(SystemChromeListener.instance.reset());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

const _body = ValueKey('body');
