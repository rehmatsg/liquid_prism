import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/src/rendering/prism_display.dart';

void main() {
  const channel = EventChannel('liquid_prism/display');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late MockStreamHandlerEventSink events;
  late List<bool> requests;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    requests = [];
    binding.defaultBinaryMessenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          events = sink;
          requests.add((arguments! as Map)['enabled'] as bool);
        },
      ),
    );
  });
  tearDown(() async {
    await PrismDisplay.reset();
    binding.defaultBinaryMessenger.setMockStreamHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('concurrent lazy loads share one EDR request', () async {
    await Future.wait(List.generate(20, (_) => PrismDisplay.configure(null)));
    await Future<void>.delayed(Duration.zero);
    expect(requests, [true]);
    events.success(8.0);
    await Future<void>.delayed(Duration.zero);
    expect(PrismDisplay.headroom.value, 1.3);
    events.success(1.05);
    await Future<void>.delayed(Duration.zero);
    expect(PrismDisplay.headroom.value, 1.05);
    events.success(1.0);
    await Future<void>.delayed(Duration.zero);
    expect(PrismDisplay.headroom.value, 1);
  });

  test(
    'explicit SDR survives subsequent lazy loads and native updates',
    () async {
      await PrismDisplay.configure(false);
      await PrismDisplay.configure(null);
      await Future<void>.delayed(Duration.zero);
      expect(requests, [false]);
      events.success(8.0);
      await Future<void>.delayed(Duration.zero);
      expect(PrismDisplay.headroom.value, 1);
      await PrismDisplay.configure(true);
      await Future<void>.delayed(Duration.zero);
      expect(requests, [false, true]);
      events.success(1.1);
      await Future<void>.delayed(Duration.zero);
      expect(PrismDisplay.headroom.value, 1.1);
    },
  );

  test('invalid data and native errors fall back to SDR', () async {
    await PrismDisplay.configure(true);
    await Future<void>.delayed(Duration.zero);
    for (final value in [double.nan, double.infinity, -1, null, 'unknown']) {
      events.success(value);
      await Future<void>.delayed(Duration.zero);
      expect(PrismDisplay.headroom.value, 1);
    }
    events.success(1.2);
    await Future<void>.delayed(Duration.zero);
    expect(PrismDisplay.headroom.value, 1.2);
    events.error(code: 'unavailable');
    await Future<void>.delayed(Duration.zero);
    expect(PrismDisplay.headroom.value, 1);
  });

  test('other platforms keep SDR without opening a channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await PrismDisplay.configure(true);
    expect(requests, isEmpty);
    expect(PrismDisplay.headroom.value, 1);
  });
}
