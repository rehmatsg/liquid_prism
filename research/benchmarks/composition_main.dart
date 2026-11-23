import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prism.initialize();
  runApp(const CompositionExample());
}

/// Run with `flutter run -t benchmarks/composition_main.dart` from `research/`.
class CompositionExample extends StatefulWidget {
  const CompositionExample({super.key});
  @override
  State<CompositionExample> createState() => CompositionExampleState();
}

class CompositionExampleState extends State<CompositionExample> {
  bool dark = false, rtl = false, fill = false;
  double textScale = 1;
  PrismTabBarPlacement dock = PrismTabBarPlacement.automatic;
  PrismControlSize size = PrismControlSize.large;
  PrismTitleAlignment titleAlignment = PrismTitleAlignment.center;
  int tab = 0, saves = 0, favorites = 0;
  final editorFocus = FocusNode();
  final scroll = ScrollController();

  void configure({
    bool? dark,
    bool? rtl,
    bool? fill,
    double? textScale,
    PrismTabBarPlacement? dock,
    PrismControlSize? size,
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
    final colors = PrismColors(brightness);
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.blue,
      ),
      home: PrismTheme(
        brightness: brightness,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: PrismScaffold(
                backgroundColor: dark
                    ? const Color(0xFF000000)
                    : const Color(0xFFF2F2F7),
                title: const Text('Composition'),
                navigationBarStyle: PrismNavigationBarStyle(
                  titleAlignment: titleAlignment,
                ),
                toolbar: [
                  PrismToolbarItem(
                    placement: PrismToolbarPlacement.topLeading,
                    icon: const Icon(CupertinoIcons.xmark),
                    label: 'Reset',
                    onPressed: () => setState(() {
                      saves = 0;
                      favorites = 0;
                    }),
                  ),
                  PrismToolbarItem(
                    label: 'Save',
                    onPressed: () => setState(() => saves++),
                  ),
                  PrismToolbarGroup(
                    placement: PrismToolbarPlacement.bottomLeading,
                    items: [
                      PrismToolbarItem(
                        icon: const Icon(CupertinoIcons.arrow_uturn_left),
                        label: 'Undo',
                        onPressed: () => setState(() => saves = 0),
                      ),
                      PrismToolbarItem(
                        icon: const Icon(CupertinoIcons.arrow_uturn_right),
                        label: 'Redo',
                        onPressed: () => setState(() => saves++),
                      ),
                    ],
                  ),
                  PrismToolbarItem.custom(
                    placement: PrismToolbarPlacement.bottomTrailing,
                    child: PrismButton.icon(
                      icon: const Icon(CupertinoIcons.heart),
                      label: 'Favorite',
                      key: const ValueKey('composition-favorite'),
                      onPressed: () => setState(() => favorites++),
                    ),
                  ),
                ],
                tabBarPlacement: dock,
                style: const PrismScaffoldStyle(
                  tabBarMaxWidth: 520,
                  bottomBarMargin: EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                ),
                tabBar: PrismTabBar(
                  key: const ValueKey('composition-tabs'),
                  selectedIndex: tab,
                  onSelected: (value) => setState(() => tab = value),
                  style: PrismTabBarStyle(
                    sizing: fill
                        ? PrismTabBarSizing.fill
                        : PrismTabBarSizing.compact,
                  ),
                  tabs: const [
                    PrismTab(
                      icon: Icon(CupertinoIcons.square_grid_2x2),
                      label: 'Layout',
                    ),
                    PrismTab(
                      icon: Icon(CupertinoIcons.paintbrush),
                      label: 'Style',
                    ),
                    PrismTab(icon: Icon(CupertinoIcons.doc), label: 'Content'),
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
                          PrismTabBarPlacement.values,
                          dock,
                          (value) => configure(dock: value),
                        ),
                        _choices(
                          'Title alignment',
                          PrismTitleAlignment.values,
                          titleAlignment,
                          (value) => setState(() => titleAlignment = value),
                        ),
                        _choices(
                          'Button size',
                          PrismControlSize.values,
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
                        PrismButton(
                          label: 'Upload',
                          icon: const Icon(CupertinoIcons.cloud_upload),
                          onPressed: () => setState(() => saves++),
                          variant: PrismButtonVariant.prominent,
                          style: PrismButtonStyle(
                            size: size,
                            sizing: PrismButtonSizing.fill,
                            labelPlacement: PrismLabelPlacement.trailing,
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
            PrismSwitch(value: value, label: label, onChanged: onChanged),
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
              PrismButton(
                label: value.name,
                size: PrismControlSize.small,
                variant: value == current
                    ? PrismButtonVariant.prominent
                    : PrismButtonVariant.regular,
                onPressed: () => onChanged(value),
              ),
          ],
        ),
      ],
    ),
  );
}
