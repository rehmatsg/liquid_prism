#!/usr/bin/env python3
"""Compact live native sheet probe results. Raw capture directories stay local."""
import hashlib
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
out = Path(__file__).resolve().parents[1] / 'doc/native_sheet_spec.json'
profiles = {}
springs = {}
for mode in ['light', 'dark']:
    for detent in ['medium', 'large']:
        name = f'sheet-{mode}-{detent}-settled.json'
        layer_file = root/'layers'/name
        data = json.loads(layer_file.read_text())
        spec = json.loads((root/'specs'/name).read_text())
        sheet = next(l for l in data['layers'] if l['path'] == 'window0/1/1')
        dim = next(l for l in data['layers'] if l['delegateClass'] == 'UIDimmingView'
                   and l['backgroundColor']['components'][-1] > 0)
        grabber = next(l for l in data['layers'] if l['delegateClass'] == '_UIGrabber')
        material = [f for l in data['layers'] if l['delegateClass'] == 'UIKit.UISDFBackdropView'
                    for f in l.get('filters', [])]
        view = next(v for v in spec['views'] if v['path'] == sheet['path'])
        profiles[f'{mode}-{detent}'] = {
            'bounds': sheet['bounds'], 'windowFrame': sheet['windowFrame'],
            'transform': sheet['transform'], 'background': sheet['backgroundColor'],
            'dimming': dim['backgroundColor'], 'materialFilters': material,
            'grabber': {k: grabber[k] for k in ['bounds','frame','windowFrame']},
            'preferredCornerRadii': view.get('nativeSpecs',{}).get('preferredCornerRadii'),
            'environmentCornerRadii': view.get('nativeSpecs',{}).get('environmentCornerRadii'),
            'cornerCurve': sheet['cornerCurve'],
        }
        for c in spec['timingCalls']:
            stack = [s for s in c['stack'] if 'UIKit' in s and 'UISheetPresentationController' in s]
            if stack:
                key = (c['method'], json.dumps(c['arguments'], sort_keys=True))
                springs[str(key)] = {'method':c['method'], 'arguments':c['arguments'], 'owner':stack[0].split(' +')[0]}
result = {
    'reference': {'device':'iPhone 17','runtime':'iOS 27.0 (24A5370g)',
                  'screenPoints':[402,874],'scale':3,'safeAreaTop':62,'safeAreaBottom':34},
    'profiles':profiles,'springConstructors':list(springs.values()),
    'rawSHA256':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
                 for folder in ['layers','specs'] for p in (root/folder).glob('*settled.json')},
    'limitations':['Responsive detent formula is derived from the reference frame, not recovered UIKit layout code.',
                  'Private glass kernels, lower-corner optics, shadows, entry/exit and scroll snap physics remain approximations.',
                  'The corner-radii getter was directly captured in dark mode; light-mode frames and material inputs were captured independently.']
}
out.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
print(f'Wrote {out} ({out.stat().st_size} bytes)')
