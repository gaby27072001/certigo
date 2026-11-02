#!/usr/bin/env python3
"""Deterministic App Store Connect marketing screenshot generator for CertiGo.

Generates 6 high-conversion, strictly minimalist (Page 17/18 Figma style) marketing
slides in French (fr-FR) and English (en-US) across Apple's required iPhone and iPad
resolutions as 24-bit RGB PNGs (no alpha channel / no transparency):

- iPhone 6.9" (APP_IPHONE_67): 1320x2868 and 1290x2796
- iPhone 6.5" (APP_IPHONE_65): 1284x2778
- iPhone 6.3" (APP_IPHONE_61): 1206x2622
- iPad Pro 13" (APP_IPAD_PRO_3GEN_129): 2064x2752 and 2048x2732
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
PRISM_ASSETS = ROOT / "apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets"
NATIVE_ASSETS = ROOT / "apps/apple/CertigoNative/Resources/CertigoAssets.xcassets"

RESOLUTIONS: dict[str, tuple[int, int]] = {
    "iphone_69_1320x2868": (1320, 2868),
    "iphone_67_1290x2796": (1290, 2796),
    "iphone_65_1284x2778": (1284, 2778),
    "iphone_61_1206x2622": (1206, 2622),
    "ipad_13_2064x2752": (2064, 2752),
    "ipad_129_2048x2732": (2048, 2732),
}

SLIDE_THEMES = [
    {
        "slug": "01_parcours_34x",
        "bg_top": (6, 19, 44),
        "bg_bottom": (10, 37, 78),
        "accent": (14, 165, 233),
        "badge_bg": (12, 42, 82),
        "fr": {"badge": "N°1 CLOUD & IA", "title": "Certifié 3,4×\nplus vite."},
        "en": {"badge": "#1 CLOUD & AI", "title": "Get certified\n3.4× faster."},
    },
    {
        "slug": "02_cartes_declic",
        "bg_top": (4, 28, 24),
        "bg_bottom": (7, 52, 43),
        "accent": (16, 185, 129),
        "badge_bg": (8, 56, 46),
        "fr": {"badge": "CARTES DÉCLIC 15S", "title": "L'architecture Cloud\nen 15 secondes."},
        "en": {"badge": "15S VISUAL CARDS", "title": "Cloud architecture\nin 15 seconds."},
    },
    {
        "slug": "03_cloud_shell_cli",
        "bg_top": (13, 15, 38),
        "bg_bottom": (25, 28, 68),
        "accent": (99, 102, 241),
        "badge_bg": (28, 31, 78),
        "fr": {"badge": "CLOUD SHELL CLI", "title": "Vrai Terminal\nCloud Shell."},
        "en": {"badge": "CLOUD SHELL CLI", "title": "Real Cloud Shell\nTerminal."},
    },
    {
        "slug": "04_coach_ia_examen",
        "bg_top": (24, 12, 48),
        "bg_bottom": (44, 20, 86),
        "accent": (168, 85, 247),
        "badge_bg": (48, 24, 92),
        "fr": {"badge": "COACH IA & EXAMEN", "title": "Coach IA &\nExamen Blanc."},
        "en": {"badge": "AI COACH & EXAM", "title": "AI Coach &\nMock Exam."},
    },
    {
        "slug": "05_widgets_mascotte",
        "bg_top": (28, 19, 8),
        "bg_bottom": (48, 31, 11),
        "accent": (245, 158, 11),
        "badge_bg": (56, 36, 12),
        "fr": {"badge": "WIDGETS & MASCOTTE", "title": "Une habitude\nsur mesure."},
        "en": {"badge": "WIDGETS & MASCOT", "title": "Build a daily\nhabit."},
    },
    {
        "slug": "06_catalogue_multicloud",
        "bg_top": (5, 24, 38),
        "bg_bottom": (9, 46, 70),
        "accent": (56, 189, 248),
        "badge_bg": (12, 52, 78),
        "fr": {"badge": "+15 CERTIFICATIONS", "title": "Azure, AWS, GCP,\nKubernetes & IA."},
        "en": {"badge": "15+ CERTIFICATIONS", "title": "Azure, AWS, GCP,\nKubernetes & AI."},
    },
]


def load_font(size: int, bold: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont:
    candidates = (
        ["C:/Windows/Fonts/consolab.ttf", "C:/Windows/Fonts/consola.ttf"]
        if mono
        else (
            [
                "C:/Windows/Fonts/segoeuib.ttf",
                "C:/Windows/Fonts/arialbd.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            ]
            if bold
            else [
                "C:/Windows/Fonts/seguisb.ttf",
                "C:/Windows/Fonts/segoeui.ttf",
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            ]
        )
    )
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def load_asset_image(
    rel_path: Path,
    size: tuple[int, int],
    rounded_mask: bool = False,
) -> Image.Image | None:
    if not rel_path.exists():
        return None
    img = Image.open(rel_path).convert("RGBA").resize(size, Image.Resampling.LANCZOS)
    if rounded_mask:
        mask = Image.new("L", size, 0)
        mdraw = ImageDraw.Draw(mask)
        pad = max(2, size[0] // 18)
        mdraw.rounded_rectangle(
            [pad, pad, size[0] - pad, size[1] - pad],
            radius=int(size[0] * 0.26),
            fill=255,
        )
        out = Image.new("RGBA", size, (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        return out
    return img


def draw_play_triangle(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    r: int,
    color: tuple[int, int, int] = (255, 255, 255),
) -> None:
    draw.polygon(
        [(cx - int(r * 0.6), cy - r), (cx - int(r * 0.6), cy + r), (cx + r, cy)],
        fill=color,
    )


def draw_arrow_right(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    r: int,
    color: tuple[int, int, int] = (255, 255, 255),
) -> None:
    w = max(3, r // 3)
    draw.line([(cx - r, cy), (cx + r // 2, cy)], fill=color, width=w)
    draw.polygon(
        [(cx + r, cy), (cx + int(r * 0.15), cy - int(r * 0.7)), (cx + int(r * 0.15), cy + int(r * 0.7))],
        fill=color,
    )


def draw_chevron_down(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    r: int,
    color: tuple[int, int, int] = (15, 23, 42),
) -> None:
    w = max(3, r // 2)
    draw.line([(cx - r, cy - r // 2), (cx, cy + r // 2), (cx + r, cy - r // 2)], fill=color, width=w)


def make_vertical_gradient(
    width: int,
    height: int,
    top_rgb: tuple[int, int, int],
    bottom_rgb: tuple[int, int, int],
    accent_rgb: tuple[int, int, int],
) -> Image.Image:
    base = Image.new("RGB", (width, height), top_rgb)
    draw = ImageDraw.Draw(base)
    for y in range(height):
        t = y / max(1, height - 1)
        r = int(top_rgb[0] * (1 - t) + bottom_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bottom_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bottom_rgb[2] * t)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    # Subtle radial glow behind phone/tablet header
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cx, cy = width // 2, int(height * 0.24)
    rx, ry = int(width * 0.44), int(height * 0.18)
    gdraw.ellipse(
        [cx - rx, cy - ry, cx + rx, cy + ry],
        fill=(accent_rgb[0], accent_rgb[1], accent_rgb[2], 46),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=max(24, width // 18)))
    comp = Image.alpha_composite(base.convert("RGBA"), glow)
    return comp.convert("RGB")


def draw_heart(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int, color: tuple[int, int, int]) -> None:
    draw.ellipse([cx - r, cy - r, cx, cy], fill=color)
    draw.ellipse([cx, cy - r, cx + r, cy], fill=color)
    draw.polygon([(cx - r, cy - r // 3), (cx + r, cy - r // 3), (cx, cy + r)], fill=color)


def draw_flame(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    draw.polygon([(cx, cy - r), (cx + r, cy + r // 3), (cx, cy + r), (cx - r, cy + r // 3)], fill=(249, 115, 22))
    draw.ellipse([cx - int(r * 0.7), cy - int(r * 0.2), cx + int(r * 0.7), cy + r], fill=(251, 146, 60))
    draw.ellipse([cx - int(r * 0.35), cy + int(r * 0.1), cx + int(r * 0.35), cy + int(r * 0.85)], fill=(253, 224, 71))


def draw_gem(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    draw.polygon(
        [(cx - r // 2, cy - r), (cx + r // 2, cy - r), (cx + r, cy - r // 4), (cx, cy + r), (cx - r, cy - r // 4)],
        fill=(56, 189, 248),
    )


def draw_check_circle(
    draw: ImageDraw.ImageDraw,
    cx: int,
    cy: int,
    r: int,
    bg: tuple[int, int, int],
    fg: tuple[int, int, int] = (255, 255, 255),
) -> None:
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=bg)
    w = max(3, r // 4)
    draw.line([(cx - r // 2, cy), (cx - r // 8, cy + r // 2), (cx + r // 2, cy - r // 3)], fill=fg, width=w)


def draw_badge_icon(draw: ImageDraw.ImageDraw, slide_idx: int, cx: int, cy: int, r: int, accent: tuple[int, int, int]) -> None:
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=accent)
    w = max(3, r // 4)
    if slide_idx == 0:
        # Star/Trophy spark
        draw.polygon([(cx, cy - r // 2), (cx + r // 2, cy), (cx, cy + r // 2), (cx - r // 2, cy)], fill=(255, 255, 255))
    elif slide_idx == 1:
        # Lightning bolt
        draw.polygon(
            [(cx + r // 6, cy - r // 2), (cx - r // 2, cy + r // 8), (cx, cy + r // 8), (cx - r // 6, cy + r // 2), (cx + r // 2, cy - r // 8), (cx, cy - r // 8)],
            fill=(255, 255, 255),
        )
    elif slide_idx == 2:
        # Terminal >_
        draw.line([(cx - r // 2, cy - r // 3), (cx - r // 8, cy), (cx - r // 2, cy + r // 3)], fill=(255, 255, 255), width=w)
        draw.line([(cx, cy + r // 3), (cx + r // 2, cy + r // 3)], fill=(255, 255, 255), width=w)
    elif slide_idx == 3:
        # Sparkle diamond
        draw.polygon([(cx, cy - int(r * 0.6)), (cx + int(r * 0.6), cy), (cx, cy + int(r * 0.6)), (cx - int(r * 0.6), cy)], fill=(255, 255, 255))
    elif slide_idx == 4:
        # Flame
        draw.polygon([(cx, cy - int(r * 0.6)), (cx + int(r * 0.5), cy + int(r * 0.3)), (cx, cy + int(r * 0.6)), (cx - int(r * 0.5), cy + int(r * 0.3))], fill=(255, 255, 255))
    else:
        # Grid / Globe
        draw.ellipse([cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2], outline=(255, 255, 255), width=w)


def paste_rgba(canvas: Image.Image, overlay: Image.Image | None, pos: tuple[int, int]) -> None:
    if overlay is None:
        return
    canvas.paste(overlay, pos, overlay)


def draw_bottom_tab_bar(
    draw: ImageDraw.ImageDraw,
    mx: int,
    my: int,
    mw: int,
    mh: int,
    s: float,
    active_idx: int,
    locale: str,
) -> None:
    bar_h = int(130 * s)
    bar_y = my + mh - bar_h - int(26 * s)
    bar_x = mx + int(32 * s)
    bar_w = mw - int(64 * s)
    draw.rounded_rectangle(
        [bar_x, bar_y, bar_x + bar_w, bar_y + bar_h],
        radius=int(65 * s),
        fill=(255, 255, 255),
        outline=(226, 232, 240),
        width=max(2, int(3 * s)),
    )
    labels = (
        ["Parcours", "Examens", "Coach IA", "Ligue", "Moi"]
        if locale == "fr-FR"
        else ["Path", "Exams", "AI Coach", "League", "Profile"]
    )
    f_tab = load_font(int(24 * s), bold=True)
    slot_w = bar_w // 5
    for idx, label in enumerate(labels):
        cx = bar_x + idx * slot_w + slot_w // 2
        cy = bar_y + bar_h // 2
        if idx == 2:
            r = int(44 * s)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(14, 165, 233), outline=(56, 189, 248), width=max(2, int(4 * s)))
            draw.polygon([(cx, cy - int(20 * s)), (cx + int(20 * s), cy), (cx, cy + int(20 * s)), (cx - int(20 * s), cy)], fill=(255, 255, 255))
            continue
        is_active = idx == active_idx
        if is_active:
            draw.rounded_rectangle(
                [cx - int(78 * s), bar_y + int(12 * s), cx + int(78 * s), bar_y + bar_h - int(12 * s)],
                radius=int(48 * s),
                fill=(239, 246, 255),
            )
        fg = (2, 132, 199) if is_active else (100, 116, 139)
        ir = int(16 * s)
        draw.ellipse([cx - ir, cy - int(28 * s) - ir, cx + ir, cy - int(28 * s) + ir], outline=fg, width=max(2, int(4 * s)))
        bbox = draw.textbbox((0, 0), label, font=f_tab)
        tw = bbox[2] - bbox[0]
        draw.text((cx - tw // 2, cy + int(8 * s)), label, font=f_tab, fill=fg)

    # Home indicator
    hi_w = int(280 * s)
    hi_y = my + mh - int(14 * s)
    draw.rounded_rectangle(
        [mx + (mw - hi_w) // 2, hi_y - int(5 * s), mx + (mw + hi_w) // 2, hi_y + int(5 * s)],
        radius=int(5 * s),
        fill=(15, 23, 42),
    )


def render_slide_content(
    canvas: Image.Image,
    draw: ImageDraw.ImageDraw,
    slide_idx: int,
    locale: str,
    mx: int,
    my: int,
    mw: int,
    mh: int,
    s: float,
    accent: tuple[int, int, int],
) -> None:
    is_fr = locale == "fr-FR"
    pad = int(42 * s)
    content_x = mx + pad
    content_w = mw - 2 * pad
    cur_y = my + int(124 * s)

    f_h2 = load_font(int(40 * s), bold=True)
    f_card = load_font(int(33 * s), bold=True)
    f_sub = load_font(int(27 * s), bold=False)
    f_mono = load_font(int(29 * s), mono=True)
    f_pill = load_font(int(25 * s), bold=True)

    # Top status pills row (Track selector + Streak / Gems / 5 Hearts)
    pill_h = int(78 * s)
    left_w = int(content_w * 0.38)
    right_w = content_w - left_w - int(20 * s)
    rx = content_x + left_w + int(20 * s)

    draw.rounded_rectangle(
        [content_x, cur_y, content_x + left_w, cur_y + pill_h],
        radius=pill_h // 2,
        fill=(255, 255, 255),
        outline=(226, 232, 240),
        width=max(2, int(3 * s)),
    )
    # Microsoft 4-square mini icon
    sq = int(14 * s)
    sx0 = content_x + int(28 * s)
    sy0 = cur_y + (pill_h - 2 * sq - int(4 * s)) // 2
    draw.rectangle([sx0, sy0, sx0 + sq, sy0 + sq], fill=(242, 80, 34))
    draw.rectangle([sx0 + sq + int(4 * s), sy0, sx0 + 2 * sq + int(4 * s), sy0 + sq], fill=(127, 186, 0))
    draw.rectangle([sx0, sy0 + sq + int(4 * s), sx0 + sq, sy0 + 2 * sq + int(4 * s)], fill=(0, 164, 239))
    draw.rectangle([sx0 + sq + int(4 * s), sy0 + sq + int(4 * s), sx0 + 2 * sq + int(4 * s), sy0 + 2 * sq + int(4 * s)], fill=(255, 185, 0))
    draw.text((sx0 + int(46 * s), cur_y + int(18 * s)), "AZ-104", font=f_card, fill=(15, 23, 42))
    draw_chevron_down(draw, content_x + left_w - int(42 * s), cur_y + pill_h // 2 + int(2 * s), int(10 * s), (71, 85, 105))

    draw.rounded_rectangle(
        [rx, cur_y, rx + right_w, cur_y + pill_h],
        radius=pill_h // 2,
        fill=(255, 255, 255),
        outline=(226, 232, 240),
        width=max(2, int(3 * s)),
    )
    draw_flame(draw, rx + int(44 * s), cur_y + pill_h // 2, int(16 * s))
    draw.text((rx + int(68 * s), cur_y + int(18 * s)), "14", font=f_card, fill=(234, 88, 12))
    draw_gem(draw, rx + int(168 * s), cur_y + pill_h // 2, int(15 * s))
    draw.text((rx + int(192 * s), cur_y + int(18 * s)), "480", font=f_card, fill=(2, 132, 199))
    draw_heart(draw, rx + int(312 * s), cur_y + pill_h // 2 + int(2 * s), int(15 * s), (239, 68, 68))
    draw.text((rx + int(336 * s), cur_y + int(18 * s)), "5", font=f_card, fill=(220, 38, 38))

    cur_y += pill_h + int(32 * s)

    if slide_idx == 0:
        # SLIDE 1: Real CertiGo Parcours 01 (Sinuous 3D cushions + Mascot Pro v2 + 1-click Sprint CTA)
        ub_h = int(112 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + ub_h], radius=ub_h // 2, fill=(0, 98, 184))
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + ub_h - int(8 * s)], radius=ub_h // 2, fill=(2, 132, 199))
        draw.ellipse([content_x + int(18 * s), cur_y + int(16 * s), content_x + int(90 * s), cur_y + int(88 * s)], outline=(125, 211, 252), width=max(3, int(5 * s)))
        draw.text((content_x + int(30 * s), cur_y + int(36 * s)), "65%", font=f_pill, fill=(255, 255, 255))
        unit_txt = "UNITÉ 1 · Identité Entra ID" if is_fr else "UNIT 1 · Entra ID Identity"
        draw.text((content_x + int(112 * s), cur_y + int(32 * s)), unit_txt, font=f_card, fill=(255, 255, 255))
        cur_y += ub_h + int(42 * s)

        # Orthogonal green/blue path connectors
        n1_x, n1_y = content_x + int(90 * s), cur_y
        n2_x, n2_y = content_x + content_w - int(250 * s), cur_y + int(225 * s)
        n3_x, n3_y = content_x + int(90 * s), cur_y + int(460 * s)
        box_sz = int(166 * s)

        # Rail lines
        rail_w = max(8, int(22 * s))
        c1 = (n1_x + box_sz // 2, n1_y + box_sz // 2)
        c2 = (n2_x + box_sz // 2, n2_y + box_sz // 2)
        c3 = (n3_x + box_sz // 2, n3_y + box_sz // 2)
        draw.line([c1, (c1[0], c2[1]), c2], fill=(101, 196, 20), width=rail_w)
        draw.line([c2, (c2[0], c3[1]), c3], fill=(101, 196, 20), width=rail_w)

        nodes = [
            (n1_x, n1_y, (101, 196, 20), "Concepts Cloud Azure" if is_fr else "Azure Cloud Concepts", True, False),
            (n2_x, n2_y, (101, 196, 20), "Identité Entra ID" if is_fr else "Entra ID Identity", True, True),
            (n3_x, n3_y, (2, 132, 199), "Rôles RBAC & PIM" if is_fr else "RBAC Roles & PIM", False, False),
        ]
        for nx, ny, col, title, done, left_label in nodes:
            draw.rounded_rectangle([nx, ny + int(10 * s), nx + box_sz, ny + box_sz + int(10 * s)], radius=int(44 * s), fill=col)
            draw.rounded_rectangle([nx, ny, nx + box_sz, ny + box_sz], radius=int(44 * s), fill=(255, 255, 255), outline=col, width=max(4, int(8 * s)))
            # Inner emblem
            cx_n, cy_n = nx + box_sz // 2, ny + box_sz // 2
            draw.polygon([(cx_n, cy_n - int(36 * s)), (cx_n + int(36 * s), cy_n), (cx_n, cy_n + int(36 * s)), (cx_n - int(36 * s), cy_n)], fill=col)
            if done:
                draw_check_circle(draw, nx + box_sz - int(14 * s), ny + int(14 * s), int(24 * s), (101, 196, 20))
            else:
                # CONTINUER pill above node 3
                pill_txt = "CONTINUER" if is_fr else "CONTINUE"
                draw.rounded_rectangle([nx - int(12 * s), ny - int(58 * s), nx + box_sz + int(26 * s), ny - int(8 * s)], radius=int(25 * s), fill=(2, 132, 199))
                draw.text((nx + int(18 * s), ny - int(48 * s)), pill_txt, font=f_pill, fill=(255, 255, 255))

            tx = (nx - int(380 * s)) if left_label else (nx + box_sz + int(28 * s))
            tb_lbl = draw.textbbox((0, 0), title, font=f_h2)
            lw = (tb_lbl[2] - tb_lbl[0]) + int(44 * s)
            lh_pill = int(76 * s)
            ly = ny + (box_sz - lh_pill) // 2
            draw.rounded_rectangle(
                [tx - int(22 * s), ly, tx - int(22 * s) + lw, ly + lh_pill],
                radius=lh_pill // 2,
                fill=(255, 255, 255),
                outline=(226, 232, 240) if done else (2, 132, 199),
                width=max(2, int(3 * s)),
            )
            draw.text((tx, ly + int(14 * s)), title, font=f_h2, fill=(2, 132, 199) if not done else (15, 23, 42))

        # Paste Master Mascot Pro v2 on right of Node 3
        mascot_img = load_asset_image(
            PRISM_ASSETS / "Mascots/mascot-pose-01-presenter.imageset/mascot-pose-01-presenter.png",
            (int(250 * s), int(250 * s)),
        )
        paste_rgba(canvas, mascot_img, (content_x + content_w - int(248 * s), n3_y - int(32 * s)))

        cur_y = n3_y + box_sz + int(44 * s)
        # Clean 1-line Mini-Lab Card
        lab_h = int(128 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + lab_h], radius=int(32 * s), fill=(255, 255, 255), outline=(203, 213, 225), width=max(2, int(4 * s)))
        draw.rounded_rectangle([content_x + int(24 * s), cur_y + int(18 * s), content_x + int(270 * s), cur_y + int(54 * s)], radius=int(18 * s), fill=(243, 232, 255))
        draw.text((content_x + int(38 * s), cur_y + int(22 * s)), "MINI-LAB PRATIQUE" if is_fr else "HANDS-ON MINI-LAB", font=f_pill, fill=(126, 34, 206))
        draw.text((content_x + int(24 * s), cur_y + int(66 * s)), "Réparer un accès RBAC refusé" if is_fr else "Fix a denied RBAC role assignment", font=f_card, fill=(15, 23, 42))
        draw.rounded_rectangle([content_x + content_w - int(116 * s), cur_y + int(22 * s), content_x + content_w - int(28 * s), cur_y + lab_h - int(22 * s)], radius=int(24 * s), fill=(124, 58, 237))
        draw_play_triangle(draw, content_x + content_w - int(72 * s), cur_y + lab_h // 2, int(18 * s), (255, 255, 255))

        cur_y += lab_h + int(26 * s)
        # Clean 1-line Tactile Haptic Card
        hap_h = int(106 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + hap_h], radius=int(28 * s), fill=(240, 249, 255), outline=(14, 165, 233), width=max(2, int(4 * s)))
        draw_check_circle(draw, content_x + int(50 * s), cur_y + hap_h // 2, int(22 * s), (14, 165, 233))
        draw.text(
            (content_x + int(92 * s), cur_y + int(30 * s)),
            "Boutons 3D & Vibrations Core Haptics" if is_fr else "3D Cushions & Core Haptics Vibrations",
            font=f_card,
            fill=(15, 23, 42),
        )

        cur_y += hap_h + int(28 * s)
        # 1-Click Primary CTA
        cta_h = int(110 * s)
        draw.rounded_rectangle([content_x, cur_y + int(8 * s), content_x + content_w, cur_y + cta_h + int(8 * s)], radius=int(30 * s), fill=(3, 105, 161))
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + cta_h], radius=int(30 * s), fill=(14, 165, 233))
        cta_txt = "LANCER MON SPRINT (10 MIN)" if is_fr else "START DAILY SPRINT (10 MIN)"
        bbox = draw.textbbox((0, 0), cta_txt, font=f_card)
        tw = bbox[2] - bbox[0]
        tx0 = content_x + (content_w - tw) // 2 + int(18 * s)
        draw_play_triangle(draw, tx0 - int(34 * s), cur_y + cta_h // 2, int(16 * s), (255, 255, 255))
        draw.text((tx0, cur_y + int(32 * s)), cta_txt, font=f_card, fill=(255, 255, 255))

        draw_bottom_tab_bar(draw, mx, my, mw, mh, s, 0, locale)

    elif slide_idx == 1:
        # SLIDE 2: 15-Second Visual Insight Cards (3-brick schema + 1-line cards)
        draw.text((content_x, cur_y), "Carte Déclic · Verrous Azure" if is_fr else "Visual Card · Azure Resource Locks", font=f_h2, fill=(15, 23, 42))
        cur_y += int(72 * s)

        # 3-Brick Visual Diagram Card
        diag_h = int(196 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + diag_h], radius=int(34 * s), fill=(15, 23, 42))
        bw = (content_w - int(112 * s)) // 3
        bricks = [
            ("Mgmt Group", (56, 189, 248)),
            ("Subscription", (99, 102, 241)),
            ("RG [Lock]", (16, 185, 129)),
        ]
        for idx, (btitle, bcol) in enumerate(bricks):
            bx = content_x + int(24 * s) + idx * (bw + int(32 * s))
            by = cur_y + int(32 * s)
            bh = diag_h - int(64 * s)
            draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=int(24 * s), fill=(30, 41, 59), outline=bcol, width=max(2, int(4 * s)))
            bbox = draw.textbbox((0, 0), btitle, font=f_pill)
            draw.text((bx + (bw - (bbox[2] - bbox[0])) // 2, by + (bh - (bbox[3] - bbox[1])) // 2 - int(4 * s)), btitle, font=f_pill, fill=(255, 255, 255))
            if idx < 2:
                ax = bx + bw + int(16 * s)
                ay = by + bh // 2
                draw_arrow_right(draw, ax, ay, int(10 * s), (148, 163, 184))

        cur_y += diag_h + int(32 * s)

        # 5 Strictly 1-Line Cards (Page 17 style)
        cards = (
            [
                ((16, 185, 129), (236, 253, 245), "Piège d'examen · 68 % d'erreurs"),
                ((2, 132, 199), (240, 249, 255), "CanNotDelete bloque toute suppression"),
                ((124, 58, 237), (245, 243, 255), "Même Owner doit retirer le verrou d'abord"),
                ((245, 158, 11), (255, 251, 235), "Héritage automatique sur les sous-ressources"),
                ((234, 88, 12), (255, 247, 237), "Retour haptique & +20 XP validés"),
            ]
            if is_fr
            else [
                ((16, 185, 129), (236, 253, 245), "Exam trap spotted · 68% miss rate"),
                ((2, 132, 199), (240, 249, 255), "CanNotDelete blocks any resource deletion"),
                ((124, 58, 237), (245, 243, 255), "Even Owner must remove the lock first"),
                ((245, 158, 11), (255, 251, 235), "Automatically inherited by child resources"),
                ((234, 88, 12), (255, 247, 237), "Tactile haptic feedback & +20 XP earned"),
            ]
        )
        ch = int(124 * s)
        for col, bg_col, text in cards:
            draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + ch], radius=int(28 * s), fill=bg_col, outline=col, width=max(2, int(4 * s)))
            draw_check_circle(draw, content_x + int(52 * s), cur_y + ch // 2, int(24 * s), col)
            draw.text((content_x + int(96 * s), cur_y + int(38 * s)), text, font=f_card, fill=(15, 23, 42))
            cur_y += ch + int(24 * s)

        mascot_img = load_asset_image(
            PRISM_ASSETS / "Mascots/mascot-emotion-03-aha-idea.imageset/mascot-emotion-03-aha-idea.png",
            (int(215 * s), int(215 * s)),
        )
        paste_rgba(canvas, mascot_img, (content_x + content_w - int(215 * s), cur_y - int(8 * s)))

        cta_y = cur_y + int(42 * s)
        cta_w = content_w - int(235 * s)
        draw.rounded_rectangle([content_x, cta_y + int(8 * s), content_x + cta_w, cta_y + int(112 * s) + int(8 * s)], radius=int(28 * s), fill=(5, 150, 105))
        draw.rounded_rectangle([content_x, cta_y, content_x + cta_w, cta_y + int(112 * s)], radius=int(28 * s), fill=(16, 185, 129))
        draw.text((content_x + int(42 * s), cta_y + int(32 * s)), "COMPRIS · QUESTION" if is_fr else "GOT IT · PRACTICE", font=f_card, fill=(255, 255, 255))
        draw_arrow_right(draw, content_x + cta_w - int(58 * s), cta_y + int(56 * s), int(16 * s), (255, 255, 255))

        draw_bottom_tab_bar(draw, mx, my, mw, mh, s, 0, locale)

    elif slide_idx == 2:
        # SLIDE 3: Interactive Cloud Shell CLI Terminal
        draw.text((content_x, cur_y), "Lab CLI · Azure Cloud Shell" if is_fr else "CLI Lab · Azure Cloud Shell", font=f_h2, fill=(15, 23, 42))
        cur_y += int(72 * s)

        term_h = int(320 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + term_h], radius=int(32 * s), fill=(15, 23, 42), outline=(99, 102, 241), width=max(2, int(4 * s)))
        # macOS traffic lights
        for idx, dot_col in enumerate([(239, 68, 68), (245, 158, 11), (16, 185, 129)]):
            dx = content_x + int(32 * s) + idx * int(28 * s)
            dy = cur_y + int(28 * s)
            draw.ellipse([dx, dy, dx + int(16 * s), dy + int(16 * s)], fill=dot_col)
        draw.text((content_x + int(130 * s), cur_y + int(20 * s)), "bash — cloud-shell", font=f_pill, fill=(148, 163, 184))
        draw.text((content_x + int(32 * s), cur_y + int(84 * s)), "$ az lock create \\", font=f_mono, fill=(56, 189, 248))
        draw.text((content_x + int(32 * s), cur_y + int(142 * s)), "  --lock-type CanNotDelete \\", font=f_mono, fill=(167, 243, 208))
        draw.text((content_x + int(32 * s), cur_y + int(200 * s)), "  --name LockProd -g RG-Prod", font=f_mono, fill=(226, 232, 240))
        draw.text((content_x + int(32 * s), cur_y + int(256 * s)), "{ \"level\": \"CanNotDelete\", \"status\": \"Succeeded\" }", font=load_font(int(23 * s), mono=True), fill=(52, 211, 153))
        cur_y += term_h + int(30 * s)

        # Interactive CLI token pills row
        pills = ["CanNotDelete", "--resource-group", "ReadOnly"]
        px = content_x
        ph = int(84 * s)
        for idx, ptxt in enumerate(pills):
            pw = int((content_w - int(32 * s)) // 3)
            active_p = idx == 0
            draw.rounded_rectangle(
                [px, cur_y, px + pw, cur_y + ph],
                radius=int(24 * s),
                fill=(238, 242, 255) if active_p else (248, 250, 252),
                outline=(99, 102, 241) if active_p else (203, 213, 225),
                width=max(2, int(4 * s)),
            )
            bbox = draw.textbbox((0, 0), ptxt, font=f_pill)
            draw.text((px + (pw - (bbox[2] - bbox[0])) // 2, cur_y + int(26 * s)), ptxt, font=f_pill, fill=(67, 56, 202) if active_p else (71, 85, 105))
            px += pw + int(16 * s)
        cur_y += ph + int(30 * s)

        # 3 Single-line Feedback Cards
        rows = (
            [
                ((16, 185, 129), (236, 253, 245), "Verrou 'LockProd' créé · +25 XP"),
                ((99, 102, 241), (238, 242, 255), "Autocomplétion Azure CLI, PowerShell & Kubectl"),
                ((234, 88, 12), (255, 247, 237), "Combo ×3 · Vibration haptique validée"),
            ]
            if is_fr
            else [
                ((16, 185, 129), (236, 253, 245), "Lock 'LockProd' created · +25 XP"),
                ((99, 102, 241), (238, 242, 255), "Azure CLI, PowerShell & Kubectl smart tokens"),
                ((234, 88, 12), (255, 247, 237), "Combo ×3 · Tactile haptic confirmed"),
            ]
        )
        ch = int(124 * s)
        for col, bg_col, txt in rows:
            draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + ch], radius=int(28 * s), fill=bg_col, outline=col, width=max(2, int(4 * s)))
            draw_check_circle(draw, content_x + int(52 * s), cur_y + ch // 2, int(24 * s), col)
            draw.text((content_x + int(96 * s), cur_y + int(38 * s)), txt, font=f_card, fill=(15, 23, 42))
            cur_y += ch + int(24 * s)

        mascot_img = load_asset_image(
            PRISM_ASSETS / "Mascots/mascot-pose-05-cli-coder.imageset/mascot-pose-05-cli-coder.png",
            (int(215 * s), int(215 * s)),
        )
        paste_rgba(canvas, mascot_img, (content_x + content_w - int(215 * s), cur_y - int(8 * s)))

        cta_y = cur_y + int(42 * s)
        cta_w = content_w - int(235 * s)
        draw.rounded_rectangle([content_x, cta_y + int(8 * s), content_x + cta_w, cta_y + int(112 * s) + int(8 * s)], radius=int(28 * s), fill=(67, 56, 202))
        draw.rounded_rectangle([content_x, cta_y, content_x + cta_w, cta_y + int(112 * s)], radius=int(28 * s), fill=(79, 70, 229))
        draw.text((content_x + int(42 * s), cta_y + int(32 * s)), "EXÉCUTER LE SCRIPT" if is_fr else "RUN CLI COMMAND", font=f_card, fill=(255, 255, 255))
        draw_arrow_right(draw, content_x + cta_w - int(58 * s), cta_y + int(56 * s), int(16 * s), (255, 255, 255))

        draw_bottom_tab_bar(draw, mx, my, mw, mh, s, 0, locale)

    elif slide_idx == 3:
        # SLIDE 4: AI Coach & Official Mock Exam (/1000)
        draw.text((content_x, cur_y), "Simulateur /1000 & Coach IA" if is_fr else "Exam Simulator /1000 & AI Coach", font=f_h2, fill=(15, 23, 42))
        cur_y += int(72 * s)

        # Score /1000 Hero Card
        sc_h = int(164 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + sc_h], radius=int(32 * s), fill=(24, 12, 48), outline=(168, 85, 247), width=max(2, int(4 * s)))
        draw.text((content_x + int(36 * s), cur_y + int(34 * s)), "840 / 1000", font=load_font(int(54 * s), bold=True), fill=(255, 255, 255))
        badge_pass = "PRÊT EXAMEN" if is_fr else "EXAM READY"
        draw.rounded_rectangle([content_x + content_w - int(268 * s), cur_y + int(44 * s), content_x + content_w - int(32 * s), cur_y + int(118 * s)], radius=int(37 * s), fill=(16, 185, 129))
        draw.text((content_x + content_w - int(236 * s), cur_y + int(64 * s)), badge_pass, font=f_pill, fill=(255, 255, 255))
        cur_y += sc_h + int(28 * s)

        # 3 Clean 1-line Domain Progress Bars
        domains = (
            [
                ("Identité & Gouvernance", 0.88, "88 %", (16, 185, 129)),
                ("Réseaux VNet & Sécurité", 0.82, "82 %", (14, 165, 233)),
                ("Stockage & Calcul", 0.79, "79 %", (168, 85, 247)),
            ]
            if is_fr
            else [
                ("Identity & Governance", 0.88, "88%", (16, 185, 129)),
                ("VNet Networking & Security", 0.82, "82%", (14, 165, 233)),
                ("Storage & Compute", 0.79, "79%", (168, 85, 247)),
            ]
        )
        dh = int(116 * s)
        for dname, ratio, pct, dcol in domains:
            draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + dh], radius=int(26 * s), fill=(255, 255, 255), outline=(226, 232, 240), width=max(2, int(3 * s)))
            draw.text((content_x + int(28 * s), cur_y + int(20 * s)), dname, font=f_sub, fill=(15, 23, 42))
            draw.text((content_x + content_w - int(110 * s), cur_y + int(20 * s)), pct, font=f_card, fill=dcol)
            bx0, by0 = content_x + int(28 * s), cur_y + int(74 * s)
            bw_tot = content_w - int(56 * s)
            draw.rounded_rectangle([bx0, by0, bx0 + bw_tot, by0 + int(20 * s)], radius=int(10 * s), fill=(241, 245, 249))
            draw.rounded_rectangle([bx0, by0, bx0 + int(bw_tot * ratio), by0 + int(20 * s)], radius=int(10 * s), fill=dcol)
            cur_y += dh + int(22 * s)

        # 2 Single-line AI Coach & Haptic Cards
        ai_cards = (
            [
                ((147, 51, 234), (245, 243, 255), "Coach IA : RBAC (Qui) vs Azure Policy (Quoi)"),
                ((16, 185, 129), (236, 253, 245), "Célébration haptique · Seuil 700+ validé"),
            ]
            if is_fr
            else [
                ((147, 51, 234), (245, 243, 255), "AI Coach: RBAC (Who) vs Azure Policy (What)"),
                ((16, 185, 129), (236, 253, 245), "Haptic celebration · 700+ pass threshold"),
            ]
        )
        ai_h = int(116 * s)
        for acol, abg, atxt in ai_cards:
            draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + ai_h], radius=int(28 * s), fill=abg, outline=acol, width=max(2, int(4 * s)))
            draw_check_circle(draw, content_x + int(52 * s), cur_y + ai_h // 2, int(24 * s), acol)
            draw.text((content_x + int(96 * s), cur_y + int(34 * s)), atxt, font=f_card, fill=(15, 23, 42))
            cur_y += ai_h + int(20 * s)

        mascot_img = load_asset_image(
            PRISM_ASSETS / "Mascots/mascot-spec-06-ai-coach.imageset/mascot-spec-06-ai-coach.png",
            (int(205 * s), int(205 * s)),
        )
        paste_rgba(canvas, mascot_img, (content_x + content_w - int(205 * s), cur_y - int(8 * s)))

        cta_y = cur_y + int(36 * s)
        cta_w = content_w - int(225 * s)
        draw.rounded_rectangle([content_x, cta_y + int(8 * s), content_x + cta_w, cta_y + int(108 * s) + int(8 * s)], radius=int(28 * s), fill=(107, 33, 168))
        draw.rounded_rectangle([content_x, cta_y, content_x + cta_w, cta_y + int(108 * s)], radius=int(28 * s), fill=(147, 51, 234))
        draw.text((content_x + int(36 * s), cta_y + int(30 * s)), "ÉPINGLER AU CARNET" if is_fr else "SAVE TO NOTEBOOK", font=f_card, fill=(255, 255, 255))
        draw_arrow_right(draw, content_x + cta_w - int(54 * s), cta_y + int(54 * s), int(16 * s), (255, 255, 255))

        draw_bottom_tab_bar(draw, mx, my, mw, mh, s, 1, locale)

    elif slide_idx == 4:
        # SLIDE 5: iOS Widgets & 8 Mascot Outfits Vault
        draw.text((content_x, cur_y), "Widget iOS & Mascotte Pro v2" if is_fr else "iOS Widget & Mascot Pro v2", font=f_h2, fill=(15, 23, 42))
        cur_y += int(68 * s)

        # iOS Home Screen Widget Card
        w_h = int(228 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + w_h], radius=int(36 * s), fill=(15, 23, 42), outline=(245, 158, 11), width=max(2, int(4 * s)))
        w_mascot = load_asset_image(
            NATIVE_ASSETS / "CertiGoMascotStreakFire.appiconset/CertiGoMascotStreakFireDark.png",
            (int(122 * s), int(122 * s)),
            rounded_mask=True,
        )
        paste_rgba(canvas, w_mascot, (content_x + int(28 * s), cur_y + int(24 * s)))
        draw.text((content_x + int(172 * s), cur_y + int(28 * s)), "CERTIGO · WIDGET iOS", font=f_pill, fill=(251, 191, 36))
        draw.text((content_x + int(172 * s), cur_y + int(70 * s)), "Série : 14 jours actifs" if is_fr else "Streak: 14 active days", font=f_h2, fill=(255, 255, 255))
        draw.rounded_rectangle([content_x + int(28 * s), cur_y + int(160 * s), content_x + content_w - int(28 * s), cur_y + int(206 * s)], radius=int(23 * s), fill=(2, 132, 199))
        w_btn = "Lancer mon Sprint (3 min) en 1 clic" if is_fr else "Start 3-min Sprint in 1 tap"
        bbox = draw.textbbox((0, 0), w_btn, font=f_pill)
        tw = bbox[2] - bbox[0]
        tx0 = content_x + (content_w - tw) // 2 + int(14 * s)
        draw_play_triangle(draw, tx0 - int(24 * s), cur_y + int(183 * s), int(11 * s), (255, 255, 255))
        draw.text((tx0, cur_y + int(167 * s)), w_btn, font=f_pill, fill=(255, 255, 255))
        cur_y += w_h + int(26 * s)

        # 1-Line 90s Rescue Card
        r_h = int(114 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + r_h], radius=int(28 * s), fill=(255, 251, 235), outline=(245, 158, 11), width=max(2, int(4 * s)))
        draw_check_circle(draw, content_x + int(50 * s), cur_y + r_h // 2, int(22 * s), (245, 158, 11))
        draw.text((content_x + int(92 * s), cur_y + int(34 * s)), "Mode Sauvetage 90s (3 cartes Flash)" if is_fr else "90s Streak Rescue (3 Flash cards)", font=f_card, fill=(15, 23, 42))
        cur_y += r_h + int(26 * s)

        # 2x2 Grid of Real Pro v2 Mascot Outfits (with clean rounded-rect icon masks!)
        outfits = [
            ("CertiGoMascotMorningPajama.appiconset/CertiGoMascotMorningPajama.png", "Matin · Pyjama" if is_fr else "Morning · Pajama"),
            ("CertiGoMascotCoffeeBoost.appiconset/CertiGoMascotCoffeeBoost.png", "Pause · Café" if is_fr else "Focus · Coffee"),
            ("CertiGoMascotSuitBoss.appiconset/CertiGoMascotSuitBoss.png", "Mode Examen" if is_fr else "Exam Suit"),
            ("CertiGoMascotPrestigePro.appiconset/CertiGoMascotPrestigeProDark.png", "Prestige Or #10" if is_fr else "Prestige Gold #10"),
        ]
        cell_w = (content_w - int(24 * s)) // 2
        cell_h = int(236 * s)
        for idx, (rel_icon, olabel) in enumerate(outfits):
            gx = content_x + (idx % 2) * (cell_w + int(24 * s))
            gy = cur_y + (idx // 2) * (cell_h + int(22 * s))
            draw.rounded_rectangle([gx, gy, gx + cell_w, gy + cell_h], radius=int(30 * s), fill=(255, 255, 255), outline=(226, 232, 240), width=max(2, int(3 * s)))
            icon_img = load_asset_image(NATIVE_ASSETS / rel_icon, (int(142 * s), int(142 * s)), rounded_mask=True)
            paste_rgba(canvas, icon_img, (gx + (cell_w - int(142 * s)) // 2, gy + int(18 * s)))
            bbox = draw.textbbox((0, 0), olabel, font=f_pill)
            draw.text((gx + (cell_w - (bbox[2] - bbox[0])) // 2, gy + int(176 * s)), olabel, font=f_pill, fill=(15, 23, 42))

        cur_y += 2 * cell_h + int(48 * s)
        # 1-Line Live Activity & Haptics Card
        lh = int(112 * s)
        draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + lh], radius=int(28 * s), fill=(240, 249, 255), outline=(14, 165, 233), width=max(2, int(4 * s)))
        draw_check_circle(draw, content_x + int(50 * s), cur_y + lh // 2, int(22 * s), (14, 165, 233))
        draw.text(
            (content_x + int(92 * s), cur_y + int(33 * s)),
            "Dynamic Island & Retours Haptiques" if is_fr else "Dynamic Island & Tactile Haptics",
            font=f_card,
            fill=(15, 23, 42),
        )

        draw_bottom_tab_bar(draw, mx, my, mw, mh, s, 4, locale)

    else:
        # SLIDE 6: Multi-Cloud Official Catalog (+15 Certifications)
        draw.text((content_x, cur_y), "+15 Certifications Officielles" if is_fr else "15+ Official Certifications", font=f_h2, fill=(15, 23, 42))
        cur_y += int(68 * s)

        certs = [
            ("tech-azure-administrator.imageset/tech-azure-administrator.png", "AZ-104"),
            ("tech-azure-fundamentals.imageset/tech-azure-fundamentals.png", "AZ-900"),
            ("tech-aws-solutions-architect.imageset/tech-aws-solutions-architect.png", "SAA-C03"),
            ("tech-cka.imageset/tech-cka.png", "CKA K8s"),
            ("tech-gcp-cloud-architect.imageset/tech-gcp-cloud-architect.png", "GCP PCA"),
            ("tech-github-copilot.imageset/tech-github-copilot.png", "GH-300"),
            ("tech-terraform-associate.imageset/tech-terraform-associate.png", "Terraform"),
            ("tech-anthropic-cca-foundations.imageset/tech-anthropic-cca-foundations.png", "Claude AI"),
        ]
        cols = 4
        gap = int(18 * s)
        cw = (content_w - (cols - 1) * gap) // cols
        ch_grid = int(202 * s)
        for idx, (cpath, clabel) in enumerate(certs):
            gx = content_x + (idx % cols) * (cw + gap)
            gy = cur_y + (idx // cols) * (ch_grid + gap)
            draw.rounded_rectangle([gx, gy, gx + cw, gy + ch_grid], radius=int(26 * s), fill=(255, 255, 255), outline=(226, 232, 240), width=max(2, int(3 * s)))
            cimg = load_asset_image(PRISM_ASSETS / "Certifications" / cpath, (int(108 * s), int(108 * s)))
            paste_rgba(canvas, cimg, (gx + (cw - int(108 * s)) // 2, gy + int(20 * s)))
            bbox = draw.textbbox((0, 0), clabel, font=f_pill)
            draw.text((gx + (cw - (bbox[2] - bbox[0])) // 2, gy + int(144 * s)), clabel, font=f_pill, fill=(15, 23, 42))

        cur_y += 2 * ch_grid + gap + int(32 * s)

        # 4 Single-line Progression Cards
        rows = (
            [
                ((14, 165, 233), (240, 249, 255), "Chapitre 1 : 2 / 10 tampons offerts (20 %)"),
                ((16, 185, 129), (236, 253, 245), "Défi Promo : 845 / 1 000 concepts validés"),
                ((168, 85, 247), (245, 243, 255), "Carnet Personnel Jour-J en 1 clic"),
                ((245, 158, 11), (255, 251, 235), "Mode Hors-Ligne & Synchronisation iCloud"),
            ]
            if is_fr
            else [
                ((14, 165, 233), (240, 249, 255), "Chapter 1: 2 / 10 stamps gifted (20%)"),
                ((16, 185, 129), (236, 253, 245), "Squad Goal: 845 / 1,000 concepts mastered"),
                ((168, 85, 247), (245, 243, 255), "1-Tap Exam-Day Personal Notebook"),
                ((245, 158, 11), (255, 251, 235), "Offline Packs & Multi-Device Sync"),
            ]
        )
        rh = int(116 * s)
        for col, bg_col, txt in rows:
            draw.rounded_rectangle([content_x, cur_y, content_x + content_w, cur_y + rh], radius=int(28 * s), fill=bg_col, outline=col, width=max(2, int(4 * s)))
            draw_check_circle(draw, content_x + int(50 * s), cur_y + rh // 2, int(22 * s), col)
            draw.text((content_x + int(92 * s), cur_y + int(34 * s)), txt, font=f_card, fill=(15, 23, 42))
            cur_y += rh + int(20 * s)

        draw_bottom_tab_bar(draw, mx, my, mw, mh, s, 3, locale)


def render_marketing_slide(
    slide_idx: int,
    locale: str,
    width: int,
    height: int,
) -> Image.Image:
    theme = SLIDE_THEMES[slide_idx]
    copy = theme["fr"] if locale == "fr-FR" else theme["en"]
    accent = theme["accent"]

    canvas = make_vertical_gradient(width, height, theme["bg_top"], theme["bg_bottom"], accent)
    draw = ImageDraw.Draw(canvas)

    is_ipad = width / height > 0.65
    s = (height / 2868.0) * (0.94 if is_ipad else 1.0)

    # Outer glowing frame
    frame_m = int(28 * s)
    draw.rounded_rectangle(
        [frame_m, frame_m, width - frame_m, height - frame_m],
        radius=int(72 * s),
        outline=accent,
        width=max(3, int(5 * s)),
    )

    # 1. Short Top Pill Badge (Strictly minimalist: 2-3 words)
    header_x = int(96 * s) if not is_ipad else int(width * 0.12)
    badge_y = int(104 * s)
    badge_h = int(76 * s)
    f_badge = load_font(int(30 * s), bold=True)
    tb = draw.textbbox((0, 0), copy["badge"], font=f_badge)
    badge_w = (tb[2] - tb[0]) + int(124 * s)

    draw.rounded_rectangle(
        [header_x, badge_y, header_x + badge_w, badge_y + badge_h],
        radius=badge_h // 2,
        fill=theme["badge_bg"],
        outline=accent,
        width=max(2, int(4 * s)),
    )
    draw_badge_icon(draw, slide_idx, header_x + int(44 * s), badge_y + badge_h // 2, int(22 * s), accent)
    draw.text((header_x + int(82 * s), badge_y + int(18 * s)), copy["badge"], font=f_badge, fill=(255, 255, 255))

    # 2. Big 3-to-5 Word Headline (Zero subtitle paragraph!)
    f_title = load_font(int(88 * s) if not is_ipad else int(82 * s), bold=True)
    title_y = badge_y + badge_h + int(34 * s)
    draw.multiline_text(
        (header_x, title_y),
        copy["title"],
        font=f_title,
        fill=(255, 255, 255),
        spacing=int(14 * s),
    )

    # 3. Device Mockup Frame (iPhone Dynamic Island or iPad Pro 13")
    mx = int(84 * s) if not is_ipad else int(width * 0.12)
    mw = width - 2 * mx
    my = int(495 * s)
    mh = height - my - int(76 * s)

    # Outer Titanium Bezel + Screen Surface
    bezel = int(18 * s)
    draw.rounded_rectangle(
        [mx - bezel, my - bezel, mx + mw + bezel, my + mh + bezel],
        radius=int(108 * s),
        fill=(30, 41, 59),
        outline=accent,
        width=max(3, int(5 * s)),
    )
    draw.rounded_rectangle(
        [mx, my, mx + mw, my + mh],
        radius=int(92 * s),
        fill=(244, 247, 251),
    )

    # iOS Status Bar + Dynamic Island
    f_status = load_font(int(30 * s), bold=True)
    draw.text((mx + int(68 * s), my + int(34 * s)), "9:41", font=f_status, fill=(15, 23, 42))
    draw.text((mx + mw - int(198 * s), my + int(34 * s)), "5G 100%", font=f_status, fill=(15, 23, 42))
    di_w = int(280 * s)
    di_h = int(62 * s)
    draw.rounded_rectangle(
        [mx + (mw - di_w) // 2, my + int(24 * s), mx + (mw + di_w) // 2, my + int(24 * s) + di_h],
        radius=di_h // 2,
        fill=(15, 23, 42),
    )

    # Render Slide Screen Content
    render_slide_content(canvas, draw, slide_idx, locale, mx, my, mw, mh, s, accent)

    # Guarantee 24-bit RGB without alpha channel
    return canvas.convert("RGB")


def generate_all(output_dir: Path, resolutions: list[str] | None = None) -> dict:
    selected = resolutions or list(RESOLUTIONS.keys())
    manifest: dict[str, dict[str, list[dict[str, str | int]]]] = {}

    for locale in ("fr-FR", "en-US"):
        manifest[locale] = {}
        for res_key in selected:
            w, h = RESOLUTIONS[res_key]
            target_dir = output_dir / locale / res_key
            target_dir.mkdir(parents=True, exist_ok=True)
            manifest[locale][res_key] = []

            for idx, theme in enumerate(SLIDE_THEMES):
                img = render_marketing_slide(idx, locale, w, h)
                assert img.mode == "RGB", f"Expected RGB mode, got {img.mode}"
                assert img.size == (w, h), f"Expected {(w, h)}, got {img.size}"
                filename = f"{locale}_{res_key}_{theme['slug']}.png"
                out_path = target_dir / filename
                img.save(out_path, format="PNG", optimize=True)
                manifest[locale][res_key].append(
                    {
                        "slide": idx + 1,
                        "slug": theme["slug"],
                        "filename": filename,
                        "width": w,
                        "height": h,
                        "mode": img.mode,
                        "bytes": out_path.stat().st_size,
                    }
                )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / "apps/apple/fastlane/screenshots/generated",
        help="Output directory for generated PNGs.",
    )
    parser.add_argument(
        "--manifest-out",
        type=Path,
        default=ROOT / "apps/apple/fastlane/screenshots/manifest.json",
        help="Path to write JSON manifest.",
    )
    parser.add_argument(
        "--resolutions",
        nargs="*",
        choices=list(RESOLUTIONS.keys()),
        default=None,
        help="Optional subset of resolutions to generate.",
    )
    args = parser.parse_args()
    manifest = generate_all(args.output, args.resolutions)
    args.manifest_out.parent.mkdir(parents=True, exist_ok=True)
    args.manifest_out.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    total = sum(len(v) for loc in manifest.values() for v in loc.values())
    print(f"Generated {total} 24-bit RGB screenshots across {len(manifest)} locales.")


if __name__ == "__main__":
    main()
