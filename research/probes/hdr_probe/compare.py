# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow"]
# ///
"""Compare the dark contour in a paired devicectl SDR capture, not HDR luminance.

uv run tool/hdr_probe/compare.py IMAGE.png --log RUN.log
"""
import argparse
import json
from PIL import Image

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("image")
p.add_argument("--log", required=True)
p.add_argument("--scale", type=float, help="override DPR for older probe logs")
args = p.parse_args()
lines = open(args.log).read().splitlines()
rects = next(json.loads(s.split("HDR_PROBE native reference rects ")[1])
             for s in lines if "HDR_PROBE native reference rects " in s)
info = next(json.loads(s.split("HDR_PROBE native ")[1])
            for s in lines if "HDR_PROBE native {" in s)
scale = args.scale or info["scale"]
flutter_rects = next((json.loads(s.split("HDR_PROBE flutter rects ")[1])
                      for s in lines if "HDR_PROBE flutter rects " in s), None)
image = Image.open(args.image).convert("RGB")
report = []
for index, (x, y, w, h, *_) in enumerate(rects):
    profiles = {}
    for edge in ["side", "top", "bottom"]:
        rows = []
        flutter = flutter_rects[index] if flutter_rects else [x, y-200, w, h]
        for rx, ry, rw, rh in [flutter, [x,y,w,h]]:
            left, top = round(rx * scale), round(ry * scale)
            width, height = round(rw * scale), round(rh * scale)
            samples = []
            for offset in range(-4, 5):
                point = ((left + offset, top + height // 2) if edge == "side" else
                         (left + width // 2, top + offset + (height if edge == "bottom" else 0)))
                samples.append(image.getpixel(point)[0])
            rows.append(samples)
        # Only the two dark contour pixels: exclude the separately calibrated
        # exterior shadow and the HDR band clipped by the PNG capture.
        band = [4, 5] if edge == "bottom" else [2, 3]
        profiles[edge] = {"flutter": rows[0], "native": rows[1],
                          "bandMAE": sum(abs(rows[0][i]-rows[1][i]) for i in band) / 2}
    report.append({"shape": index, "profiles": profiles})
print(json.dumps(report, indent=2))
