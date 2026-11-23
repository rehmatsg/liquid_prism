import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';
import 'package:liquid_prism/src/navigation/scaffold/prism_scaffold.dart'
    show topEdgeInset;

void main() {
  test('only glass titles and full toolbars extend the top edge', () {
    const style = PrismScrollEdgeStyle();
    double inset(Widget? title, {bool bareRows = false}) =>
        topEdgeInset(title, bareRows: bareRows, style: style);
    final item = PrismToolbarItem(label: 'Edit', onPressed: () {});
    final toolbar = PrismToolbar(
      content: [
        PrismToolbarGroup(items: [item]),
      ],
    );

    expect(
      inset(const PrismTitle(child: Text('Inbox'))),
      PrismScrollEdgeStyle.defaultExtension,
    );
    expect(inset(toolbar), PrismScrollEdgeStyle.defaultExtension);
    expect(inset(toolbar, bareRows: true), 0);
    expect(inset(PrismToolbar.group(items: [item])), 0);
    expect(inset(const Text('Inbox')), 0);
    expect(inset(null), 0);
  });
}
