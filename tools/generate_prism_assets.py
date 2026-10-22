"""Rebuild the Prism color catalog from the portable, normative Swift palettes."""

import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
PRISM = ROOT / "apps/apple/CertigoKit/Sources/Prism"
CATALOG = PRISM / "Resources/Prism.xcassets"


def palettes():
    source = (PRISM / "PrismColors.swift").read_text(encoding="utf-8")
    for declaration, prefix in (
        ("PrismColorRole", ""), ("PrismRegion", "region."), ("PrismSyntax", "syntax.")
    ):
        body = source.split(f"public enum {declaration}:", 1)[1].split(
            "return PrismRGBA", 1
        )[0]
        for role, array in re.findall(r"case \.(\w+): values = \[(.*?)\]", body):
            values = re.findall(r"0x([0-9A-F]{6})", array)
            if len(values) != 4:
                raise ValueError(f"{declaration}.{role}: four appearances required")
            yield prefix + role, values


def contents(role, values):
    colors = []
    for index, value in enumerate(values):
        alpha = "1.000000"
        if role in ("textSecondary", "textTertiary", "separator"):
            alpha = {
                "textSecondary": (0.6, 0.8),
                "textTertiary": (0.3, 0.7),
                "separator": (0.29, 0.65),
            }[role][index >= 2]
            alpha = f"{alpha:.6f}"
        color = {
            "idiom": "universal",
            "color": {
                "color-space": "srgb",
                "components": dict(
                    zip(("red", "green", "blue"),
                        (f"0x{value[i:i+2]}" for i in (0, 2, 4))),
                    alpha=alpha,
                ),
            },
        }
        appearances = []
        if index in (1, 3):
            appearances.append({"appearance": "luminosity", "value": "dark"})
        if index >= 2:
            appearances.append({"appearance": "contrast", "value": "high"})
        if appearances:
            color["appearances"] = appearances
        colors.append(color)
    return {"colors": colors, "info": {"author": "xcode", "version": 1}}


def main():
    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8",
    )
    for role, values in palettes():
        target = CATALOG / f"{role}.colorset"
        target.mkdir(exist_ok=True)
        (target / "Contents.json").write_text(
            json.dumps(contents(role, values), indent=2) + "\n", encoding="utf-8"
        )


if __name__ == "__main__":
    main()
