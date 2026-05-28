"""
Extract individual owl frames from owl_stripes.png - V2.
Fixes:
1. Lower merge gap threshold to avoid merging adjacent sprites
2. Trim green background from extracted frames (crop to content bounding box)
3. Resize all frames to a uniform size for consistent animation
"""
from PIL import Image
import os

img = Image.open('assets/images/owl/owl_stripes.png')
W, H = img.size
pixels = img.load()

def is_green_pixel(r, g, b):
    return g > 150 and r < 100 and b < 100

def row_is_green(y, threshold=0.95):
    green_count = 0
    for x in range(W):
        r, g, b, a = pixels[x, y]
        if is_green_pixel(r, g, b):
            green_count += 1
    return green_count / W > threshold

# Find content row bands
in_content = False
row_starts = []
row_ends = []
for y in range(H):
    green = row_is_green(y)
    if not in_content and not green:
        row_starts.append(y)
        in_content = True
    elif in_content and green:
        row_ends.append(y - 1)
        in_content = False
if in_content:
    row_ends.append(H - 1)

# Filter to only large bands (actual sprite rows)
sprite_bands = [(s, e) for s, e in zip(row_starts, row_ends) if (e - s + 1) > 100]

print(f"Found {len(sprite_bands)} sprite row bands")

def find_cells_in_band(rs, re):
    """Find cell x-boundaries within a row band."""
    col_green = []
    for x in range(W):
        green_count = 0
        sample_count = 0
        for y in range(rs, re + 1, 4):
            r, g, b, a = pixels[x, y]
            if is_green_pixel(r, g, b):
                green_count += 1
            sample_count += 1
        col_green.append(green_count / sample_count > 0.90)
    
    in_cell = False
    cell_starts = []
    cell_ends = []
    for x in range(W):
        if not in_cell and not col_green[x]:
            cell_starts.append(x)
            in_cell = True
        elif in_cell and col_green[x]:
            cell_ends.append(x - 1)
            in_cell = False
    if in_cell:
        cell_ends.append(W - 1)
    
    # DON'T merge at all - keep each separate blob
    return list(zip(cell_starts, cell_ends))

def trim_green_and_numbers(frame_img):
    """
    Remove the green background, making it transparent.
    Also crop to the bounding box of non-green content,
    excluding the bottom 15% where number labels appear.
    """
    w, h = frame_img.size
    px = frame_img.load()
    
    # Make green pixels transparent
    result = frame_img.copy().convert('RGBA')
    rpx = result.load()
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = rpx[x, y]
            if is_green_pixel(r, g, b):
                rpx[x, y] = (0, 0, 0, 0)
    
    # Find bounding box of non-transparent content
    bbox = result.getbbox()
    if bbox:
        result = result.crop(bbox)
    
    return result

# Pose names per frame within each row  
pose_map = {
    0: [("idle", 4), ("blink", 3)],
    1: [("takeoff", 5), ("flying", 5)],
    2: [("landing", 5), ("walking", 4)],
    3: [("sleeping", 4), ("alerted", 4)],
    4: [("hurt", 4), ("wakingup", 5)],
}

# Output dir
out_dir = 'assets/images/owl/frames'
# Clear old frames
if os.path.exists(out_dir):
    for f in os.listdir(out_dir):
        os.remove(os.path.join(out_dir, f))
os.makedirs(out_dir, exist_ok=True)

total_extracted = 0
all_frames_info = {}  # pose -> [(filename, width, height)]

for ri, (rs, re) in enumerate(sprite_bands):
    raw_cells = find_cells_in_band(rs, re)
    
    # Filter: keep only cells wider than 100px (actual sprites)
    # Number labels are typically 40-55px wide
    cells = [(cs, ce) for cs, ce in raw_cells if (ce - cs + 1) > 100]
    
    print(f"\n  Sprite Row {ri} (y={rs}-{re}): {len(cells)} sprite cells (from {len(raw_cells)} raw)")
    
    poses = pose_map.get(ri, [])
    pose_idx = 0
    pose_frame = 0
    
    for ci, (cs, ce) in enumerate(cells):
        cell_w = ce - cs + 1
        
        # Determine pose name
        if pose_idx < len(poses):
            pose_name, pose_count = poses[pose_idx]
        else:
            pose_name = f"extra_{ri}"
            pose_count = 99
        
        # Crop the raw frame
        raw_frame = img.crop((cs, rs, ce + 1, re + 1))
        
        # Trim green background and get clean sprite
        clean_frame = trim_green_and_numbers(raw_frame)
        
        fname = f"{pose_name}_{pose_frame}.png"
        clean_frame.save(os.path.join(out_dir, fname))
        
        fw, fh = clean_frame.size
        print(f"    {fname}: raw {cell_w}px -> clean {fw}x{fh}")
        
        if pose_name not in all_frames_info:
            all_frames_info[pose_name] = []
        all_frames_info[pose_name].append((fname, fw, fh))
        
        total_extracted += 1
        pose_frame += 1
        
        if pose_frame >= pose_count:
            pose_idx += 1
            pose_frame = 0

print(f"\n=== Total frames extracted: {total_extracted} ===")
print(f"\nFrame sizes per pose:")
for pose, frames in sorted(all_frames_info.items()):
    sizes = [(w, h) for _, w, h in frames]
    print(f"  {pose}: {len(frames)} frames, sizes: {sizes}")
