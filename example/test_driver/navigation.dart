import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/glass_transition.dart'
    show GlassContentPresence;

Future<void> main() async {
  final key = GlobalKey<NavigationFixtureState>();
  final errors = <String>[];
  final report = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exceptionAsString());
    report?.call(details);
  };
  enableFlutterDriverExtension(
    handler: (message) async {
      final request = jsonDecode(message!) as Map<String, dynamic>;
      final state = key.currentState!;
      switch (request['op']) {
        case 'configure':
          state.configure(request);
          await WidgetsBinding.instance.endOfFrame;
        case 'scroll':
          state.scroll.jumpTo((request['offset'] as num).toDouble());
          await WidgetsBinding.instance.endOfFrame;
        case 'trace':
          final samples = <Object?>[];
          Duration? start;
          var recording = true;
          void sample(Duration time) {
            if (!recording) return;
            start ??= time;
            samples.add({
              't': (time - start!).inMicroseconds / 1e6,
              ...state.sample(),
            });
            WidgetsBinding.instance.addPostFrameCallback(sample);
            WidgetsBinding.instance.scheduleFrame();
          }
          WidgetsBinding.instance.addPostFrameCallback(sample);
          state.scroll.jumpTo((request['offset'] as num).toDouble());
          await Future<void>.delayed(const Duration(milliseconds: 850));
          recording = false;
          return jsonEncode(samples);
      }
      return jsonEncode({
        'errors': errors,
        ...state.sample(),
        'taps': state.taps,
      });
    },
  );
  await LiquidPrism.preload();
  runApp(NavigationFixture(key: key));
}

class NavigationFixture extends StatefulWidget {
  const NavigationFixture({super.key});
  @override
  State<NavigationFixture> createState() => NavigationFixtureState();
}

class NavigationFixtureState extends State<NavigationFixture> {
  ScrollController scroll = ScrollController();
  final inlineKey = GlobalKey(), largeKey = GlobalKey(), backKey = GlobalKey();
  bool sliver = false,
      large = true,
      dark = false,
      rtl = false,
      fixedInsets = false;
  double textScale = 1;
  GlassToolbarMinimizationBehavior behavior =
      GlassToolbarMinimizationBehavior.never;
  GlassToolbarMinimizationRestoration restoration =
      GlassToolbarMinimizationRestoration.automatic;
  GlassTitleAlignment alignment = GlassTitleAlignment.center;
  int taps = 0, revision = 0;

  void configure(Map<String, dynamic> request) {
    setState(() {
      sliver = request['sliver'] as bool? ?? false;
      large = request['large'] as bool? ?? true;
      dark = request['dark'] as bool? ?? false;
      rtl = request['rtl'] as bool? ?? false;
      fixedInsets = request['fixedInsets'] as bool? ?? false;
      textScale = (request['textScale'] as num?)?.toDouble() ?? 1;
      behavior = GlassToolbarMinimizationBehavior.values.byName(
        request['behavior'] as String? ?? 'never',
      );
      restoration = GlassToolbarMinimizationRestoration.values.byName(
        request['restoration'] as String? ?? 'automatic',
      );
      alignment = GlassTitleAlignment.values.byName(
        request['alignment'] as String? ?? 'center',
      );
      revision++;
    });
    scroll.jumpTo(0);
  }

  Map<String, Object?> sample() {
    Map<String, Object?> title(GlobalKey key) {
      final context = key.currentContext;
      if (context == null) return {};
      final box = context.findRenderObject()! as RenderBox;
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      final presence = context
          .findAncestorWidgetOfExactType<GlassContentPresence>();
      return {
        'frame': [rect.left, rect.top, rect.width, rect.height],
        'opacity': presence?.presence.clamp(0.0, 1.0) ?? 1,
      };
    }

    return {
      'inline': title(inlineKey),
      'large': title(largeKey),
      'back': title(backKey),
      'offset': scroll.hasClients ? scroll.offset : 0,
    };
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoApp(
    debugShowCheckedModeBanner: false,
    theme: CupertinoThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
    ),
    home: Builder(
      builder: (context) {
        final style = GlassNavigationBarStyle(
          titleStyle: const TextStyle(
            fontFamily: 'CupertinoSystemText',
            letterSpacing: -.41,
          ),
          largeTitleStyle: const TextStyle(
            fontFamily: 'CupertinoSystemDisplay',
            letterSpacing: .38,
          ),
          titleAlignment: alignment,
          minimizationBehavior: behavior,
          minimizationRestoration: restoration,
          minimizationSafeAreaAdjustment: fixedInsets
              ? GlassToolbarMinimizationSafeAreaAdjustment.disabled
              : GlassToolbarMinimizationSafeAreaAdjustment.automatic,
        );
        final title = Text('Library', key: inlineKey);
        final largeTitle = large ? Text('Library', key: largeKey) : null;
        final back = LiquidPrismBackButton(
          key: backKey,
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => taps++,
        );
        final toolbar = [
          GlassToolbarItem(
            icon: const Icon(CupertinoIcons.ellipsis),
            label: 'More',
            onPressed: () => taps++,
          ),
        ];
        final rows = SliverFixedExtentList.builder(
          itemExtent: 52,
          itemCount: 80,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'Row $index',
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
          ),
        );
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: ColoredBox(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: KeyedSubtree(
                key: ValueKey(revision),
                child: sliver
                    ? CustomScrollView(
                        controller: scroll,
                        slivers: [
                          LiquidPrismSliverAppBar(
                            title: title,
                            largeTitle: largeTitle,
                            leading: back,
                            toolbar: toolbar,
                            navigationBarStyle: style,
                          ),
                          rows,
                        ],
                      )
                    : LiquidPrismScaffold(
                        title: title,
                        largeTitle: largeTitle,
                        leading: back,
                        toolbar: toolbar,
                        navigationBarStyle: style,
                        scrollController: scroll,
                        slivers: [rows],
                      ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
