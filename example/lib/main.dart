import 'package:flutter/cupertino.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'showcase/app.dart';
export 'showcase/app.dart' show LiquidPrismExample;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidPrism.preload();
  runApp(const LiquidPrismExample());
}
