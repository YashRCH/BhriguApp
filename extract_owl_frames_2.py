"""
Extract individual owl sprite frames from owl_stripe_2.png.
Scans for cells in each row, removes the magenta/purple background, 
trims to content bounding box, and saves as transparent PNGs.
"""
from PIL import Image
import os
import shutil

FRAME_SIZE = 128
# Magenta/purple background color detection
def is_bg_pixel(r, g, b):
    """Detect the magenta/purple background in the sprite sheet."""
    return (r > 150 and b > 150 and g < 120) or \
           (r > 180 and b > 180 and g < 80)

def col_is_bg(img_pixels, x, y_start, y_end, w, threshold=0.85):
    """Check if a column is mostly background color."""
    bg_count = 0
    total = 0
    for y in range(y_start, min(y_end, img_pixels.size[1]), 3):
        r, g, b, a = img_pixels.getpixel((x, y))
        if is_bg_pixel(r, g, b):
            bg_count += 1
        total += 1
    if total == 0:
        return True
    return bg_count / total > threshold

def row_is_bg(img_pixels, y, w, threshold=0.90):
    """Check if a row is mostly background color."""
    bg_count = 0
    total = 0
    for x in range(0, w, 3):
        r, g, b, a = img_pixels.getpixel((x, y))
        if is_bg_pixel(r, g, b):
            bg_count += 1
        total += 1
    if total == 0:
        return True
    return bg_count / total > threshold

def find_row_bands(img, h, w):
    """Find horizontal bands of sprite content (between bg rows)."""
    bands = []
    in_content = False
    start = 0
    for y in range(h):
        bg = row_is_bg(img, y, w)
        if not in_content and not bg:
            start = y
            in_content = True
        elif in_content and bg:
            if y - start > 40:  # Min row height
                bands.append((start, y))
            in_content = False
    if in_content and h - start > 40:
        bands.append((start, h))
    return bands

def find_cells_in_band(img, y_start, y_end, w):
    """Find cell boundaries within a row band."""
    cells = []
    in_cell = False
    cell_start = 0
    for x in range(w):
        bg = col_is_bg(img, x, y_start, y_end, w)
        if not in_cell and not bg:
            cell_start = x
            in_cell = True
        elif in_cell and bg:
            cell_w = x - cell_start
            if cell_w > 100:  # Min cell width (skip number labels ~50px)
                cells.append((cell_start, x))
            in_cell = False
    if in_cell:
        cell_w = w - cell_start
        if cell_w > 100:
            cells.append((cell_start, w))
    return cells

def make_transparent(img):
    """Convert magenta/purple background to transparent."""
    rgba = img.convert('RGBA')
    pixels = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if is_bg_pixel(r, g, b):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba

def extract_and_save(img, x1, y1, x2, y2, output_path, output_size=FRAME_SIZE):
    """Extract a sprite cell, trim bottom label area, clean background, center on canvas, and save."""
    # Trim bottom 15% to remove number labels
    cell_h = y2 - y1
    trim_y2 = y1 + int(cell_h * 0.85)
    
    region = img.crop((x1, y1, x2, trim_y2))
    clean = make_transparent(region)
    
    bbox = clean.getbbox()
    if bbox is None:
        return False
    
    content = clean.crop(bbox)
    cw, ch = content.size
    
    if cw < 10 or ch < 10:
        return False
    
    # Scale down if needed
    if cw > output_size or ch > output_size:
        scale = min(output_size / cw, output_size / ch)
        new_w = max(1, int(cw * scale))
        new_h = max(1, int(ch * scale))
        content = content.resize((new_w, new_h), Image.NEAREST)
        cw, ch = new_w, new_h
    
    canvas = Image.new('RGBA', (output_size, output_size), (0, 0, 0, 0))
    px = (output_size - cw) // 2
    py = (output_size - ch) // 2
    canvas.paste(content, (px, py), content)
    canvas.save(output_path)
    return True

def main():
    src = "assets/images/owl/owl_stripe_2.png"
    out_dir = "assets/images/owl/frames_2"
    
    if os.path.exists(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    
    print(f"Opening {src}...")
    try:
        img = Image.open(src).convert('RGBA')
    except Exception as e:
        print(f"Error opening image: {e}")
        return
        
    w, h = img.size
    print(f"Image size: {w}x{h}")
    
    # We will just extract all cells in all rows and put them in generically named folders first
    # so we can see what the layout is, OR we can try the same layout if it matches.
    # Let's try the generic approach first to be safe, since we don't know the layout of owl_stripe_2.png.
    
    # Find rows
    bands = find_row_bands(img, h, w)
    print(f"\nFound {len(bands)} row bands:")
    for i, (ys, ye) in enumerate(bands):
        print(f"  Row {i}: y={ys}-{ye} (height={ye-ys})")
    
    # Extract frames
    total = 0
    
    for ri, (ys, ye) in enumerate(bands):
        cells = find_cells_in_band(img, ys, ye, w)
        print(f"\n  Row {ri} (y={ys}-{ye}): {len(cells)} cells detected")
        
        row_dir = os.path.join(out_dir, f"row_{ri}")
        os.makedirs(row_dir, exist_ok=True)
        
        saved = 0
        for cell_idx, (cx1, cx2) in enumerate(cells):
            out_path = os.path.join(row_dir, f"{cell_idx}.png")
            if extract_and_save(img, cx1, ys, cx2, ye, out_path):
                saved += 1
        
        total += saved
        print(f"    Row {ri}: {saved} frames saved")
    
    print(f"\n{'='*50}")
    print("EXTRACTION COMPLETE")
    print(f"{'='*50}")
    print(f"  TOTAL: {total} frames")

if __name__ == "__main__":
    main()
