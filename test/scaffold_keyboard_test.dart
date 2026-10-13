import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_prism/liquid_prism.dart';

void main() {
  testWidgets('keyboard inset is consumed once, with opt-out for descendants', (
    tester,
  ) async {
    Future<void> mount(bool resize) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            viewInsets: EdgeInsets.only(bottom: 200),
          ),
          child: LiquidPrismScaffold(
            resizeToAvoidBottomInset: resize,
            body: Builder(
              builder: (context) => Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      const TextField(),
                      Expanded(child: Container(key: const Key('remaining'))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await mount(true);
    final bodyContext = tester.element(find.byType(Scaffold).last);
    expect(MediaQuery.viewInsetsOf(bodyContext).bottom, 0);
    expect(MediaQuery.paddingOf(bodyContext).bottom, 200);
    final once = tester.getRect(find.byKey(const Key('remaining'))).bottom;
    expect(once, 400);
    await mount(false);
    expect(
      MediaQuery.viewInsetsOf(tester.element(find.byType(Scaffold).last))
          .bottom,
      200,
    );
    expect(tester.getRect(find.byKey(const Key('remaining'))).bottom, once);
  });
}
