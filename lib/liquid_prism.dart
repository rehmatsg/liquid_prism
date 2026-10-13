/// Liquid glass surfaces, buttons, themes, and interactive tab bars for Flutter.
///
/// Call [LiquidPrism.preload] after initializing Flutter bindings, then place
/// [LiquidPrismTheme] above your glass widgets to share material and color defaults.
library;

export 'src/button.dart' show GlassButtonStyle, LiquidPrismButton;
export 'src/chrome_layout.dart' show GlassChromePlacement, LiquidPrismScaffold;
export 'src/sidebar.dart' show GlassTabBarPlacement;
export 'src/system_chrome.dart'
    show
        GlassReservedRegion,
        GlassSizeClass,
        GlassSystemChrome,
        GlassVerticalBarBehavior,
        LiquidPrismSystemChrome;
export 'src/edge_fade.dart' show GlassEdge, GlassEdgeFade, GlassFadeCurve;
export 'src/glass.dart'
    show GlassEdgeBlur, LiquidPrism, LiquidPrismEdgeBlur, LiquidPrismGroup;
export 'src/scroll_edge.dart'
    show
        GlassScrollEdgeStyle,
        GlassScrollEdgeVariant,
        LiquidPrismScrollEdge,
        LiquidPrismScrollFade;
export 'src/glass_transition.dart'
    show
        GlassTransition,
        GlassTransitionStyle,
        LiquidPrismPresence,
        LiquidPrismVisibility;
export 'src/material.dart' show Glass, GlassVariant, GlassShape;
export 'src/motion.dart' show GlassMotion, GlassSpring, GlassControlMotion;
export 'src/appearance.dart'
    show
        GlassLensStyle,
        GlassButtonAppearance,
        GlassSwitchStyle,
        GlassSliderStyle,
        GlassSegmentedStyle,
        GlassToolbarStyle,
        GlassSearchStyle;
export 'src/pressable.dart' show LiquidPrismPressable;
export 'src/selection.dart' show LiquidPrismSelection;
export 'src/style.dart' show LiquidPrismStyle;
export 'src/tab_bar.dart' show LiquidPrismTab, LiquidPrismTabBar;
export 'src/tab_bar_style.dart' show GlassTabBarStyle, GlassTabLabelBehavior;
export 'src/theme.dart'
    show LiquidPrismTheme, LiquidPrismThemeData, GlassColors;

export "src/switch.dart" show LiquidPrismSwitch;
export "src/slider.dart" show LiquidPrismSlider;
export "src/segmented_control.dart" show LiquidPrismSegmentedControl;

export 'src/toolbar.dart'
    show
        GlassToolbarSize,
        GlassToolbarItem,
        LiquidPrismBackButton,
        LiquidPrismToolbar,
        LiquidPrismToolbarGroup;
export 'src/search_field.dart'
    show
        GlassSearchFieldBuilder,
        GlassSearchSuffixBuilder,
        LiquidPrismSearchField;

export 'liquid_menu.dart';
