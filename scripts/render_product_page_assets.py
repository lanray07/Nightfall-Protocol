"""Extend Nightfall's code-drawn receiver identity for App Store creative slots.

These are brand illustrations, not screenshots. No external art or fonts required.
"""
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'fastlane/creative-assets'


def render(width, height):
    # A quiet instrument face with station contours, echo traces and one live signal.
    yy, xx = np.mgrid[0:height, 0:width]
    distance = ((xx / width - .5) ** 2 * 2 + (yy / height - .48) ** 2)
    glow = np.exp(-distance * 7)
    pixels = np.stack([12 + glow * 12, 23 + glow * 17, 21 + glow * 11], axis=-1)
    im = Image.fromarray(pixels.astype('uint8'), 'RGB')
    d = ImageDraw.Draw(im)
    cx, cy = width / 2, height / 2
    r = min(width * .205, height * .36)
    # Fine geological lines echo the actual game's seismic floorplan.
    for k in range(22):
        pts = []
        for i in range(801):
            x = i / 800 * width
            y = height * (k / 21) + math.sin(x / width * 8 + k * .22) * height * .045
            y += math.sin(x / width * 19 - k * .31) * height * .012
            pts.append((x, y))
        d.line(pts, fill=(31, 49, 40), width=2)
    # Receiving chambers: asymmetry and broken outlines, without fictional UI.
    for sx, sy, size in [(.15, .32, .16), (.79, .67, .13)]:
        x, y, z = width*sx, height*sy, height*size
        points = [(x-z,y-z*.8),(x+z*.63,y-z),(x+z,y-z*.5),
                  (x+z*.87,y+z*.75),(x-z*.45,y+z),(x-z,y+z*.57)]
        d.line(points+[points[0]],fill='#425340',width=3)
        for j in range(4):
            off = z * (.12+j*.12)
            d.line((x-z*.5,y+off,x+z*.5,y+off),fill='#334438',width=3)
    # The exact fractured arc / diagonal needle / waveform language of the icon.
    d.ellipse((cx-r*1.23,cy-r*1.23,cx+r*1.23,cy+r*1.23),fill='#13231e',outline='#536049',width=3)
    for ring in range(7):
        rr = r * (.3+ring*.115)
        d.arc((cx-rr,cy-rr,cx+rr,cy+rr),45+ring*4,318-ring*3,
              fill='#ddd2b5' if ring%2==0 else '#526354',width=6 if ring==6 else 3)
    for tick in range(72):
        angle=tick/72*math.tau
        inner=r*(1.04 if tick%6==0 else 1.10)
        d.line((cx+math.cos(angle)*inner,cy+math.sin(angle)*inner,
                cx+math.cos(angle)*r*1.16,cy+math.sin(angle)*r*1.16),fill='#b38a4f',width=3)
    # The echo is offset, then stops. The live signal stays central for safe crops.
    for dx,dy,rr in [(-r*1.65,r*.27,r*.13),(r*1.7,-r*.33,r*.11)]:
        d.ellipse((cx+dx-rr,cy+dy-rr,cx+dx+rr,cy+dy+rr),outline='#648477',width=3)
    wave=[]
    for i in range(1600):
        t=i/1599
        x=cx+(t-.5)*r*3.4
        y=cy+math.sin(t*43)*math.exp(-((t-.55)*5)**2)*r*.58
        wave.append((x,y))
    light=Image.new('RGB',im.size)
    ld=ImageDraw.Draw(light)
    ld.line(wave,fill='#57733c',width=18)
    im=Image.blend(im,Image.fromarray(np.maximum(np.asarray(im),np.asarray(light.filter(ImageFilter.GaussianBlur(18))))),.65)
    d=ImageDraw.Draw(im)
    d.line(wave,fill='#c4dc91',width=5)
    d.line((cx,cy,cx+r*.73,cy-r*.52),fill='#e68145',width=8)
    d.ellipse((cx-11,cy-11,cx+11,cy+11),fill='#eee3c7')
    return im


if __name__ == '__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    manifest=[]
    for name,w,h in [('field-receiver-header',3840,1646),('field-receiver-search',3840,2560)]:
        path=OUT/f'{name}.png'
        image=render(w,h)
        image.save(path,optimize=True)
        manifest.append({'file':path.name,'width':w,'height':h,'mode':image.mode,
                         'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        print(path.name,w,h,image.mode)
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
