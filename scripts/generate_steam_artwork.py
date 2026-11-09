"""Generate AAA 'Made by Steam' Aperture Industrial artwork for Steam Library."""

import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS_DIR = Path(r"C:\Users\thecr\steamdeck-hermes-installer\assets")
ASSETS_DIR.mkdir(parents=True, exist_ok=True)


def draw_caduceus(draw, cx, cy, scale=1.0, color=(103, 193, 245)):
    """Draw a stylized Hermes winged staff insignia with metallic glow."""
    s = scale
    # Central staff
    staff_top = int(cy - 120 * s)
    staff_bot = int(cy + 120 * s)
    draw.line([(cx, staff_top), (cx, staff_bot)], fill=color, width=max(2, int(6 * s)))
    draw.ellipse([cx - int(14 * s), staff_top - int(14 * s), cx + int(14 * s), staff_top + int(14 * s)], fill=color)

    # Wings
    wing_pts_left = [
        (cx, staff_top),
        (cx - int(80 * s), staff_top - int(30 * s)),
        (cx - int(110 * s), staff_top + int(20 * s)),
        (cx - int(60 * s), staff_top + int(40 * s)),
        (cx, staff_top + int(30 * s)),
    ]
    wing_pts_right = [
        (cx, staff_top),
        (cx + int(80 * s), staff_top - int(30 * s)),
        (cx + int(110 * s), staff_top + int(20 * s)),
        (cx + int(60 * s), staff_top + int(40 * s)),
        (cx, staff_top + int(30 * s)),
    ]
    draw.polygon(wing_pts_left, fill=color)
    draw.polygon(wing_pts_right, fill=color)

    # Entwined Serpents (sine curves)
    steps = 60
    for side in (-1, 1):
        pts = []
        for i in range(steps):
            t = i / steps
            y = staff_top + int(40 * s) + int(t * 140 * s)
            x = cx + int(math.sin(t * math.pi * 3) * 45 * s * side)
            pts.append((x, y))
        for i in range(len(pts) - 1):
            draw.line([pts[i], pts[i + 1]], fill=color, width=max(1, int(4 * s)))


def generate_poster():
    """Generate 600x900 Vertical Capsule."""
    w, h = 600, 900
    im = Image.new("RGBA", (w, h), (14, 20, 30, 255))
    draw = ImageDraw.Draw(im)

    # Gradient background
    for y in range(h):
        ratio = y / h
        r = int(14 + ratio * 15)
        g = int(20 + ratio * 24)
        b = int(30 + ratio * 38)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Technical grid lines (Aperture blueprint style)
    grid_color = (255, 255, 255, 12)
    for x in range(0, w, 40):
        draw.line([(x, 0), (x, h)], fill=grid_color, width=1)
    for y in range(0, h, 40):
        draw.line([(0, y), (w, y)], fill=grid_color, width=1)

    # Ambient radial cyan glow behind emblem
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for r in range(220, 0, -10):
        alpha = int((1 - r / 220) * 80)
        gdraw.ellipse([300 - r, 380 - r, 300 + r, 380 + r], fill=(26, 159, 255, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(25))
    im = Image.alpha_composite(im, glow)
    draw = ImageDraw.Draw(im)

    # Draw Caduceus emblem
    draw_caduceus(draw, 300, 360, scale=1.5, color=(103, 193, 245, 255))

    # Text: HERMDECK
    draw.text((300, 560), "HERMDECK", fill=(255, 255, 255, 255), anchor="mm", font_size=48)
    draw.text((300, 610), "INSTALLER", fill=(103, 193, 245, 255), anchor="mm", font_size=34)
    draw.text((300, 650), "STEAM DECK ULTIMATE EDITION", fill=(148, 163, 184, 255), anchor="mm", font_size=16)

    # Technical metadata badges
    draw.line([(80, 690), (520, 690)], fill=(255, 255, 255, 40), width=1)
    draw.text((300, 715), "AUTONOMOUS HANDHELD AI & GAME OPS", fill=(203, 213, 225, 255), anchor="mm", font_size=13)
    draw.text((300, 735), "STEAMVOICE • PROTONDB • CLAUDE DIRECTSDK", fill=(100, 116, 139, 255), anchor="mm", font_size=11)

    # Steam Deck Verified Gold Badge Pill
    badge_y = 800
    draw.rounded_rectangle([130, badge_y, 470, badge_y + 44], radius=22, fill=(35, 42, 53, 255), outline=(207, 181, 59, 255), width=2)
    # Green checkmark circle
    draw.ellipse([142, badge_y + 8, 170, badge_y + 36], fill=(16, 185, 129, 255))
    draw.line([(150, badge_y + 22), (155, badge_y + 27), (163, badge_y + 17)], fill=(255, 255, 255, 255), width=3)
    draw.text((320, badge_y + 22), "STEAM DECK VERIFIED", fill=(207, 181, 59, 255), anchor="mm", font_size=15)

    poster_path = ASSETS_DIR / "poster.png"
    im.save(poster_path, "PNG")
    print("Generated poster.png (600x900)")


def generate_grid():
    """Generate 920x430 Wide Banner."""
    w, h = 920, 430
    im = Image.new("RGBA", (w, h), (14, 20, 30, 255))
    draw = ImageDraw.Draw(im)

    # Gradient background
    for y in range(h):
        ratio = y / h
        r = int(14 + ratio * 12)
        g = int(20 + ratio * 20)
        b = int(30 + ratio * 32)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Technical grid lines
    grid_color = (255, 255, 255, 12)
    for x in range(0, w, 40):
        draw.line([(x, 0), (x, h)], fill=grid_color, width=1)
    for y in range(0, h, 40):
        draw.line([(0, y), (w, y)], fill=grid_color, width=1)

    # Left side: Illuminated Caduceus
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for r in range(160, 0, -10):
        alpha = int((1 - r / 160) * 80)
        gdraw.ellipse([200 - r, 215 - r, 200 + r, 215 + r], fill=(26, 159, 255, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(20))
    im = Image.alpha_composite(im, glow)
    draw = ImageDraw.Draw(im)

    draw_caduceus(draw, 200, 215, scale=1.3, color=(103, 193, 245, 255))

    # Right side: Typography
    draw.text((420, 150), "HERMDECK INSTALLER", fill=(255, 255, 255, 255), font_size=40)
    draw.text((420, 205), "STEAM DECK ULTIMATE EDITION", fill=(103, 193, 245, 255), font_size=20)
    draw.text((420, 245), "Handheld AI Suite • SteamOS Ops • ProtonDB Auto-Fixes", fill=(148, 163, 184, 255), font_size=14)

    # Verified Pill
    badge_x, badge_y = 420, 290
    draw.rounded_rectangle([badge_x, badge_y, badge_x + 290, badge_y + 36], radius=18, fill=(35, 42, 53, 255), outline=(207, 181, 59, 255), width=2)
    draw.ellipse([badge_x + 8, badge_y + 6, badge_x + 32, badge_y + 30], fill=(16, 185, 129, 255))
    draw.line([(badge_x + 14, badge_y + 18), (badge_x + 19, badge_y + 23), (badge_x + 26, badge_y + 14)], fill=(255, 255, 255, 255), width=3)
    draw.text((badge_x + 160, badge_y + 18), "STEAM DECK VERIFIED", fill=(207, 181, 59, 255), anchor="mm", font_size=13)

    grid_path = ASSETS_DIR / "grid.png"
    im.save(grid_path, "PNG")
    print("Generated grid.png (920x430)")


def generate_hero():
    """Generate 1920x620 Ultra-Wide Hero Background."""
    w, h = 1920, 620
    im = Image.new("RGBA", (w, h), (10, 15, 24, 255))
    draw = ImageDraw.Draw(im)

    # Radial gradient lighting from top right and center
    for y in range(h):
        ratio = y / h
        r = int(10 + ratio * 14)
        g = int(15 + ratio * 20)
        b = int(24 + ratio * 32)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Large ambient atmospheric cyan illumination
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for r in range(400, 0, -20):
        alpha = int((1 - r / 400) * 45)
        gdraw.ellipse([1400 - r, 300 - r, 1400 + r, 300 + r], fill=(26, 159, 255, alpha))
        gdraw.ellipse([300 - r, 310 - r, 300 + r, 310 + r], fill=(0, 210, 255, alpha // 2))
    glow = glow.filter(ImageFilter.GaussianBlur(35))
    im = Image.alpha_composite(im, glow)
    draw = ImageDraw.Draw(im)

    # Technical grid lines
    grid_color = (255, 255, 255, 10)
    for x in range(0, w, 60):
        draw.line([(x, 0), (x, h)], fill=grid_color, width=1)
    for y in range(0, h, 60):
        draw.line([(0, y), (w, y)], fill=grid_color, width=1)

    # Subtle stylized Caduceus on the right
    draw_caduceus(draw, 1400, 310, scale=2.0, color=(103, 193, 245, 140))

    hero_path = ASSETS_DIR / "hero.png"
    im.save(hero_path, "PNG")
    print("Generated hero.png (1920x620)")


def generate_logo():
    """Generate 1280x720 Transparent Parallax Logo."""
    w, h = 1280, 720
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)

    # Drop shadow
    shadow_offset = 6
    draw.text((w // 2 + shadow_offset, 340 + shadow_offset), "HERMDECK", fill=(0, 0, 0, 180), anchor="mm", font_size=100)
    draw.text((w // 2 + shadow_offset, 450 + shadow_offset), "INSTALLER", fill=(0, 0, 0, 180), anchor="mm", font_size=58)

    # Crisp text
    draw.text((w // 2, 340), "HERMDECK", fill=(255, 255, 255, 255), anchor="mm", font_size=100)
    draw.text((w // 2, 450), "INSTALLER", fill=(103, 193, 245, 255), anchor="mm", font_size=58)
    draw.text((w // 2, 520), "STEAM DECK SUITE", fill=(148, 163, 184, 255), anchor="mm", font_size=24)

    # Central winged emblem above text
    draw_caduceus(draw, w // 2, 180, scale=1.1, color=(103, 193, 245, 255))

    logo_path = ASSETS_DIR / "logo.png"
    im.save(logo_path, "PNG")
    print("Generated logo.png (1280x720)")


if __name__ == "__main__":
    generate_poster()
    generate_grid()
    generate_hero()
    generate_logo()
    print("All Steam artwork assets generated successfully.")
