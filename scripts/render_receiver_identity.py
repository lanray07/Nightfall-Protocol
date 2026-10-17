"""Render the app's code-drawn fractured receiver coil at required iOS icon sizes.

This is the same visual vocabulary as ReceiverIllustration, not a stock asset.
No screenshots or external artwork are used as inputs.
"""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / 'NightfallProtocol/Resources/Assets.xcassets/AppIcon.appiconset'


def render():
    image = Image.new('RGB', (2048, 2048), '#101b18')
    draw = ImageDraw.Draw(image)
    cx, cy, radius = 990, 1000, 700
    for ring in range(7):
        r = radius * (0.3 + ring * 0.115)
        draw.arc((cx-r, cy-r, cx+r, cy+r), 45 + ring * 4, 318 - ring * 3,
                 fill='#ddd2b5' if ring % 2 == 0 else '#526354', width=14 if ring == 6 else 7)
    for tick in range(48):
        angle = tick / 48 * math.tau
        r = radius * (1.03 if tick % 4 == 0 else 1.08)
        draw.line((cx+math.cos(angle)*r, cy+math.sin(angle)*r,
                   cx+math.cos(angle)*radius*1.14, cy+math.sin(angle)*radius*1.14),
                  fill='#b38a4f', width=7)
    wave = []
    for step in range(400):
        x = step / 399
        wave.append((2048*(0.07+x*0.86), cy+math.sin(x*43)*math.exp(-((x-0.55)*5)**2)*radius*0.72))
    draw.line(wave, fill='#c4dc91', width=14)
    draw.line((cx,cy,cx+radius*0.73,cy-radius*0.52), fill='#e68145', width=18)
    draw.ellipse((cx-26,cy-26,cx+26,cy+26), fill='#eee3c7')
    return image


if __name__ == '__main__':
    master = render()
    contents = json.loads((ICON / 'Contents.json').read_text(encoding='utf-8'))
    for asset in contents['images']:
        size = round(float(asset['size'].split('x')[0]) * float(asset['scale'].removesuffix('x')))
        master.resize((size, size), Image.Resampling.LANCZOS).save(ICON / asset['filename'])
    print('Rendered original receiver identity for', len(contents['images']), 'iOS icon slots.')
