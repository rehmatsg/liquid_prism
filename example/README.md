# Liquid Prism example

A small app using only `package:liquid_prism/liquid_prism.dart` for glass controls.
It demonstrates system/shader rendering, material and theme changes, tinted surfaces, buttons, favorites,
optional tab labels, a draggable selection pill, and an iOS page transition with
swipe-back navigation. Tap **Open another page** to try it. Its background is drawn in
Dart and needs no external images.

```sh
flutter pub get
../tool/run_example.sh <device-id>
```

Use `flutter devices` to find an iOS simulator or Android device. A native iOS
plugin change requires a fresh build. Ordinary Dart changes support hot reload.
