"""
Extract owl frames V5 - Using auto-detected precise cell boundaries.
Scans each row for vertical dark separator columns, then extracts
the content regions between them.
"""
from PIL import Image
import os
import shutil

FRAME_SIZE = 128
BG_THRESHOLD = 42


def make_transparent(img):
    """Convert dark/grid background to transparent."""
    rgba = img.convert('RGBA')
    pixels = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            brightness = (r + g + b) / 3
            max_c = max(r, g, b)
            min_c = min(r, g, b)
            sat = (max_c - min_c) / max(max_c, 1)
            if brightness < BG_THRESHOLD:
                pixels[x, y] = (0, 0, 0, 0)
            elif brightness < 80 and sat < 0.12:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def scan_cells(gray, y_start, y_end, min_cell_width=30):
    """Find content cell boundaries by scanning for vertical dark separators."""
    w = gray.size[0]
    span = y_end - y_start
    
    dark_cols = []
    for x in range(w):
        dark_count = 0
        for y in range(y_start, y_end):
            if gray.getpixel((x, y)) < BG_THRESHOLD:
                dark_count += 1
        if dark_count > span * 0.82:
            dark_cols.append(x)
    
    # Group consecutive dark columns into separator bands
    groups = []
    if dark_cols:
        start = dark_cols[0]
        prev = dark_cols[0]
        for x in dark_cols[1:]:
            if x - prev > 2:
                groups.append((start, prev))
                start = x
            prev = x
        groups.append((start, prev))
    
    # Extract content regions between separators
    cells = []
    for i in range(len(groups) - 1):
        cell_start = groups[i][1] + 1
        cell_end = groups[i+1][0] - 1
        if cell_end - cell_start >= min_cell_width:
            cells.append((cell_start, cell_end))
    
    return cells


def extract_frame(img, x1, y1, x2, y2, output_size=FRAME_SIZE):
    """Extract, clean, and center a single frame."""
    iw, ih = img.size
    x2 = min(x2, iw)
    y2 = min(y2, ih)
    
    region = img.crop((x1, y1, x2, y2))
    clean = make_transparent(region)
    
    bbox = clean.getbbox()
    if bbox is None:
        return None
    
    content = clean.crop(bbox)
    cw, ch = content.size
    
    if cw < 15 or ch < 15:
        return None
    
    canvas = Image.new('RGBA', (output_size, output_size), (0, 0, 0, 0))
    
    if cw > output_size or ch > output_size:
        scale = min(output_size / cw, output_size / ch)
        new_w = max(1, int(cw * scale))
        new_h = max(1, int(ch * scale))
        content = content.resize((new_w, new_h), Image.NEAREST)
        cw, ch = new_w, new_h
    
    px = (output_size - cw) // 2
    py = (output_size - ch) // 2
    canvas.paste(content, (px, py), content)
    return canvas


def extract_animations(img, gray, y_start, y_end, anim_defs, output_dir):
    """Extract animations from a row using auto-detected cell boundaries."""
    cells = scan_cells(gray, y_start, y_end)
    print(f"  y={y_start}-{y_end}: {len(cells)} cells detected")
    
    cell_idx = 0
    for anim_name, count in anim_defs:
        out = os.path.join(output_dir, anim_name)
        os.makedirs(out, exist_ok=True)
        
        saved = 0
        for f in range(count):
            if cell_idx >= len(cells):
                print(f"    WARNING: ran out of cells for {anim_name}")
                break
            
            x1, x2 = cells[cell_idx]
            frame = extract_frame(img, x1, y_start, x2, y_end)
            cell_idx += 1
            
            if frame is not None:
                saved += 1
                frame.save(os.path.join(out, f"{saved}.png"))
        
        print(f"    {anim_name}: {saved} frames")


def main():
    base = "assets/images/owl"
    output = os.path.join(base, "frames")
    
    if os.path.exists(output):
        shutil.rmtree(output)
    os.makedirs(output, exist_ok=True)
    
    # ================================================================
    # SHEET 1: 1408 x 768
    # ================================================================
    print("Processing Sheet 1 (1408x768)...")
    img1 = Image.open(os.path.join(base, "owl_sprites_1.png")).convert('RGBA')
    gray1 = img1.convert('L')
    
    # Row definitions: (y_start, y_end, [(anim_name, frame_count), ...])
    # y ranges are the SPRITE-ONLY area (below text labels)
    extract_animations(img1, gray1, 40, 145, [("idle", 4), ("blink", 3)], output)
    extract_animations(img1, gray1, 190, 298, [("takeoff", 4), ("flying", 6)], output)
    extract_animations(img1, gray1, 345, 450, [("landing", 4), ("walking", 5)], output)
    extract_animations(img1, gray1, 498, 612, [("feeding", 10)], output)
    extract_animations(img1, gray1, 655, 768, [("petting", 10)], output)
    
    # ================================================================
    # SHEET 2: 2816 x 1536
    # ================================================================
    print("\nProcessing Sheet 2 (2816x1536)...")
    img2 = Image.open(os.path.join(base, "owl_sprites_2.png")).convert('RGBA')
    gray2 = img2.convert('L')
    
    # Only extract the unique animations from sheet 2
    extract_animations(img2, gray2, 965, 1220, [("sleeping", 4), ("alerted", 4)], output)
    extract_animations(img2, gray2, 1285, 1536, [("hurt", 4), ("waking_up", 4)], output)
    
    # Summary
    print(f"\n{'='*60}")
    print("EXTRACTION COMPLETE")
    print(f"{'='*60}")
    total = 0
    for anim_dir in sorted(os.listdir(output)):
        anim_path = os.path.join(output, anim_dir)
        if os.path.isdir(anim_path):
            frames = sorted([f for f in os.listdir(anim_path) if f.endswith('.png')])
            print(f"  {anim_dir}: {len(frames)} frames")
            total += len(frames)
    print(f"  TOTAL: {total} frames")


if __name__ == "__main__":
    main()
