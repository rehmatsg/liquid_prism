import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/recipe.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Center(child: child),
  ),
);

Widget _card({VoidCallback? onTap}) => GestureDetector(
  onTap: onTap,
  child: const LiquidPrism(
    child: SizedBox(width: 120, height: 80, child: Text('Card')),
  ),
);

void main() {
  test('presence reaches the shader as absence and scales shadows', () {
    final recipe = GlassRecipe.resolve(
      Glass.regular,
      Brightness.dark,
      GlassRole.surface,
      customOptics: false,
    );
    // Slot 44 overall (18 into the recipe packet); zero keeps old output.
    expect(recipe.uniforms[18], 0);
    final half = recipe.withPresence(.5);
    expect(half.uniforms[18], .5);
    expect(half.shadowStrength, recipe.shadowStrength * .5);
  });

  testWidgets('visibility keeps the child through its exit, then removes it', (
    tester,
  ) async {
    var taps = 0;
    var ends = 0;
    Widget build(bool visible) => _host(
      LiquidPrismVisibility(
        visible: visible,
        onEnd: () => ends++,
        child: _card(onTap: () => taps++),
      ),
    );
    await tester.pumpWidget(build(false));
    expect(find.text('Card'), findsNothing);

    await tester.pumpWidget(build(true));
    await tester.pump(const Duration(milliseconds: 60));
    final entering = tester
        .widget<Opacity>(
          find
              .ancestor(of: find.text('Card'), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
    expect(entering, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(ends, 1);
    await tester.tap(find.text('Card'));
    expect(taps, 1);

    await tester.pumpWidget(build(false));
    await tester.pump(const Duration(milliseconds: 60));
    // Still painted while leaving, but no longer interactive or announced.
    expect(find.text('Card'), findsOneWidget);
    await tester.tap(find.text('Card'), warnIfMissed: false);
    expect(taps, 1);
    final semantics = tester.widget<ExcludeSemantics>(
      find
          .ancestor(
            of: find.byType(LiquidPrism),
            matching: find.byType(ExcludeSemantics),
          )
          .first,
    );
    expect(semantics.excluding, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Card'), findsNothing);
    expect(ends, 2);
  });

  testWidgets('identity and reduce motion skip materializing', (tester) async {
    await tester.pumpWidget(
      _host(
        LiquidPrismVisibility(
          visible: false,
          transition: GlassTransition.identity,
          child: _card(),
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        LiquidPrismVisibility(
          visible: true,
          transition: GlassTransition.identity,
          child: _card(),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Card'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        LiquidPrismVisibility(visible: false, child: _card()),
        reduceMotion: true,
      ),
    );
    await tester.pumpWidget(
      _host(
        LiquidPrismVisibility(visible: true, child: _card()),
        reduceMotion: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final blur = tester.widget<ImageFiltered>(
      find
          .ancestor(of: find.text('Card'), matching: find.byType(ImageFiltered))
          .first,
    );
    expect(blur.enabled, isFalse);
  });

  testWidgets('nested presences multiply', (tester) async {
    final outer = AnimationController(vsync: tester, value: .5);
    final inner = AnimationController(vsync: tester, value: .5);
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    late BuildContext leaf;
    await tester.pumpWidget(
      _host(
        LiquidPrismPresence(
          progress: outer,
          child: LiquidPrismPresence(
            progress: inner,
            child: Builder(
              builder: (context) {
                leaf = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(LiquidPrismPresence.of(leaf), .25);
    outer.value = 1;
    await tester.pump();
    expect(LiquidPrismPresence.of(leaf), .5);
  });

  test('theme transition style merges field by field', () {
    const spring = GlassSpring(response: Duration(milliseconds: 600));
    final merged =
        const LiquidPrismThemeData(
          transition: GlassTransitionStyle(enterSpring: spring, contentBlur: 4),
        ).merge(
          const LiquidPrismThemeData(
            transition: GlassTransitionStyle(contentBlur: 0),
          ),
        );
    expect(merged.transition!.enterSpring, spring);
    expect(merged.transition!.contentBlur, 0);
  });
}
