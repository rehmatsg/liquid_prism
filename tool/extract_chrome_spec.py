#!/usr/bin/env python3
"""Compact direct UIView/CALayer toolbar and search measurements."""
import hashlib
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
out = Path(__file__).resolve().parents[1] / 'doc/native_chrome_spec.json'
used = set()


def read(folder, name):
    path = root / folder / f'{name}.json'
    used.add(path)
    return json.loads(path.read_text())


def numbers(value):
    return [float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', value)]


def geometry(layer):
    keys = ['path', 'delegateClass', 'bounds', 'windowFrame', 'transform',
            'accessibilityIdentifier', 'text', 'font', 'textColor', 'tintColor',
            'imageSize', 'textRect', 'editingRect', 'cornerRadius', 'cornerCurve']
    return {key: layer[key] for key in keys if key in layer}


profiles = {}
for mode in ['light', 'dark']:
    for component, states in [('toolbar', ['rest']),
                              ('search', ['rest', 'focused', 'filled'])]:
        for state in states:
            name = f'chrome-{mode}-{component}-{state}'
            layers = read('layers', name)['layers']
            # Restrict search extraction to its navigation hierarchy, excluding
            # detached/accessory keyboard copies and system keyboard windows.
            surfaces = [layer for layer in layers
                        if 'UIPlatformGlassInteractionView' in layer['delegateClass']
                        and layer.get('windowFrame') and not layer['hidden']]
            prefix = 'window0/0/0/0/0/0/'
            content = [geometry(layer) for layer in layers
                       if layer['path'].startswith(prefix)
                       and (layer['delegateClass'] in ['_UIButtonBarButton',
                            'UISearchBarTextField', 'UISearchBarTextFieldLabel']
                            or (layer['delegateClass'] == 'UIImageView'
                                and layer.get('accessibilityIdentifier')
                                and not layer['path'].endswith('/0')))]
            filters = [f for layer in layers for f in layer.get('filters', [])
                       if f['name'] == 'glassBackground']
            profiles[f'{mode}-{component}-{state}'] = {
                'surfaces': [geometry(layer) for layer in surfaces],
                'content': content,
                'glassBackgroundInputs': [f['inputs'] for f in filters],
            }

holds = {}
for path in sorted((root / 'layers').glob('chrome-dark-toolbar-contact-*.json')):
    used.add(path)
    for layer in json.loads(path.read_text())['layers']:
        if 'UIPlatformGlassInteractionView' not in layer['delegateClass']:
            continue
        width, height = numbers(layer['bounds'])[-2:]
        scale = layer['transform'][0]
        key = f'{width:g}x{height:g}'
        if scale > holds.get(key, {}).get('scale', 1):
            holds[key] = {'bounds': [width, height], 'scale': scale,
                          'heldSize': [width * scale, height * scale],
                          'capture': path.name}

timing = []
for mode in ['dark', 'light']:
    name = f'chrome-{mode}-search-focused'
    for call in read('specs', name)['timingCalls']:
        owners = [s.split(' +')[0] for s in call['stack'] if 'UISearch' in s]
        if owners:
            entry = {'method': call['method'], 'arguments': call['arguments'],
                     'owner': owners[0]}
            if entry not in timing:
                timing.append(entry)

result = {
    'reference': {'device': 'iPhone 17', 'runtime': 'iOS 27.0 (24A5370g)',
                  'screenPoints': [402, 874], 'scale': 3},
    'profiles': profiles, 'toolbarHeldGeometry': holds,
    'searchTimingConstructors': timing,
    'rawSHA256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(used)},
    'limitations': [
        'Private glass/vibrancy kernels and localized highlights remain approximations.',
        'Toolbar press/release timing reuses fitted button springs; the 16-point width gain is directly measured.',
        'Search focus timing is fitted; intercepted keyboard timing is not proof of every field property binding.',
        'Native symbol dimensions are stored; Flutter CupertinoIcons use different glyph assets.',
        'Responsive, RTL and enlarged-text behavior are adaptive fallbacks, not separately measured native layouts.',
    ],
}
out.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(f'Wrote {out} ({out.stat().st_size} bytes)')
