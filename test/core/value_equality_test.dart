import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/primitives.dart';

void main() {
  test(
    'immutable core, style, theme, and menu models implement value equality',
    () {
      expect(
        PrismGlass.clear.tint(const Color(0xFF112233)).interactive(),
        equals(PrismGlass.clear.tint(const Color(0xFF112233)).interactive()),
      );
      expect(
        const PrismShape.rect(cornerRadius: 18),
        equals(const PrismShape.rect(cornerRadius: 18)),
      );
      expect(
        const PrismOptics(frost: 4, refraction: 20),
        equals(const PrismOptics(frost: 4, refraction: 20)),
      );
      expect(
        const PrismOptics(frost: 4).hashCode,
        equals(const PrismOptics(frost: 4).hashCode),
      );
      expect(
        const PrismSpring(response: Duration(milliseconds: 250), bounce: 0.2),
        equals(
          const PrismSpring(response: Duration(milliseconds: 250), bounce: 0.2),
        ),
      );
      expect(
        const PrismSpring.physical(
          SpringDescription(mass: 1, stiffness: 200, damping: 24),
        ),
        equals(
          const PrismSpring.physical(
            SpringDescription(mass: 1, stiffness: 200, damping: 24),
          ),
        ),
      );
      expect(
        const PrismMotion(pressScale: 1.08),
        equals(const PrismMotion(pressScale: 1.08)),
      );
      expect(
        const PrismControlMotion(maxStretch: 0.08),
        equals(const PrismControlMotion(maxStretch: 0.08)),
      );
      expect(
        const PrismLensStyle(shadowOpacity: 0.1, rimWidth: 6),
        equals(const PrismLensStyle(shadowOpacity: 0.1, rimWidth: 6)),
      );
      expect(
        const PrismButtonStyle(
          variant: PrismButtonVariant.prominent,
          padding: EdgeInsets.all(12),
        ),
        equals(
          const PrismButtonStyle(
            variant: PrismButtonVariant.prominent,
            padding: EdgeInsets.all(12),
          ),
        ),
      );
      expect(
        const PrismSwitchStyle(scale: 1.2, haptics: false),
        equals(const PrismSwitchStyle(scale: 1.2, haptics: false)),
      );
      expect(
        const PrismSliderStyle(trackHeight: 8, heldScale: 1.5),
        equals(const PrismSliderStyle(trackHeight: 8, heldScale: 1.5)),
      );
      expect(
        const PrismSegmentedStyle(trackHeight: 36),
        equals(const PrismSegmentedStyle(trackHeight: 36)),
      );
      expect(
        const PrismSearchStyle(height: 50, showCancelButton: false),
        equals(const PrismSearchStyle(height: 50, showCancelButton: false)),
      );
      expect(
        const PrismTabBarStyle(height: 60, sizing: PrismTabBarSizing.fill),
        equals(
          const PrismTabBarStyle(height: 60, sizing: PrismTabBarSizing.fill),
        ),
      );
      expect(
        const PrismToolbarStyle(spacing: 12, groupSpacing: 10),
        equals(const PrismToolbarStyle(spacing: 12, groupSpacing: 10)),
      );
      expect(
        const PrismNavigationBarStyle(
          titleDisplayMode: PrismTitleDisplayMode.inline,
          minimizationSafeArea: PrismMinimizationSafeArea.disabled,
        ),
        equals(
          const PrismNavigationBarStyle(
            titleDisplayMode: PrismTitleDisplayMode.inline,
            minimizationSafeArea: PrismMinimizationSafeArea.disabled,
          ),
        ),
      );
      expect(
        const PrismScaffoldStyle(tabBarMaxWidth: 420),
        equals(const PrismScaffoldStyle(tabBarMaxWidth: 420)),
      );
      expect(
        const PrismTitleStyle(avatarSize: 60),
        equals(const PrismTitleStyle(avatarSize: 60)),
      );
      expect(
        const PrismTransitionStyle(contentBlur: 2),
        equals(const PrismTransitionStyle(contentBlur: 2)),
      );
      expect(
        const PrismScrollEdgeStyle(sigma: 4, hairline: true),
        equals(const PrismScrollEdgeStyle(sigma: 4, hairline: true)),
      );
      expect(const PrismBadge.count(42), equals(const PrismBadge.count(42)));
      expect(const PrismColors(Brightness.dark), equals(PrismColors.dark));
      expect(
        const PrismMenu(
          title: 'Actions',
          children: [PrismMenuAction<int>(title: 'Copy', value: 1)],
        ),
        equals(
          const PrismMenu(
            title: 'Actions',
            children: [PrismMenuAction<int>(title: 'Copy', value: 1)],
          ),
        ),
      );

      const a = PrismThemeData(
        tint: Color(0xFF007AFF),
        button: PrismButtonStyle(blur: 4),
        slider: PrismSliderStyle(trackHeight: 8),
      );
      const b = PrismThemeData(
        tint: Color(0xFF007AFF),
        button: PrismButtonStyle(blur: 4),
        slider: PrismSliderStyle(trackHeight: 8),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.merge(const PrismThemeData()), equals(a));
    },
  );

  testWidgets('PrismTheme does not rebuild descendants when data is equal', (
    tester,
  ) async {
    var builds = 0;
    final trigger = ValueNotifier<int>(0);
    addTearDown(trigger.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: trigger,
          builder: (context, value, child) => PrismTheme(
            data: const PrismThemeData(
              tint: Color(0xFF6155F5),
              button: PrismButtonStyle(blur: 3),
            ),
            child: child!,
          ),
          child: Builder(
            builder: (context) {
              PrismTheme.of(context);
              builds++;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(builds, 1);
    trigger.value = 1;
    await tester.pump();
    expect(builds, 1);
  });
}
