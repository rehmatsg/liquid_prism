import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(const CompositionExample());
}

/// Run with `flutter run -t lib/composition_main.dart`.
class CompositionExample extends StatefulWidget {
  const CompositionExample({super.key});
  @override
  State<CompositionExample> createState() => CompositionExampleState();
}

class CompositionExampleState extends State<CompositionExample> {
  bool dark = false, rtl = false, fill = false;
  double textScale = 1;
  GlassTabBarPlacement dock = GlassTabBarPlacement.automatic;
  GlassControlSize size = GlassControlSize.large;
  GlassTitleAlignment titleAlignment = GlassTitleAlignment.center;
  int tab = 0, saves = 0, favorites = 0;
  final editorFocus = FocusNode();
  final scroll = ScrollController();

  void configure({
    bool? dark,
    bool? rtl,
    bool? fill,
    double? textScale,
    GlassTabBarPlacement? dock,
    GlassControlSize? size,
  }) => setState(() {
    this.dark = dark ?? this.dark;
    this.rtl = rtl ?? this.rtl;
    this.fill = fill ?? this.fill;
    this.textScale = textScale ?? this.textScale;
    this.dock = dock ?? this.dock;
    this.size = size ?? this.size;
  });

  @override
  void dispose() {
    editorFocus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = dark ? Brightness.dark : Brightness.light;
    final colors = GlassColors(brightness);
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.blue,
      ),
      home: LiquidPrismTheme(
        brightness: brightness,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: LiquidPrismScaffold(
                backgroundColor: dark
                    ? const Color(0xFF000000)
                    : const Color(0xFFF2F2F7),
                title: const Text('Composition'),
                navigationBarStyle: GlassNavigationBarStyle(
                  titleAlignment: titleAlignment,
                ),
                toolbar: [
                  GlassToolbarItem(
                    placement: GlassToolbarPlacement.topLeading,
                    icon: const Icon(CupertinoIcons.xmark),
                    label: 'Reset',
                    onPressed: () => setState(() {
                      saves = 0;
                      favorites = 0;
                    }),
                  ),
                  GlassToolbarItem(
                    label: 'Save',
                    onPressed: () => setState(() => saves++),
                  ),
                  GlassToolbarGroup(
                    placement: GlassToolbarPlacement.bottomLeading,
                    items: [
                      GlassToolbarItem(
                        icon: const Icon(CupertinoIcons.arrow_uturn_left),
                        label: 'Undo',
                        onPressed: () => setState(() => saves = 0),
                      ),
                      GlassToolbarItem(
                        icon: const Icon(CupertinoIcons.arrow_uturn_right),
                        label: 'Redo',
                        onPressed: () => setState(() => saves++),
                      ),
                    ],
                  ),
                  GlassToolbarItem.custom(
                    placement: GlassToolbarPlacement.bottomTrailing,
                    child: LiquidPrismButton.icon(
                      icon: const Icon(CupertinoIcons.heart),
                      label: 'Favorite',
                      key: const ValueKey('composition-favorite'),
                      onPressed: () => setState(() => favorites++),
                    ),
                  ),
                ],
                tabBarPlacement: dock,
                style: const GlassScaffoldStyle(
                  tabBarMaxWidth: 520,
                  bottomBarMargin: EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                ),
                tabBar: LiquidPrismTabBar(
                  key: const ValueKey('composition-tabs'),
                  selectedIndex: tab,
                  onSelected: (value) => setState(() => tab = value),
                  style: GlassTabBarStyle(
                    sizing: fill
                        ? GlassTabBarSizing.fill
                        : GlassTabBarSizing.compact,
                  ),
                  tabs: const [
                    LiquidPrismTab(
                      icon: Icon(CupertinoIcons.square_grid_2x2),
                      label: 'Layout',
                    ),
                    LiquidPrismTab(
                      icon: Icon(CupertinoIcons.paintbrush),
                      label: 'Style',
                    ),
                    LiquidPrismTab(
                      icon: Icon(CupertinoIcons.doc),
                      label: 'Content',
                    ),
                  ],
                ),
                scrollController: scroll,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          'Your layout. Native glass.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: colors.label,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saved $saves · Favorites $favorites',
                          key: const ValueKey('composition-status'),
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                        const SizedBox(height: 24),
                        _choices(
                          'Tab dock',
                          GlassTabBarPlacement.values,
                          dock,
                          (value) => configure(dock: value),
                        ),
                        _choices(
                          'Title alignment',
                          GlassTitleAlignment.values,
                          titleAlignment,
                          (value) => setState(() => titleAlignment = value),
                        ),
                        _choices(
                          'Button size',
                          GlassControlSize.values,
                          size,
                          (value) => configure(size: value),
                        ),
                        _toggle(
                          'Dark appearance',
                          dark,
                          (value) => configure(dark: value),
                        ),
                        _toggle(
                          'Right to left',
                          rtl,
                          (value) => configure(rtl: value),
                        ),
                        _toggle(
                          'Fill tab dock',
                          fill,
                          (value) => configure(fill: value),
                        ),
                        const SizedBox(height: 20),
                        LiquidPrismButton(
                          label: 'Upload',
                          icon: const Icon(CupertinoIcons.cloud_upload),
                          onPressed: () => setState(() => saves++),
                          variant: GlassButtonVariant.prominent,
                          style: GlassButtonStyle(
                            size: size,
                            sizing: GlassButtonSizing.fill,
                            labelPlacement: GlassLabelPlacement.trailing,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoTextField(
                          key: const ValueKey('composition-editor'),
                          focusNode: editorFocus,
                          placeholder:
                              'Edit a title to test keyboard avoidance',
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => editorFocus.unfocus(),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'The bottom controls use separate leading and trailing regions. '
                          'Tab placement, alignment, spacing and sizing are independent of the glass material.',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            LiquidPrismSwitch(value: value, label: label, onChanged: onChanged),
          ],
        ),
      );

  Widget _choices<T extends Enum>(
    String label,
    List<T> values,
    T current,
    ValueChanged<T> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in values)
              LiquidPrismButton(
                label: value.name,
                size: GlassControlSize.small,
                variant: value == current
                    ? GlassButtonVariant.prominent
                    : GlassButtonVariant.regular,
                onPressed: () => onChanged(value),
              ),
          ],
        ),
      ],
    ),
  );
}
