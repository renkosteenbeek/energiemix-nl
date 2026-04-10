from PIL import Image, ImageDraw, ImageFont
import math
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)

BG = (250, 250, 247)
GREEN_DARK = (15, 81, 50)
GREEN_MID = (101, 196, 106)
GREEN_LIGHT = (180, 225, 170)
WHITE = (255, 255, 255)


def radial_gradient(size, center_color, edge_color, cx=0.35, cy=0.3):
    img = Image.new("RGB", (size, size))
    pixels = img.load()
    max_dist = math.sqrt(size * size + size * size)
    for y in range(size):
        for x in range(size):
            dx = x - size * cx
            dy = y - size * cy
            dist = math.sqrt(dx * dx + dy * dy) / (max_dist * 0.5)
            dist = min(1.0, dist)
            r = int(center_color[0] + (edge_color[0] - center_color[0]) * dist)
            g = int(center_color[1] + (edge_color[1] - center_color[1]) * dist)
            b = int(center_color[2] + (edge_color[2] - center_color[2]) * dist)
            pixels[x, y] = (r, g, b)
    return img


def draw_bolt(draw, cx, cy, scale, color):
    points = [
        (cx - 0.12 * scale, cy - 0.38 * scale),
        (cx + 0.15 * scale, cy - 0.38 * scale),
        (cx + 0.02 * scale, cy - 0.04 * scale),
        (cx + 0.22 * scale, cy - 0.04 * scale),
        (cx - 0.08 * scale, cy + 0.42 * scale),
        (cx + 0.02 * scale, cy + 0.08 * scale),
        (cx - 0.18 * scale, cy + 0.08 * scale),
    ]
    draw.polygon(points, fill=color)


def generate_icon(size, output_path):
    img = radial_gradient(size, GREEN_MID, GREEN_DARK, cx=0.35, cy=0.3)
    draw = ImageDraw.Draw(img)

    margin = size * 0.12
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=size * 0.22,
        fill=None,
        outline=(*WHITE, 40),
        width=max(1, int(size * 0.003)),
    )

    draw_bolt(draw, size * 0.48, size * 0.48, size * 0.9, WHITE)

    img.save(output_path, "PNG")
    print(f"  {output_path} ({size}x{size})")


def generate_splash(size, output_path, dark=False):
    bg = (10, 10, 10) if dark else BG
    accent = GREEN_MID

    img = Image.new("RGB", (size, size), bg)
    draw = ImageDraw.Draw(img)

    icon_size = int(size * 0.12)
    icon = radial_gradient(icon_size, GREEN_MID, GREEN_DARK, cx=0.35, cy=0.3)
    icon_draw = ImageDraw.Draw(icon)
    draw_bolt(icon_draw, icon_size * 0.48, icon_size * 0.48, icon_size * 0.9, WHITE)

    mask = Image.new("L", (icon_size, icon_size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [0, 0, icon_size, icon_size],
        radius=int(icon_size * 0.22),
        fill=255,
    )

    paste_x = (size - icon_size) // 2
    paste_y = (size - icon_size) // 2 - int(size * 0.02)
    img.paste(icon, (paste_x, paste_y), mask)

    text_color = WHITE if dark else GREEN_DARK
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNSText.ttf", int(size * 0.018))
    except (OSError, IOError):
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", int(size * 0.018))
        except (OSError, IOError):
            font = ImageFont.load_default()

    text = "ENERGIEMIX NL"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    draw.text(
        ((size - tw) / 2, paste_y + icon_size + size * 0.025),
        text,
        fill=text_color,
        font=font,
    )

    img.save(output_path, "PNG")
    print(f"  {output_path} ({size}x{size})")


print("Generating app icon...")
ios_icon_dir = os.path.join(ROOT, "ios/App/App/Assets.xcassets/AppIcon.appiconset")
generate_icon(1024, os.path.join(ios_icon_dir, "AppIcon-512@2x.png"))

android_icon_dir = os.path.join(ROOT, "android/app/src/main/res")
for dpi, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    d = os.path.join(android_icon_dir, f"mipmap-{dpi}")
    os.makedirs(d, exist_ok=True)
    generate_icon(size, os.path.join(d, "ic_launcher.png"))
    generate_icon(int(size * 1.5), os.path.join(d, "ic_launcher_foreground.png"))

print("\nGenerating splash screens...")
ios_splash_dir = os.path.join(ROOT, "ios/App/App/Assets.xcassets/Splash.imageset")
generate_splash(2732, os.path.join(ios_splash_dir, "splash-2732x2732.png"))
generate_splash(2732, os.path.join(ios_splash_dir, "splash-2732x2732-1.png"))
generate_splash(2732, os.path.join(ios_splash_dir, "splash-2732x2732-2.png"))
generate_splash(2732, os.path.join(ios_splash_dir, "splash-2732x2732-dark.png"), dark=True)

android_splash_dir = os.path.join(android_icon_dir, "drawable")
os.makedirs(android_splash_dir, exist_ok=True)
generate_splash(2732, os.path.join(android_splash_dir, "splash.png"))

print("\nDone!")
