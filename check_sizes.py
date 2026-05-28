import struct
import os

def get_png_size(path):
    with open(path, 'rb') as f:
        f.read(16)
        width, height = struct.unpack('>LL', f.read(8))
        return width, height

files = [
    'assets/images/owl/owl_home_bg.png.png',
    'assets/images/owl/owl_sprites_1.png.png',
    'assets/images/owl/owl_sprites_2.png.png'
]

for p in files:
    if os.path.exists(p):
        new_p = p.replace('.png.png', '.png')
        os.rename(p, new_p)
        w, h = get_png_size(new_p)
        print(f"{new_p}: {w}x{h}")
    else:
        print(f"{p} not found")
