"""
Procedural generator for authentic tournament carrom assets.
Generates:
1. High-resolution playing surface texture (English birch ply, compass star, baselines, foul arrows, pocket netting)
2. Roughness map (smooth satin board, matte markings, rough netting)
3. Black lacquered hardwood frame decals with crisp white "nOMEX®" logo
4. Lathe-turned tournament carrom men and acrylic striker textures
"""

import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUTPUT_DIR = r"D:\Carrom\godot\assets\textures"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Resolution: 2048 x 2048 for high-fidelity rendering
RES = 2048
BOARD_SIZE_CM = 74.0  # Tournament regulation playing surface: 74cm x 74cm

def cm_to_px(cm):
    """Convert centimeters on the 74cm board to pixel coordinates."""
    return cm * (RES / BOARD_SIZE_CM)

def to_canvas(x_cm, z_cm):
    """Convert (X, Z) coordinates centered at (0, 0) to Canvas (x_px, y_px)."""
    cx = RES / 2.0
    cy = RES / 2.0
    px = cx + cm_to_px(x_cm)
    py = cy + cm_to_px(z_cm)
    return px, py

def create_wood_texture(width, height):
    """Generate high-end English birch plywood veneer texture."""
    print("Generating birch plywood veneer texture...")
    np.random.seed(42)
    
    # Coordinates grid
    y_coords, x_coords = np.mgrid[0:height, 0:width].astype(np.float32)
    
    # Large scale gentle color variation (radial / subtle ply veneer gradient)
    r_dist = np.sqrt((x_coords - width/2)**2 + (y_coords - height/2)**2) / (width/2)
    vignette = 1.0 - 0.05 * (r_dist ** 1.8)
    
    # Wood grain: smooth longitudinal grain along Y axis with gentle organic wave
    wave1 = np.sin(x_coords * 0.008 + np.sin(y_coords * 0.003) * 2.5)
    wave2 = np.sin(x_coords * 0.022 + np.cos(y_coords * 0.006) * 3.0)
    wave3 = np.sin(x_coords * 0.065 + np.sin(y_coords * 0.015) * 1.5)
    
    # Fine wood fiber noise
    noise_fine = np.random.normal(128, 20, (height, width)).astype(np.float32)
    noise_fine = np.clip(noise_fine, 0, 255).astype(np.uint8)
    noise_img = Image.fromarray(noise_fine, mode='L')
    noise_blur = noise_img.filter(ImageFilter.GaussianBlur(radius=0.7))
    noise_arr = (np.array(noise_blur).astype(np.float32) - 128.0) / 25.0
    
    grain = (wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.20)
    grain_intensity = (grain + 1.0) * 0.5  # 0 to 1
    
    # Tournament Birch plywood tone:
    # Warm cream / natural blonde birch ply
    base_r = 244.0 - grain_intensity * 16.0 + noise_arr * 2.5
    base_g = 227.0 - grain_intensity * 20.0 + noise_arr * 2.5
    base_b = 198.0 - grain_intensity * 24.0 + noise_arr * 2.0
    
    base_r = np.clip(base_r * vignette, 0, 255).astype(np.uint8)
    base_g = np.clip(base_g * vignette, 0, 255).astype(np.uint8)
    base_b = np.clip(base_b * vignette, 0, 255).astype(np.uint8)
    
    wood_rgb = np.stack([base_r, base_g, base_b], axis=-1)
    wood_image = Image.fromarray(wood_rgb, mode='RGB')
    return wood_image

def draw_arrowhead(draw, start, end, head_len=24, head_angle=math.radians(25), fill="#121212", width=3):
    """Draw a line with an arrowhead pointing at `end`."""
    draw.line([start, end], fill=fill, width=width)
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    angle = math.atan2(dy, dx)
    
    p1 = (end[0] - head_len * math.cos(angle - head_angle),
          end[1] - head_len * math.sin(angle - head_angle))
    p2 = (end[0] - head_len * math.cos(angle + head_angle),
          end[1] - head_len * math.sin(angle + head_angle))
    
    draw.polygon([end, p1, p2], fill=fill)

def draw_curved_arrow_arc(draw, center_cm, radius_cm, start_deg, end_deg, fill="#121212", width=3):
    """Draw a circular arc with arrowheads at both ends."""
    cx, cy = to_canvas(center_cm[0], center_cm[1])
    r_px = cm_to_px(radius_cm)
    
    bbox = [cx - r_px, cy - r_px, cx + r_px, cy + r_px]
    draw.arc(bbox, start=start_deg, end=end_deg, fill=fill, width=width)
    
    rad_start = math.radians(start_deg)
    p_start = (cx + r_px * math.cos(rad_start), cy + r_px * math.sin(rad_start))
    tangent_start = (-math.sin(rad_start), math.cos(rad_start))
    head_len = 16
    angle_s = math.atan2(tangent_start[1], tangent_start[0]) + math.pi
    p1 = (p_start[0] + head_len * math.cos(angle_s - 0.4), p_start[1] + head_len * math.sin(angle_s - 0.4))
    p2 = (p_start[0] + head_len * math.cos(angle_s + 0.4), p_start[1] + head_len * math.sin(angle_s + 0.4))
    draw.polygon([p_start, p1, p2], fill=fill)
    
    rad_end = math.radians(end_deg)
    p_end = (cx + r_px * math.cos(rad_end), cy + r_px * math.sin(rad_end))
    tangent_end = (-math.sin(rad_end), math.cos(rad_end))
    angle_e = math.atan2(tangent_end[1], tangent_end[0])
    p3 = (p_end[0] + head_len * math.cos(angle_e - 0.4), p_end[1] + head_len * math.sin(angle_e - 0.4))
    p4 = (p_end[0] + head_len * math.cos(angle_e + 0.4), p_end[1] + head_len * math.sin(angle_e + 0.4))
    draw.polygon([p_end, p3, p4], fill=fill)

def generate_net_texture(radius_px):
    """Generate circular woven pocket netting texture (chartreuse/lime green)."""
    size = int(radius_px * 2) + 4
    net_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(net_img)
    cx, cy = size / 2.0, size / 2.0
    
    bg_green = (158, 192, 70, 255)
    dark_depth = (28, 36, 10, 255)
    
    # Fill circle with dark background (depth of net)
    draw.ellipse([cx - radius_px, cy - radius_px, cx + radius_px, cy + radius_px], fill=dark_depth)
    
    # Diamond woven cords
    grid_spacing = 9
    for i in range(-int(radius_px), int(radius_px) + grid_spacing, grid_spacing):
        p1 = (cx + i - radius_px, cy - radius_px)
        p2 = (cx + i + radius_px, cy + radius_px)
        draw.line([p1, p2], fill=bg_green, width=3)
        
        p3 = (cx + i + radius_px, cy - radius_px)
        p4 = (cx + i - radius_px, cy + radius_px)
        draw.line([p3, p4], fill=bg_green, width=3)
        
    # Soft circular edge vignette
    mask = Image.new('L', (size, size), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.ellipse([cx - radius_px, cy - radius_px, cx + radius_px, cy + radius_px], fill=255)
    
    net_img.putalpha(mask)
    return net_img

def draw_carrom_markings(wood_image):
    """Draw authentic regulation tournament markings."""
    print("Drawing tournament carrom markings...")
    image = wood_image.copy()
    draw = ImageDraw.Draw(image)
    
    cx, cy = RES / 2.0, RES / 2.0
    
    # Colors
    COLOR_BLACK = "#141416"
    COLOR_RED = "#c21f28"
    COLOR_RED_DARK = "#9e151c"
    
    # -------------------------------------------------------------
    # 1. POCKETS (4 corners at ~35.15 cm from center)
    # -------------------------------------------------------------
    pocket_r = cm_to_px(2.8)
    net_img = generate_net_texture(pocket_r)
    corner_signs = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
    for sx, sz in corner_signs:
        px, py = to_canvas(sx * 35.15, sz * 35.15)
        image.paste(net_img, (int(px - pocket_r - 2), int(py - pocket_r - 2)), net_img)
        # Black outer rim outline
        draw.ellipse([px - pocket_r, py - pocket_r, px + pocket_r, py + pocket_r],
                     outline=COLOR_BLACK, width=4)

    # -------------------------------------------------------------
    # 2. CENTER ROSETTE & 8-POINT COMPASS STAR
    # -------------------------------------------------------------
    r_outer_ring2 = cm_to_px(10.5)
    r_outer_ring1 = cm_to_px(9.8)
    r_mid_ring    = cm_to_px(9.0)
    
    # Outer double ring with red decorative border
    draw.ellipse([cx - r_outer_ring2, cy - r_outer_ring2, cx + r_outer_ring2, cy + r_outer_ring2],
                 outline=COLOR_BLACK, width=4)
    # Red accent circle
    draw.ellipse([cx - (r_outer_ring2 + r_outer_ring1)/2.0, cy - (r_outer_ring2 + r_outer_ring1)/2.0,
                  cx + (r_outer_ring2 + r_outer_ring1)/2.0, cy + (r_outer_ring2 + r_outer_ring1)/2.0],
                 outline=COLOR_RED, width=3)
    draw.ellipse([cx - r_outer_ring1, cy - r_outer_ring1, cx + r_outer_ring1, cy + r_outer_ring1],
                 outline=COLOR_BLACK, width=4)
    draw.ellipse([cx - r_mid_ring, cy - r_mid_ring, cx + r_mid_ring, cy + r_mid_ring],
                 outline=COLOR_BLACK, width=3)
    
    # 8-Point Compass Star:
    # 8 slender triangular rays extending from center circle to r_outer_ring1
    # Each ray has half-black, half-red split along centerline
    r_tip = r_outer_ring1
    r_inner_center = cm_to_px(1.59)  # Queen circle radius
    
    half_angle_span = math.radians(7.5)
    
    for i in range(8):
        angle_rad = i * (math.pi / 4.0)
        tip_x = cx + r_tip * math.cos(angle_rad)
        tip_y = cy + r_tip * math.sin(angle_rad)
        
        ang_left = angle_rad - half_angle_span
        bl_x = cx + r_inner_center * math.cos(ang_left)
        bl_y = cy + r_inner_center * math.sin(ang_left)
        
        ang_right = angle_rad + half_angle_span
        br_x = cx + r_inner_center * math.cos(ang_right)
        br_y = cy + r_inner_center * math.sin(ang_right)
        
        bc_x = cx + r_inner_center * math.cos(angle_rad)
        bc_y = cy + r_inner_center * math.sin(angle_rad)
        
        # Left half triangle -> Black
        draw.polygon([(bl_x, bl_y), (tip_x, tip_y), (bc_x, bc_y)], fill=COLOR_BLACK)
        # Right half triangle -> Red
        draw.polygon([(br_x, br_y), (tip_x, tip_y), (bc_x, bc_y)], fill=COLOR_RED)
        
        # Fine outlines
        draw.line([(bl_x, bl_y), (tip_x, tip_y)], fill=COLOR_BLACK, width=2)
        draw.line([(br_x, br_y), (tip_x, tip_y)], fill=COLOR_BLACK, width=2)
        draw.line([(bc_x, bc_y), (tip_x, tip_y)], fill=COLOR_BLACK, width=2)
    
    # Queen Circle
    draw.ellipse([cx - r_inner_center, cy - r_inner_center, cx + r_inner_center, cy + r_inner_center],
                 fill=COLOR_RED, outline=COLOR_BLACK, width=4)
    # Tiny center black registration dot
    r_dot = cm_to_px(0.3)
    draw.ellipse([cx - r_dot, cy - r_dot, cx + r_dot, cy + r_dot], fill=COLOR_BLACK)
    
    # -------------------------------------------------------------
    # 3. BASELINES (North, South, East, West) WITH REGULATION CAPSULES
    # -------------------------------------------------------------
    baseline_dist = 29.0
    line_gap = 1.59
    base_circle_r = 1.59
    baseline_extent = 18.5
    
    r_circle_px = cm_to_px(base_circle_r)
    
    # Horizontal baselines (South & North)
    for sign_z in [1.0, -1.0]:
        z_center = sign_z * baseline_dist
        z_inner = z_center - sign_z * line_gap
        z_outer = z_center + sign_z * line_gap
        
        p_in_1 = to_canvas(-baseline_extent, z_inner)
        p_in_2 = to_canvas(baseline_extent, z_inner)
        p_out_1 = to_canvas(-baseline_extent, z_outer)
        p_out_2 = to_canvas(baseline_extent, z_outer)
        
        draw.line([p_in_1, p_in_2], fill=COLOR_BLACK, width=3)
        draw.line([p_out_1, p_out_2], fill=COLOR_BLACK, width=3)
        
        # Semicircle capsule arcs at left and right ends
        bx_left, by_left = to_canvas(-baseline_extent, z_center)
        draw.arc([bx_left - r_circle_px, by_left - r_circle_px, bx_left + r_circle_px, by_left + r_circle_px],
                 start=90, end=270, fill=COLOR_BLACK, width=3)
        
        bx_right, by_right = to_canvas(baseline_extent, z_center)
        draw.arc([bx_right - r_circle_px, by_right - r_circle_px, bx_right + r_circle_px, by_right + r_circle_px],
                 start=-90, end=90, fill=COLOR_BLACK, width=3)
        
        # Red Base Circles at both ends
        for sign_x in [-1.0, 1.0]:
            bx, by = to_canvas(sign_x * baseline_extent, z_center)
            draw.ellipse([bx - r_circle_px, by - r_circle_px, bx + r_circle_px, by + r_circle_px],
                         fill=COLOR_RED, outline=COLOR_BLACK, width=3)
    
    # Vertical baselines (East & West)
    for sign_x in [1.0, -1.0]:
        x_center = sign_x * baseline_dist
        x_inner = x_center - sign_x * line_gap
        x_outer = x_center + sign_x * line_gap
        
        p_in_1 = to_canvas(x_inner, -baseline_extent)
        p_in_2 = to_canvas(x_inner, baseline_extent)
        p_out_1 = to_canvas(x_outer, -baseline_extent)
        p_out_2 = to_canvas(x_outer, baseline_extent)
        
        draw.line([p_in_1, p_in_2], fill=COLOR_BLACK, width=3)
        draw.line([p_out_1, p_out_2], fill=COLOR_BLACK, width=3)
        
        # Semicircle capsule arcs at top and bottom ends
        bx_top, by_top = to_canvas(x_center, -baseline_extent)
        draw.arc([bx_top - r_circle_px, by_top - r_circle_px, bx_top + r_circle_px, by_top + r_circle_px],
                 start=180, end=360, fill=COLOR_BLACK, width=3)
        
        bx_bot, by_bot = to_canvas(x_center, baseline_extent)
        draw.arc([bx_bot - r_circle_px, by_bot - r_circle_px, bx_bot + r_circle_px, by_bot + r_circle_px],
                 start=0, end=180, fill=COLOR_BLACK, width=3)
        
        # Red Base Circles at both ends
        for sign_z in [-1.0, 1.0]:
            bx, by = to_canvas(x_center, sign_z * baseline_extent)
            draw.ellipse([bx - r_circle_px, by - r_circle_px, bx + r_circle_px, by + r_circle_px],
                         fill=COLOR_RED, outline=COLOR_BLACK, width=3)
    
    # -------------------------------------------------------------
    # 4. CORNER FOUL LINES, ARROWS & CIRCULAR ARCS
    # -------------------------------------------------------------
    for sx, sz in corner_signs:
        # Diagonal foul line pointing toward corner pocket
        p_start = to_canvas(sx * 24.5, sz * 24.5)
        p_end = to_canvas(sx * 31.8, sz * 31.8)
        draw_arrowhead(draw, p_start, p_end, head_len=26, fill=COLOR_BLACK, width=3)
        
        # Inward arrow pointing toward center
        p_in_start = to_canvas(sx * 23.5, sz * 23.5)
        p_in_end = to_canvas(sx * 15.0, sz * 15.0)
        draw_arrowhead(draw, p_in_start, p_in_end, head_len=26, fill=COLOR_BLACK, width=3)
        
        # Circular foul arc with double arrows
        arc_center_cm = (sx * 22.0, sz * 22.0)
        if sx > 0 and sz > 0: # SE
            draw_curved_arrow_arc(draw, arc_center_cm, radius_cm=3.4, start_deg=80, end_deg=280, fill=COLOR_BLACK, width=3)
        elif sx < 0 and sz > 0: # SW
            draw_curved_arrow_arc(draw, arc_center_cm, radius_cm=3.4, start_deg=-100, end_deg=100, fill=COLOR_BLACK, width=3)
        elif sx > 0 and sz < 0: # NE
            draw_curved_arrow_arc(draw, arc_center_cm, radius_cm=3.4, start_deg=170, end_deg=370, fill=COLOR_BLACK, width=3)
        else: # NW
            draw_curved_arrow_arc(draw, arc_center_cm, radius_cm=3.4, start_deg=-10, end_deg=190, fill=COLOR_BLACK, width=3)
            
    # -------------------------------------------------------------
    # 5. "MADE IN INDIA" TEXT (Along right baseline)
    # -------------------------------------------------------------
    try:
        font = ImageFont.truetype("arial.ttf", 26)
    except:
        font = ImageFont.load_default()
        
    text = "MADE IN INDIA"
    text_img = Image.new('RGBA', (280, 40), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(text_img)
    t_draw.text((10, 5), text, fill=COLOR_RED_DARK, font=font)
    text_rotated = text_img.rotate(90, expand=True)
    
    tx, ty = to_canvas(33.5, 0)
    image.paste(text_rotated, (int(tx - text_rotated.width/2), int(ty - text_rotated.height/2)), text_rotated)

    print("Carrom markings successfully drawn!")
    return image

def generate_roughness_map(albedo_image):
    """Generate physically-based roughness map."""
    print("Generating roughness map...")
    arr = np.array(albedo_image).astype(np.float32)
    gray = (arr[:, :, 0] * 0.299 + arr[:, :, 1] * 0.587 + arr[:, :, 2] * 0.114)
    
    # Smooth polished satin carrom finish ~0.26 (value 66)
    roughness = np.full_like(gray, 66.0)
    
    # Markings mask (slightly less glossy ink)
    markings_mask = gray < 160
    roughness[markings_mask] = 88.0
    
    # Pocket netting mask (matte cord)
    y_g, x_g = np.mgrid[0:RES, 0:RES]
    pocket_r = cm_to_px(2.8)
    for sx, sz in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        px, py = to_canvas(sx * 35.15, sz * 35.15)
        dist = np.sqrt((x_g - px)**2 + (y_g - py)**2)
        roughness[dist <= pocket_r] = 185.0
        
    roughness_img = Image.fromarray(np.clip(roughness, 0, 255).astype(np.uint8), mode='L')
    return roughness_img

def generate_frame_textures():
    """Generate transparent high-res nOMEX® logo decals for the wooden frame."""
    print("Generating crisp nOMEX® logo decals...")
    w, h = 1024, 256
    
    top_img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(top_img)
    
    try:
        font_logo = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 110)
        font_sub = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 36)
    except:
        font_logo = ImageFont.load_default()
        font_sub = ImageFont.load_default()
        
    logo_text = "nOMEX"
    bbox = draw.textbbox((0, 0), logo_text, font=font_logo)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    lx = (w - tw) / 2 - 20
    ly = (h - th) / 2 - 10
    
    # Crisp white letters with subtle drop shadow for depth
    draw.text((lx + 2, ly + 2), logo_text, fill=(0, 0, 0, 160), font=font_logo)
    draw.text((lx, ly), logo_text, fill=(255, 255, 255, 255), font=font_logo)
    
    draw.text((lx + tw + 8, ly + 14), "®", fill=(240, 240, 245, 255), font=font_sub)
    
    # Bottom frame: rotated 180 degrees
    bot_img = top_img.rotate(180)
    
    return top_img, bot_img

def generate_piece_textures():
    """Generate realistic lathe-turned carrom piece textures with concentric carved grooves."""
    print("Generating tournament carrom piece textures...")
    size = 512
    cx, cy = size / 2.0, size / 2.0
    
    def make_piece(base_color, groove_color, ring_radii, center_fill=None, center_r=0, extra_rings=None):
        img = Image.new('RGB', (size, size), base_color)
        draw = ImageDraw.Draw(img)
        
        # Subtle radial shading for lathe curved profile
        y_g, x_g = np.mgrid[0:size, 0:size]
        dist = np.sqrt((x_g - cx)**2 + (y_g - cy)**2)
        norm_r = dist / (size / 2.0)
        
        # Concentric carved groove rings (smooth dark lines)
        for r_ratio in ring_radii:
            r = r_ratio * (size / 2.0)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=groove_color, width=6)
            
        if extra_rings:
            for r_ratio, col, w in extra_rings:
                r = r_ratio * (size / 2.0)
                draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=w)
            
        if center_fill and center_r > 0:
            cr = center_r * (size / 2.0)
            draw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=center_fill, outline=groove_color, width=4)
            
        # Shading
        arr = np.array(img).astype(np.float32)
        edge_shade = np.clip(1.0 - np.power(np.clip(norm_r, 0, 1), 5) * 0.35, 0.45, 1.0)
        arr[:, :, 0] *= edge_shade
        arr[:, :, 1] *= edge_shade
        arr[:, :, 2] *= edge_shade
        
        # Circular anti-aliased alpha mask
        radius = size / 2.0 - 1.5
        alpha = np.clip((radius - dist) + 0.5, 0.0, 1.0) * 255.0
        rgba = np.dstack([arr.astype(np.uint8), alpha.astype(np.uint8)])
        return Image.fromarray(rgba, mode='RGBA')
        
    # White piece: warm ivory / natural polished wood with 3 concentric ring grooves
    white_img = make_piece((244, 238, 226), (170, 155, 135), [0.35, 0.60, 0.82])
    
    # Black piece: deep polished ebony with 3 concentric ring grooves
    black_img = make_piece((26, 26, 28), (10, 10, 12), [0.35, 0.60, 0.82])
    
    # Queen: rich carrom crimson with dark concentric grooves and gold center
    queen_img = make_piece((195, 26, 38), (110, 14, 22), [0.38, 0.65, 0.85], center_fill=(215, 165, 45), center_r=0.18)
    
    # Striker: tournament sapphire acrylic with gold and silver ring inlays
    extra = [
        (0.25, (225, 185, 55), 5),
        (0.48, (210, 220, 240), 5),
        (0.70, (225, 185, 55), 5),
        (0.88, (210, 220, 240), 5),
    ]
    striker_img = make_piece((18, 32, 75), (10, 18, 45), [], center_fill=(235, 195, 55), center_r=0.14, extra_rings=extra)
    
    return white_img, black_img, queen_img, striker_img

def main():
    print("=== STARTING CARROM TEXTURE ASSET GENERATION ===")
    
    # 1. Generate Board Textures
    wood_img = create_wood_texture(RES, RES)
    board_albedo = draw_carrom_markings(wood_img)
    board_albedo_path = os.path.join(OUTPUT_DIR, "carrom_board_albedo.png")
    board_albedo.save(board_albedo_path, "PNG", optimize=True)
    print(f"Saved: {board_albedo_path}")
    
    roughness_img = generate_roughness_map(board_albedo)
    roughness_path = os.path.join(OUTPUT_DIR, "carrom_board_roughness.png")
    roughness_img.save(roughness_path, "PNG", optimize=True)
    print(f"Saved: {roughness_path}")
    
    # 2. Generate Frame Textures
    frame_top, frame_bot = generate_frame_textures()
    frame_top_path = os.path.join(OUTPUT_DIR, "frame_top.png")
    frame_top.save(frame_top_path, "PNG")
    frame_bot_path = os.path.join(OUTPUT_DIR, "frame_bottom.png")
    frame_bot.save(frame_bot_path, "PNG")
    print(f"Saved frame textures: {frame_top_path}, {frame_bot_path}")
    
    # 3. Generate Piece Textures
    p_white, p_black, p_queen, striker = generate_piece_textures()
    p_white.save(os.path.join(OUTPUT_DIR, "piece_white.png"), "PNG")
    p_black.save(os.path.join(OUTPUT_DIR, "piece_black.png"), "PNG")
    p_queen.save(os.path.join(OUTPUT_DIR, "piece_queen.png"), "PNG")
    striker.save(os.path.join(OUTPUT_DIR, "piece_striker.png"), "PNG")
    print("Saved piece textures!")
    
    print("=== ALL ASSETS GENERATED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
