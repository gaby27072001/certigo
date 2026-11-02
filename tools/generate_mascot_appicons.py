#!/usr/bin/env python3
"""Generate Any (Light #07.1) and Dark (#07.2 / #07.10) iOS 1024x1024 appiconsets for the 8 CertiGo mascot outfits."""

from __future__ import annotations

import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "apps/apple/CertigoNative/Resources/CertigoAssets.xcassets"

OUTFIT_SPECS: tuple[tuple[str, str, tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]], ...] = (
    # (icon_name, figma_prefix, shield_rgb, chest_rgb, accent_rgb)
    ("CertiGoMascotHappyActive", "01_happy_active", (0, 120, 212), (2, 132, 199), (56, 189, 248)),
    ("CertiGoMascotSadMissing", "02_sad_missing", (51, 65, 85), (30, 41, 59), (56, 189, 248)),
    ("CertiGoMascotMorningPajama", "03_morning_pajama", (0, 120, 212), (224, 242, 254), (99, 102, 241)),
    ("CertiGoMascotCoffeeBoost", "04_coffee_boost", (0, 120, 212), (146, 64, 14), (245, 158, 11)),
    ("CertiGoMascotSuitBoss", "05_suit_boss", (0, 120, 212), (15, 23, 42), (14, 165, 233)),
    ("CertiGoMascotAirplaneOffline", "06_airplane_offline", (0, 120, 212), (220, 38, 38), (56, 189, 248)),
    ("CertiGoMascotStreakFire", "07_streak_fire", (234, 88, 12), (3, 105, 161), (251, 146, 60)),
    ("CertiGoMascotPrestigePro", "08_prestige_pro", (24, 24, 27), (28, 25, 23), (251, 191, 36)),
)

FIGMA_VAULT_DIR = Path(
    r"C:\Users\gchambaud\.copilot\session-state\dfbb47ac-bbf2-47f2-8f16-5d501fea8310\files\mascot_vault_v2"
)


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def upscale_figma_png_to_1024_rgb(
    png_bytes: bytes,
    bg_rgb: tuple[int, int, int],
    target_size: int = 1024,
) -> bytes:
    """Decode an 8-bit RGBA/RGB PNG from Figma Page 16 and upscale to a 1024x1024 24-bit RGB PNG."""
    pos = 8
    w = h = bit_depth = color_type = 0
    idat_chunks: list[bytes] = []
    while pos < len(png_bytes):
        length = struct.unpack(">I", png_bytes[pos : pos + 4])[0]
        chunk_type = png_bytes[pos + 4 : pos + 8]
        chunk_data = png_bytes[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if chunk_type == b"IHDR":
            w, h, bit_depth, color_type = struct.unpack(">IIBB", chunk_data[:10])
        elif chunk_type == b"IDAT":
            idat_chunks.append(chunk_data)
        elif chunk_type == b"IEND":
            break

    bpp = 4 if color_type == 6 else 3
    stride = w * bpp
    raw = zlib.decompress(b"".join(idat_chunks))
    recon = bytearray(h * stride)

    for y in range(h):
        filter_type = raw[y * (stride + 1)]
        scan = raw[y * (stride + 1) + 1 : (y + 1) * (stride + 1)]
        row_offset = y * stride
        prev_offset = (y - 1) * stride
        for i in range(stride):
            x_byte = scan[i]
            a = recon[row_offset + i - bpp] if i >= bpp else 0
            b = recon[prev_offset + i] if y > 0 else 0
            c = recon[prev_offset + i - bpp] if (y > 0 and i >= bpp) else 0
            if filter_type == 0:
                val = x_byte
            elif filter_type == 1:
                val = (x_byte + a) & 0xFF
            elif filter_type == 2:
                val = (x_byte + b) & 0xFF
            elif filter_type == 3:
                val = (x_byte + ((a + b) >> 1)) & 0xFF
            elif filter_type == 4:
                val = (x_byte + _paeth(a, b, c)) & 0xFF
            else:
                val = x_byte
            recon[row_offset + i] = val

    # Convert source rows to composited 24-bit RGB
    src_rgb_rows: list[bytes] = []
    bg_r, bg_g, bg_b = bg_rgb
    for y in range(h):
        row_rgb = bytearray(w * 3)
        row_offset = y * stride
        for x in range(w):
            px = row_offset + x * bpp
            r = recon[px]
            g = recon[px + 1]
            b_val = recon[px + 2]
            if bpp == 4:
                alpha = recon[px + 3]
                if alpha < 255:
                    inv = 255 - alpha
                    r = (r * alpha + bg_r * inv) // 255
                    g = (g * alpha + bg_g * inv) // 255
                    b_val = (b_val * alpha + bg_b * inv) // 255
            dst = x * 3
            row_rgb[dst] = r
            row_rgb[dst + 1] = g
            row_rgb[dst + 2] = b_val
        src_rgb_rows.append(bytes(row_rgb))

    # Nearest-neighbor crisp upscaling from w x h to target_size x target_size
    x_map = [min(w - 1, (x * w) // target_size) for x in range(target_size)]
    out_rows: list[bytes] = []
    last_sy = -1
    cached_row = b""
    for ty in range(target_size):
        sy = min(h - 1, (ty * h) // target_size)
        if sy != last_sy:
            srow = src_rgb_rows[sy]
            dst_row = bytearray(1 + target_size * 3)
            dst_row[0] = 0
            for tx, sx in enumerate(x_map):
                s_idx = sx * 3
                d_idx = 1 + tx * 3
                dst_row[d_idx : d_idx + 3] = srow[s_idx : s_idx + 3]
            cached_row = bytes(dst_row)
            last_sy = sy
        out_rows.append(cached_row)

    raw_out = b"".join(out_rows)
    ihdr = struct.pack(">IIBBBBB", target_size, target_size, 8, 2, 0, 0, 0)
    compressed = zlib.compress(raw_out, level=6)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", compressed)
        + _png_chunk(b"IEND", b"")
    )


def _png_chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def render_mascot_icon_png(
    shield_rgb: tuple[int, int, int],
    chest_rgb: tuple[int, int, int],
    accent_rgb: tuple[int, int, int],
    is_dark: bool,
    is_prestige: bool,
    size: int = 1024,
) -> bytes:
    """Render a deterministic 1024x1024 24-bit RGB PNG with the CertiGo mascot anatomy."""
    if is_prestige:
        bg_rgb = (9, 9, 11) if is_dark else (28, 25, 23)
        halo_rgb = (245, 158, 11)
    elif is_dark:
        bg_rgb = (7, 20, 38)
        halo_rgb = (96, 165, 250)
    else:
        bg_rgb = (255, 255, 255)
        halo_rgb = (56, 189, 248)

    beak_rgb = (251, 191, 36)
    foot_rgb = (249, 115, 22)
    white_rgb = (255, 255, 255)
    pupil_rgb = (15, 23, 42)
    brow_rgb = (251, 191, 36) if is_prestige else (224, 242, 254)

    rows: list[bytes] = []
    cx = size // 2
    cy = size // 2

    # Precompute horizontal spans for each scanline
    for y in range(size):
        ny = y / size
        row = bytearray(1 + size * 3)
        row[0] = 0  # Filter type 0 (None)

        # Default scanline fill with background
        bg_pixel = bytes(bg_rgb)
        row[1:] = bg_pixel * size

        # Halo ring around mascot (radius 0.42..0.44)
        if 0.06 <= ny <= 0.94:
            dy = ny - 0.5
            r_outer_sq = 0.435 * 0.435 - dy * dy
            r_inner_sq = 0.415 * 0.415 - dy * dy
            if r_outer_sq > 0:
                dx_out = int((r_outer_sq ** 0.5) * size)
                if r_inner_sq > 0:
                    dx_in = int((r_inner_sq ** 0.5) * size)
                    for x in range(max(0, cx - dx_out), max(0, cx - dx_in)):
                        row[1 + x * 3 : 4 + x * 3] = halo_rgb
                    for x in range(min(size, cx + dx_in), min(size, cx + dx_out)):
                        row[1 + x * 3 : 4 + x * 3] = halo_rgb
                else:
                    x0 = max(0, cx - dx_out)
                    x1 = min(size, cx + dx_out)
                    row[1 + x0 * 3 : 1 + x1 * 3] = bytes(halo_rgb) * (x1 - x0)

        # Shield body (y: 0.16..0.84)
        if 0.16 <= ny <= 0.84:
            t = (ny - 0.16) / 0.68
            half_w = int((0.33 * (1.0 - 0.55 * (t ** 1.6)) + 0.04) * size)
            x0 = max(0, cx - half_w)
            x1 = min(size, cx + half_w)
            row[1 + x0 * 3 : 1 + x1 * 3] = bytes(shield_rgb) * (x1 - x0)

        # Centered chest plastron (y: 0.57..0.75, x: 0.32..0.68 -> clear margin inside shield!)
        if 0.57 <= ny <= 0.75:
            x0 = int(0.32 * size)
            x1 = int(0.68 * size)
            row[1 + x0 * 3 : 1 + x1 * 3] = bytes(chest_rgb) * (x1 - x0)
            if 0.62 <= ny <= 0.70:
                ax0 = int(0.45 * size)
                ax1 = int(0.55 * size)
                row[1 + ax0 * 3 : 1 + ax1 * 3] = bytes(accent_rgb) * (ax1 - ax0)

        # Sculpted eyebrow arcs strictly above eyes (y: 0.27..0.30, eyeTopY = 0.34)
        if 0.27 <= ny <= 0.30:
            for bx0, bx1 in ((0.27, 0.44), (0.56, 0.73)):
                x0 = int(bx0 * size)
                x1 = int(bx1 * size)
                row[1 + x0 * 3 : 1 + x1 * 3] = bytes(brow_rgb) * (x1 - x0)

        # Clean eyes (y: 0.34..0.47, single specular highlight)
        if 0.34 <= ny <= 0.47:
            for ex0, ex1 in ((0.29, 0.43), (0.57, 0.71)):
                x0 = int(ex0 * size)
                x1 = int(ex1 * size)
                row[1 + x0 * 3 : 1 + x1 * 3] = bytes(white_rgb) * (x1 - x0)
                if 0.365 <= ny <= 0.445:
                    px0 = int((ex0 + 0.025) * size)
                    px1 = int((ex1 - 0.025) * size)
                    row[1 + px0 * 3 : 1 + px1 * 3] = bytes(pupil_rgb) * (px1 - px0)
                    if 0.375 <= ny <= 0.40:
                        sx0 = int((ex0 + 0.035) * size)
                        sx1 = int((ex0 + 0.06) * size)
                        row[1 + sx0 * 3 : 1 + sx1 * 3] = bytes(white_rgb) * (sx1 - sx0)

        # Golden diamond beak (y: 0.46..0.54)
        if 0.46 <= ny <= 0.54:
            dist = abs(ny - 0.50) / 0.04
            bw = int(max(1, (1.0 - dist) * 0.07 * size))
            x0 = cx - bw
            x1 = cx + bw
            row[1 + x0 * 3 : 1 + x1 * 3] = bytes(beak_rgb) * (x1 - x0)

        # 100% Symmetric orange feet (y: 0.84..0.89, left: 0.33..0.45, right: 0.55..0.67)
        if 0.84 <= ny <= 0.89:
            for fx0, fx1 in ((0.33, 0.45), (0.55, 0.67)):
                x0 = int(fx0 * size)
                x1 = int(fx1 * size)
                row[1 + x0 * 3 : 1 + x1 * 3] = bytes(foot_rgb) * (x1 - x0)

        rows.append(bytes(row))

    raw_data = b"".join(rows)
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    compressed = zlib.compress(raw_data, level=6)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", compressed)
        + _png_chunk(b"IEND", b"")
    )


def main() -> None:
    CATALOG.mkdir(parents=True, exist_ok=True)
    for icon_name, figma_prefix, shield_rgb, chest_rgb, accent_rgb in OUTFIT_SPECS:
        is_prestige = icon_name == "CertiGoMascotPrestigePro"
        appiconset = CATALOG / f"{icon_name}.appiconset"
        appiconset.mkdir(parents=True, exist_ok=True)

        light_filename = f"{icon_name}.png"
        dark_filename = f"{icon_name}Dark.png"

        figma_light = FIGMA_VAULT_DIR / f"{figma_prefix}_light.png"
        figma_dark = FIGMA_VAULT_DIR / f"{figma_prefix}_dark.png"

        if figma_light.is_file():
            light_bytes = upscale_figma_png_to_1024_rgb(
                figma_light.read_bytes(),
                bg_rgb=(28, 25, 23) if is_prestige else (255, 255, 255),
            )
        else:
            light_bytes = render_mascot_icon_png(
                shield_rgb=shield_rgb,
                chest_rgb=chest_rgb,
                accent_rgb=accent_rgb,
                is_dark=False,
                is_prestige=is_prestige,
            )

        if figma_dark.is_file():
            dark_bytes = upscale_figma_png_to_1024_rgb(
                figma_dark.read_bytes(),
                bg_rgb=(9, 9, 11) if is_prestige else (7, 20, 38),
            )
        else:
            dark_bytes = render_mascot_icon_png(
                shield_rgb=shield_rgb,
                chest_rgb=chest_rgb,
                accent_rgb=accent_rgb,
                is_dark=True,
                is_prestige=is_prestige,
            )

        (appiconset / light_filename).write_bytes(light_bytes)
        (appiconset / dark_filename).write_bytes(dark_bytes)

        contents = {
            "images": [
                {
                    "filename": light_filename,
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024",
                },
                {
                    "appearances": [
                        {
                            "appearance": "luminosity",
                            "value": "dark",
                        }
                    ],
                    "filename": dark_filename,
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024",
                },
            ],
            "info": {
                "author": "xcode",
                "version": 1,
            },
        }
        (appiconset / "Contents.json").write_text(
            json.dumps(contents, indent=2) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
