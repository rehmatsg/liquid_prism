import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'chrome_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(
    const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(brightness: Brightness.dark),
      home: ChromeDemo(standalone: true),
    ),
  );
}
