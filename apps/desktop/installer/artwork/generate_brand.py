"""Deterministic geometric installer branding; generated PNGs are committed."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
GROUND = '#11161B'
ACCENT = '#87DAC8'

def mark(draw, x, y, size, color):
    stroke = size * .2
    draw.polygon([(x,y+size),(x,y),(x+stroke,y),(x+size-stroke,y+size*.63),
                  (x+size-stroke,y),(x+size,y),(x+size,y+size),(x+size-stroke,y+size),
                  (x+stroke,y+size*.37),(x+stroke,y+size)], fill=color)

image = Image.new('RGB', (328, 628), GROUND)
draw = ImageDraw.Draw(image)
for i in range(3):
    draw.rounded_rectangle((32+i*12, 290+i*16, 296-i*12, 578-i*12), radius=22, fill=['#192228','#202E33','#293E40'][i])
    draw.line((64+i*12, 346+i*16, 234-i*8, 346+i*16), fill='#385958', width=3)
    draw.line((64+i*12, 370+i*16, 208-i*8, 370+i*16), fill='#385958', width=3)
mark(draw, 54, 74, 94, ACCENT)
font_path = Path('C:/Windows/Fonts/segoeuib.ttf')
font = ImageFont.truetype(str(font_path), 40)
draw.text((50, 191), 'Nex', fill='#EDF7F4', font=font)
draw.rounded_rectangle((53, 253, 107, 257), radius=2, fill=ACCENT)
image.save(ROOT/'wizard-brand.png')
logo = Image.new('RGB', (110, 110), GROUND)
mark(ImageDraw.Draw(logo), 30, 30, 50, ACCENT)
logo.save(ROOT/'wizard-logo.png')
