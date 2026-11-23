#!/usr/bin/env python3
"""Compare matched native/defaults captures along the regular capsule's top rim.

Run with a native capture directory and one or more Flutter capture directories.
Images must be from tool/native_defaults and example/test_driver/native_defaults.
"""
import argparse
from pathlib import Path
from PIL import Image


def profile(path):
    image = Image.open(path).convert('RGB')
    scale = image.width / 402
    # The first regular capsule is centered at (105, 140), height 48.
    # Stop above the label; include the white rim and the adjacent shaded face.
    return [image.getpixel((round(105 * scale), round(y * scale)))
            for y in (116, 117, 118, 119, 120, 122, 124, 126, 128)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('native', type=Path)
    parser.add_argument('flutter', type=Path, nargs='+')
    parser.add_argument('--max-mean-error', type=float, default=1.0)
    args = parser.parse_args()
    for folder in args.flutter:
        errors = []
        for reference in sorted(args.native.glob('*-light-*-native.png')):
            actual = folder / reference.name.replace('-native.png', '-flutter.png')
            target, observed = profile(reference), profile(actual)
            differences = [abs(a - b) for p, q in zip(target, observed)
                           for a, b in zip(p, q)]
            errors.extend(differences)
            print(f'{folder.name}/{reference.stem}: MAE={sum(differences)/len(differences):.3f}')
        if not errors:
            raise SystemExit('No matching light captures')
        mean = sum(errors) / len(errors)
        print(f'{folder.name}: mean channel error={mean:.3f}, max={max(errors)}')
        if mean > args.max_mean_error:
            raise SystemExit(f'Rim profile exceeds {args.max_mean_error} channel levels')


if __name__ == '__main__':
    main()
