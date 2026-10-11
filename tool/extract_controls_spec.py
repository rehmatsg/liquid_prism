#!/usr/bin/env python3
"""Compact native control captures without deriving constants from pixels.

Usage: python3 tool/extract_controls_spec.py _research/control_specs/raw
Raw directories: specs/ (UIView/runtime), layers/ (CALayer), motion/ (display-link).
"""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
output = Path(__file__).resolve().parents[1] / 'doc/native_controls_spec.json'

def read(folder, name):
    return json.loads((root / folder / name).read_text())

start = read('specs', 'slider-dark-model-start.json')
held_names = []
for index, prefix in enumerate(['switch-dark', 'slider-dark', 'segments-dark']):
    candidates = sorted(root.joinpath('specs').glob(f'{prefix}-contact-*.json'))
    held_names.append(next(p.name for p in candidates
        if [v for v in json.loads(p.read_text())['views']
            if v['class'] == '_UILiquidLensView'][index]['nativeSpecs']['lifted']))
profiles = {}
for index, (name, held_name) in enumerate(zip(['switch', 'slider', 'segmented'], held_names)):
    held = read('specs', held_name)
    resting_lens = [v for v in start['views'] if v['class'] == '_UILiquidLensView'][index]
    held_lens = [v for v in held['views'] if v['class'] == '_UILiquidLensView'][index]
    layer_capture = read('layers', held_name)
    # Layer/view path ordering differs, so select the active lens by its held bounds.
    active = next(l for l in layer_capture['layers']
                  if l['delegateClass'] == '_UILiquidLensView'
                  and l['bounds'] == held_lens['bounds'])
    material = [{k: layer[k] for k in ['class', 'name', 'frame', 'filters', 'effect', 'sdfProperties'] if k in layer}
                for layer in layer_capture['layers']
                if layer['path'].startswith(active['path'] + '/')
                and any(k in layer for k in ['filters', 'effect', 'sdfProperties'])]
    shadows = [{k: l[k] for k in ['frame', 'shadowOpacity', 'shadowRadius', 'shadowOffset', 'shadowColor']} for l in layer_capture['layers'] if l['path'].startswith(active['path']+'/') and l['shadowOpacity'] > 0]
    profiles[name] = {
        'layerShadows': shadows,
        'restingLens': {k: resting_lens[k] for k in ['bounds', 'frame', 'transform']},
        'heldLens': {k: held_lens[k] for k in ['bounds', 'frame', 'transform']},
        'lensSpec': held_lens['nativeSpecs']['spec'],
        'flexVariant': held_lens['nativeSpecs']['flexInteraction']['properties']['preferredVariant'],
        'materialLayers': material,
    }

color_names = [next(name for name in [f'native-colors-{mode}-model-start.json', fallback] if (root/'specs'/name).exists()) for mode, fallback in [('light', 'controls-light-model-start.json'), ('dark', 'switch-dark-model-start.json')]]
color_files = [read('specs', name) for name in color_names]
colors = {}
for mode, capture, filename in zip(['light', 'dark'], color_files, color_names):
    colors[mode] = {'segmentedTrackCenterPremultipliedRGBA': next(v['imageCenterRGBA'] for v in capture['views']
                     if 'imageCenterRGBA' in v and v['frame'] == '{{0, 0}, {100, 32}}')}
    layers = read('layers', filename)['layers']
    slider = next(l for l in layers if l['delegateClass'] == 'UIKit._UISliderGlassVisualElement')
    colors[mode]['sliderTrackLayers'] = [{k: l[k] for k in ['frame', 'backgroundColor']}
        for l in layers if l['path'].startswith(slider['path']+'/1/')]

calls = []
seen = set()
for file in root.joinpath('specs').glob('*.json'):
    for c in json.loads(file.read_text())['timingCalls']:
        owner = next((s.split(' -[')[-1].split(' + ')[0] for s in c['stack']
                      if any(k in s for k in ['_transitionKnob', '_updateSelectionToSegment',
                                              '_UIFluidSliderInteraction', '_UILiquidLensView'])), None)
        if owner:
            key = (owner, json.dumps(c['arguments'], sort_keys=True))
            if key not in seen:
                seen.add(key)
                calls.append({'owner': owner, 'method': c['method'], 'arguments': c['arguments']})

lens = start['rootSpecs']['UIKit._UIFlexInteractionSettingsDomain']['properties']
sources = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
           for folder in ['specs', 'layers'] for p in root.joinpath(folder).glob('*.json')}
result = {
    'provenance': {'os': read('layers', held_names[0])['os'],
        'runtimeBuild': '24A5370g', 'sdkBuild': '24A430',
        'device': 'iPhone 17', 'screen': start['screen'],
        'method': 'UIView/CALayer model and presentation state, runtime settings, intercepted spring constructors',
        'rawSHA256': sources},
    'profiles': profiles, 'colors': colors,
    'switchSettings': color_files[1]['rootSpecs']['_UISwitchSettings'],
    'fluidSliderSettings': start['rootSpecs']['_UIFluidSliderSettingsDomain'],
    'smallLoupeFlex': lens['interactionSpec']['properties']['smallLoupe'],
    'springConstructors': calls,
    'typography': [{k: v[k] for k in ['text', 'font', 'bounds', 'frame']} for v in start['views']
                   if v['class'] == 'UISegmentLabel'][:3],
    'limitations': ['Private Core Animation glass filter kernels and SDF operators are not reproduced exactly.',
        'Velocity-to-flex coupling is approximated; the scale spring settings are directly extracted.',
        'Captured native font grade G3 is not exposed by Flutter system fonts.',
        'Only default phone controls, light/dark, continuous slider and three text segments were captured.']
}
output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(f'Wrote {output} ({output.stat().st_size} bytes)')
