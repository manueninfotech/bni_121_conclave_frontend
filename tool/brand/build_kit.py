"""Builds the 1-2-1 Connect brand kit for the marketing team.

  tool/brand/build_kit.py            (run with the Pillow + fontTools venv)

Output: store/brand-kit/ (and store/1-2-1-Connect-Brand-Kit.zip)
  01-logo/     mark, wordmark and lockups as SVG (vector) and PNG, in red, ink and white
  02-app-icon/ the store icon at 1024 / 512 / 180, plus a rounded preview
  03-colour/   palette sheet + colours.txt (HEX, RGB, CMYK)
  04-type/     Plus Jakarta Sans (SIL Open Font License)
  05-screens/  the real app screens, and the framed App Store / Play screenshots
  06-social/   ready-to-post images: link preview, Instagram posts and story, LinkedIn banner
  07-copy/     names, taglines, descriptions, boilerplate and links (copy.md)

Sources: tool/brand/mark-source.svg (the mark, vector), assets/fonts/PlusJakartaSans.ttf,
assets/branding/app_icon_1024.png, store/raw (rendered by test/store/store_screens_test.dart),
store/appstore, store/playstore (tool/store/frame.py).
"""
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "store" / "brand-kit"
FONT = ROOT / "assets" / "fonts" / "PlusJakartaSans.ttf"
RAW = ROOT / "store" / "raw"

# The palette. RED is the brand (icon, launch screen, website); the rest support it.
COLOURS = [
    ("Connect Red", "#D8061B", "Primary. Logo, app icon, hero backgrounds, the one key action."),
    ("Deep Red", "#B00E29", "Buttons and pressed states; the darker end of red gradients."),
    ("Coral", "#F04E66", "The lighter end of red gradients and the live round card. Never for text."),
    ("Ink", "#17110F", "Text and the one-colour logo."),
    ("Paper", "#FAF7F6", "Page background. Warmer than white."),
    ("Graphite", "#3A3F4A", "Secondary text, dark sections, the glass-shard pattern."),
    ("Gold", "#F4B740", "Small highlights only (a number, a badge). Never large areas."),
]
RED, DEEP, CORAL, INK, PAPER, GRAPHITE, GOLD = (c[1] for c in COLOURS)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def rgb_cmyk(rgb):
    r, g, b = (v / 255 for v in rgb)
    k = 1 - max(r, g, b)
    if k >= 1:
        return (0, 0, 0, 100)
    return tuple(round(100 * v) for v in ((1 - r - k) / (1 - k), (1 - g - k) / (1 - k), (1 - b - k) / (1 - k), k))


# ---------------------------------------------------------------- vector logo
def mark_paths():
    """The mark's shapes (shadows removed) and their tight bounds."""
    src = (Path(__file__).parent / "mark-source.svg").read_text()
    ds = re.findall(r'<path d="([^"]+)"', src)
    pen = BoundsPen(None)
    for d in ds:
        parse_path(d, pen)
    return ds, pen.bounds  # (xMin, yMin, xMax, yMax) in SVG space


def wordmark(weight_regular=600, weight_bold=800):
    """'1-2-1 Connect' as SVG path data in font units (y down), plus its size."""
    def instance(w):
        f = TTFont(FONT)
        return instantiateVariableFont(f, {"wght": w}, inplace=False)

    parts = [("1-2-1 ", instance(weight_regular)), ("Connect", instance(weight_bold))]
    upm = parts[0][1]["head"].unitsPerEm
    cap = parts[0][1]["OS/2"].sCapHeight
    track = -0.02 * upm  # matches the app and site headings
    x = 0.0
    d_all = []
    for text, font in parts:
        gs = font.getGlyphSet()
        cmap = font.getBestCmap()
        for ch in text:
            g = cmap[ord(ch)]
            pen = SVGPathPen(gs)
            gs[g].draw(TransformPen(pen, (1, 0, 0, -1, x, 0)))  # flip y; baseline at y=0
            d = pen.getCommands()
            if d:
                d_all.append(d)
            x += gs[g].width + track
    width = x - track
    return d_all, width, cap, upm


def svg_doc(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" viewBox="0 0 {w:.2f} {h:.2f}">{body}</svg>\n'


def build_logo(out):
    ds, (mx0, my0, mx1, my1) = mark_paths()
    mw, mh = mx1 - mx0, my1 - my0
    words, ww, cap, upm = wordmark()

    def mark_g(fill, x, y, height):
        s = height / mh
        paths = "".join(f'<path d="{d}"/>' for d in ds)
        return f'<g fill="{fill}" transform="translate({x:.2f} {y:.2f}) scale({s:.5f}) translate({-mx0:.2f} {-my0:.2f})">{paths}</g>'

    def word_g(fill, x, baseline, cap_px):
        s = cap_px / cap
        paths = "".join(f'<path d="{d}"/>' for d in words)
        return f'<g fill="{fill}" transform="translate({x:.2f} {baseline:.2f}) scale({s:.5f})">{paths}</g>'

    files = {}
    pad = 0.06  # clear space baked into the file edges, as a share of the height
    # Mark alone.
    for name, fill in (("red", RED), ("ink", INK), ("white", "#FFFFFF")):
        H = 1000
        W = H * mw / mh
        p = H * pad
        files[f"mark-{name}"] = svg_doc(W + 2 * p, H + 2 * p, mark_g(fill, p, p, H))
    # Wordmark alone (cap height 100).
    capp = 100
    s = capp / cap
    wwp = ww * s
    for name, fill in (("ink", INK), ("white", "#FFFFFF"), ("red", RED)):
        p = capp * 0.4
        files[f"wordmark-{name}"] = svg_doc(wwp + 2 * p, capp + 2 * p, word_g(fill, p, p + capp, capp))
    # Horizontal lockup: mark height H, wordmark cap height 0.42 H, gap 0.3 H.
    H = 300
    W_mark = H * mw / mh
    capp = 0.42 * H
    gap = 0.3 * H
    wwp = ww * capp / cap
    p = H * 0.25
    total_w = W_mark + gap + wwp
    base = p + H / 2 + capp / 2
    for name, mfill, wfill in (("colour", RED, INK), ("white", "#FFFFFF", "#FFFFFF"), ("ink", INK, INK)):
        body = mark_g(mfill, p, p, H) + word_g(wfill, p + W_mark + gap, base, capp)
        files[f"lockup-horizontal-{name}"] = svg_doc(total_w + 2 * p, H + 2 * p, body)
    # Stacked lockup: mark centred above the wordmark.
    H = 400
    W_mark = H * mw / mh
    capp = 0.3 * H
    wwp = ww * capp / cap
    gap = 0.22 * H
    W = max(W_mark, wwp)
    p = H * 0.18
    for name, mfill, wfill in (("colour", RED, INK), ("white", "#FFFFFF", "#FFFFFF"), ("ink", INK, INK)):
        body = mark_g(mfill, p + (W - W_mark) / 2, p, H) + word_g(wfill, p + (W - wwp) / 2, p + H + gap + capp, capp)
        files[f"lockup-stacked-{name}"] = svg_doc(W + 2 * p, H + gap + capp + 2 * p, body)

    svg_dir = out / "svg"
    png_dir = out / "png"
    svg_dir.mkdir(parents=True, exist_ok=True)
    png_dir.mkdir(parents=True, exist_ok=True)
    jobs = []
    for name, svg in files.items():
        (svg_dir / f"{name}.svg").write_text(svg)
        width = 2048 if name.startswith("mark") else 2400
        jobs.append({"svg": str(svg_dir / f"{name}.svg"), "out": str(png_dir / f"{name}.png"), "width": width})
    # Previews on the backgrounds each version is for.
    jobs.append({"svg": str(svg_dir / "lockup-horizontal-white.svg"), "out": str(png_dir / "preview-on-red.png"), "width": 2400, "bg": RED})
    jobs.append({"svg": str(svg_dir / "lockup-horizontal-colour.svg"), "out": str(png_dir / "preview-on-paper.png"), "width": 2400, "bg": PAPER})
    jobs.append({"svg": str(svg_dir / "lockup-horizontal-white.svg"), "out": str(png_dir / "preview-on-ink.png"), "width": 2400, "bg": INK})
    job_file = OUT / ".render-jobs.json"
    job_file.write_text(json.dumps(jobs))
    # render.mjs needs puppeteer-core; PUPPETEER_DIR is a folder where it's installed
    # (npm i puppeteer-core). The script is copied there so Node can resolve it.
    node_dir = Path(os.environ.get("PUPPETEER_DIR", ROOT))
    runner = node_dir / "brand-render.mjs"
    shutil.copy(Path(__file__).parent / "render.mjs", runner)
    try:
        subprocess.run(["node", str(runner), str(job_file)], check=True)
    finally:
        runner.unlink(missing_ok=True)
    job_file.unlink()


# --------------------------------------------------------------------- helpers
def font(size, weight=800):
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([weight])
    return f


def gradient(w, h, top=RED, bottom=DEEP):
    a, b = hex_rgb(top), hex_rgb(bottom)
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    return img


def phone(shot, width):
    raw = Image.open(RAW / f"{shot}.png").convert("RGB")
    h = int(width * raw.height / raw.width)
    screen = raw.resize((width, h), Image.LANCZOS)
    r = int(width * 0.11)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width - 1, h - 1], r, fill=255)
    b = max(6, int(width * 0.025))
    body = Image.new("RGBA", (width + 2 * b, h + 2 * b), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, body.width - 1, body.height - 1], r + b, fill=(23, 19, 26, 255))
    body.paste(screen, (b, b), mask)
    return body


def paste_shadowed(canvas, item, xy, blur=40, alpha=110):
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    m = item.getchannel("A")
    shadow = Image.new("RGBA", item.size, (40, 0, 8, alpha))
    sh.paste(shadow, (xy[0], xy[1] + blur // 2), m)
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
    canvas.alpha_composite(item, xy)


def lockup(name, width):
    im = Image.open(OUT / "01-logo" / "png" / f"{name}.png").convert("RGBA")
    return im.resize((width, int(width * im.height / im.width)), Image.LANCZOS)


def text(d, xy, s, size, weight, fill, spacing=1.08, anchor="la"):
    f = font(size, weight)
    y = xy[1]
    for line in s.split("\n"):
        d.text((xy[0], y), line, font=f, fill=fill, anchor=anchor)
        y += int(size * spacing)
    return y


# ------------------------------------------------------------------- social
def build_social(out):
    out.mkdir(parents=True, exist_ok=True)

    # Link preview (websites, WhatsApp, LinkedIn shares): 1200 x 630.
    c = gradient(1200, 630).convert("RGBA")
    c.alpha_composite(lockup("lockup-horizontal-white", 330), (48, 40))
    d = ImageDraw.Draw(c)
    text(d, (64, 220), "Every table.\nEvery round.\nEvery referral.", 62, 800, "white")
    text(d, (64, 460), "Structured 1-2-1 networking for BNI conclaves.", 26, 500, (255, 225, 228))
    paste_shadowed(c, phone("02_round", 300), (820, 120))
    c.convert("RGB").save(out / "link-preview-1200x630.png", optimize=True)

    # Instagram / Facebook post: launch.
    c = gradient(1080, 1080).convert("RGBA")
    c.alpha_composite(lockup("lockup-horizontal-white", 360), (56, 56))
    d = ImageDraw.Draw(c)
    y = text(d, (72, 260), "Your conclave,\nround by round.", 76, 800, "white")
    text(d, (72, y + 20), "Your table, a live speaking timer and\none-tap referrals, in one app.", 32, 500, (255, 225, 228), 1.35)
    paste_shadowed(c, phone("02_round", 330), (680, 470))
    text(d, (72, 980), "Available on the App Store and Google Play", 28, 700, "white")
    c.convert("RGB").save(out / "instagram-post-launch-1080.png", optimize=True)

    # Instagram post: the live round (light).
    c = Image.new("RGBA", (1080, 1080), PAPER)
    d = ImageDraw.Draw(c)
    c.alpha_composite(lockup("lockup-horizontal-colour", 300), (56, 56))
    y = text(d, (72, 250), "Know who is\nspeaking,", 80, 800, INK)
    y = text(d, (72, y), "every second.", 80, 800, RED)
    text(d, (72, y + 24), "A live timer every phone at\nthe table shares, even offline.", 32, 500, GRAPHITE, 1.35)
    paste_shadowed(c, phone("02_round", 340), (670, 430), alpha=60)
    c.convert("RGB").save(out / "instagram-post-round-1080.png", optimize=True)

    # Instagram post: referrals (dark).
    c = Image.new("RGBA", (1080, 1080), "#262A33")
    d = ImageDraw.Draw(c)
    c.alpha_composite(lockup("lockup-horizontal-white", 300), (56, 56))
    y = text(d, (72, 250), "Pass business\nin one tap.", 80, 800, "white")
    text(d, (72, y + 24), "Referrals open in the referral slot,\nright at the table.", 32, 500, (210, 214, 224), 1.35)
    paste_shadowed(c, phone("03_referral", 340), (670, 430), alpha=150)
    c.convert("RGB").save(out / "instagram-post-referral-1080.png", optimize=True)

    # Instagram / WhatsApp story: 1080 x 1920.
    c = gradient(1080, 1920).convert("RGBA")
    c.alpha_composite(lockup("lockup-stacked-white", 300), (390, 120))
    d = ImageDraw.Draw(c)
    y = text(d, (540, 560), "Every table.", 92, 800, "white", anchor="ma")
    y = text(d, (540, y), "Every round.", 92, 800, "white", anchor="ma")
    y = text(d, (540, y), "Every referral.", 92, 800, "white", anchor="ma")
    paste_shadowed(c, phone("02_round", 520), (270, 960))
    text(d, (540, 1800), "Download 1-2-1 Connect on the App Store and Google Play", 30, 700, "white", anchor="ma")
    c.convert("RGB").save(out / "story-1080x1920.png", optimize=True)

    # LinkedIn company / page banner: 1584 x 396.
    c = Image.new("RGBA", (1584, 396), PAPER)
    d = ImageDraw.Draw(c)
    d.rectangle([0, 0, 560, 396], fill=RED)
    c.alpha_composite(lockup("lockup-horizontal-white", 440), (60, 120))
    text(d, (640, 120), "Structured 1-2-1 networking\nfor BNI conclaves.", 52, 800, INK)
    text(d, (640, 268), "Seating, live rounds, referrals and follow-ups in one app.", 26, 500, GRAPHITE)
    c.convert("RGB").save(out / "linkedin-banner-1584x396.png", optimize=True)


def build_palette(out):
    out.mkdir(parents=True, exist_ok=True)
    W, H = 1800, 140 + 150 * len(COLOURS)
    c = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(c)
    text(d, (60, 50), "1-2-1 Connect colours", 44, 800, INK)
    lines = ["1-2-1 Connect colours", ""]
    for i, (name, hx, use) in enumerate(COLOURS):
        y = 140 + i * 150
        rgb = hex_rgb(hx)
        cmyk = rgb_cmyk(rgb)
        d.rounded_rectangle([60, y, 300, y + 120], 18, fill=hx, outline=(234, 227, 224))
        text(d, (340, y + 6), name, 34, 800, INK)
        text(d, (340, y + 52), f"{hx}   RGB {rgb[0]} {rgb[1]} {rgb[2]}   CMYK {cmyk[0]} {cmyk[1]} {cmyk[2]} {cmyk[3]}", 24, 600, GRAPHITE)
        text(d, (340, y + 88), use, 22, 500, GRAPHITE)
        lines += [f"{name}", f"  HEX  {hx}", f"  RGB  {rgb[0]}, {rgb[1]}, {rgb[2]}", f"  CMYK {cmyk[0]}, {cmyk[1]}, {cmyk[2]}, {cmyk[3]} (approximate; ask the printer for a proof)", f"  Use  {use}", ""]
    c.save(out / "palette.png", optimize=True)
    (out / "colours.txt").write_text("\n".join(lines))


def build_icons(out):
    out.mkdir(parents=True, exist_ok=True)
    src = Image.open(ROOT / "assets" / "branding" / "app_icon_1024.png").convert("RGB")
    for s in (1024, 512, 180):
        src.resize((s, s), Image.LANCZOS).save(out / f"app-icon-{s}.png", optimize=True)
    # Rounded preview, as phones show it (for slides and posters, not for the stores).
    mask = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 1023, 1023], 229, fill=255)
    r = src.convert("RGBA")
    r.putalpha(mask)
    r.save(out / "app-icon-rounded-preview-1024.png", optimize=True)


def build_screens(out):
    (out / "app-screens").mkdir(parents=True, exist_ok=True)
    for f in sorted(RAW.glob("*.png")):
        shutil.copy(f, out / "app-screens" / f.name)
    shutil.copytree(ROOT / "store" / "appstore" / "6.9in", out / "app-store-screenshots", dirs_exist_ok=True)
    shutil.copytree(ROOT / "store" / "playstore" / "phone", out / "google-play-screenshots", dirs_exist_ok=True)
    shutil.copy(ROOT / "store" / "playstore" / "feature_graphic.png", out / "google-play-feature-graphic-1024x500.png")


def build_type(out):
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy(FONT, out / "PlusJakartaSans-Variable.ttf")
    lic = ROOT / "website" / "node_modules" / "@fontsource-variable" / "plus-jakarta-sans" / "LICENSE"
    if lic.exists():
        shutil.copy(lic, out / "OFL-LICENSE.txt")
    (out / "README.txt").write_text(
        "Plus Jakarta Sans is the 1-2-1 Connect typeface (app, website and marketing).\n"
        "Free under the SIL Open Font License; also on Google Fonts: https://fonts.google.com/specimen/Plus+Jakarta+Sans\n\n"
        "Headlines: ExtraBold (800), tight letter-spacing (-2%).\n"
        "Subheads: Bold (700). Body: Medium (500) or Regular (400).\n"
        "The wordmark sets '1-2-1' in SemiBold (600) and 'Connect' in ExtraBold (800).\n")


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    build_logo(OUT / "01-logo")
    build_icons(OUT / "02-app-icon")
    build_palette(OUT / "03-colour")
    build_type(OUT / "04-type")
    build_screens(OUT / "05-screens")
    build_social(OUT / "06-social")
    (OUT / "07-copy").mkdir()
    shutil.copy(Path(__file__).parent / "copy.md", OUT / "07-copy" / "copy.md")
    shutil.copy(Path(__file__).parent / "README.txt", OUT / "README.txt")
    zip_path = ROOT / "store" / "1-2-1-Connect-Brand-Kit"
    shutil.make_archive(str(zip_path), "zip", OUT.parent, OUT.name)
    print("built", OUT, "and", zip_path.with_suffix(".zip"))


if __name__ == "__main__":
    main()
