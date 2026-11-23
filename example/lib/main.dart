import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_prism/liquid_prism.dart';

import 'package:liquid_prism_example/showcase/app.dart';

export 'showcase/app.dart' show PrismExample;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prism.initialize();
  runApp(const PrismExample());
}
