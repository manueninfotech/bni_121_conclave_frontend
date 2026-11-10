"""Frames the raw app screens (store/raw, rendered by
test/store/store_screens_test.dart) into store listing screenshots.

  python tool/store/frame.py

Writes:
  store/appstore/6.9in/NN.png   1320 x 2868  (App Store, iPhone 6.9")
  store/appstore/6.5in/NN.png   1284 x 2778  (App Store, iPhone 6.5")
  store/playstore/phone/NN.png  1080 x 1920  (Google Play phone)
  store/playstore/feature_graphic.png 1024 x 500
  store/playstore/icon_512.png  512 x 512
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "store" / "raw"
FONT = ROOT / "assets" / "fonts" / "PlusJakartaSans.ttf"

RED_TOP = (216, 6, 27)
RED_BOTTOM = (150, 8, 30)

# Order shown in the stores, with the headline + one supporting line.
SHOTS = [
    ("02_round", "Know who is speaking,\nevery second", "Live timer, speaking order and each person's ask"),
    ("03_referral", "Pass business\nin one tap", "Give referrals right at the table"),
    ("01_home", "Your conclave day\nat a glance", "Your table, your impact, your next step"),
    ("06_summary", "See what\nyou built", "Referrals, rounds and everyone you met"),
    ("04_conclaves", "Find and join\nconclaves", "Register for the next one in seconds"),
    ("07_people", "Never lose\na contact", "Save everyone you met to your phone"),
    ("05_detail", "Everything about\nthe day", "Venue, timings and how the rounds work"),
    ("08_card", "Share your card\nwith a scan", "A QR code with your contact details"),
]


def font(size, weight="ExtraBold"):
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def gradient(w, h):
    img = Image.new("RGB", (w, h), RED_TOP)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(RED_TOP[i] + (RED_BOTTOM[i] - RED_TOP[i]) * t) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    # A soft light bloom top-right, for depth.
    bloom = Image.new("L", (w, h), 0)
    ImageDraw.Draw(bloom).ellipse([w * 0.35, -h * 0.25, w * 1.5, h * 0.35], fill=70)
    bloom = bloom.filter(ImageFilter.GaussianBlur(w * 0.12))
    img.paste(Image.new("RGB", (w, h), (255, 120, 130)), (0, 0), bloom)
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def frame(raw, title, sub, w, h):
    canvas = gradient(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    s = w / 1320  # scale everything off the 6.9" layout

    # Headline block.
    top = int(150 * s * (h / w) / (2868 / 1320))
    tf = font(int(104 * s))
    sf = font(int(46 * s), "Medium")
    y = top
    for line in title.split("\n"):
        tw = d.textlength(line, font=tf)
        d.text(((w - tw) / 2, y), line, font=tf, fill="white")
        y += int(122 * s)
    y += int(18 * s)
    tw = d.textlength(sub, font=sf)
    d.text(((w - tw) / 2, y), sub, font=sf, fill=(255, 225, 228))
    y += int(110 * s)

    # The screen: scaled to fit the space left, in a white bezel.
    avail_h = h - y + int(260 * s)  # bleed off the bottom like a phone rising
    scr_w = int(w * 0.78)
    scr_h = int(scr_w * raw.height / raw.width)
    if scr_h > avail_h * 1.15:
        scr_h = int(avail_h * 1.15)
        scr_w = int(scr_h * raw.width / raw.height)
    screen = raw.convert("RGB").resize((scr_w, scr_h), Image.LANCZOS)
    radius = int(scr_w * 0.11)
    bezel = int(scr_w * 0.028)
    bw, bh = scr_w + bezel * 2, scr_h + bezel * 2
    x0 = (w - bw) // 2
    y0 = y

    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x0, y0 + int(30 * s), x0 + bw, y0 + bh + int(30 * s)], radius + bezel, fill=(40, 0, 8, 140)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(40 * s)))
    canvas.alpha_composite(shadow)

    body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, bw - 1, bh - 1], radius + bezel, fill=(24, 20, 22, 255))
    body.alpha_composite(rounded(screen, radius), (bezel, bezel))
    canvas.alpha_composite(body, (x0, y0))
    return canvas.convert("RGB")


def main():
    targets = {
        ROOT / "store" / "appstore" / "6.9in": (1320, 2868),
        ROOT / "store" / "appstore" / "6.5in": (1284, 2778),
        ROOT / "store" / "playstore" / "phone": (1080, 1920),
    }
    for out, (w, h) in targets.items():
        out.mkdir(parents=True, exist_ok=True)
        for i, (name, title, sub) in enumerate(SHOTS, 1):
            raw = Image.open(RAW / f"{name}.png")
            frame(raw, title, sub, w, h).save(out / f"{i:02d}_{name[3:]}.png", optimize=True)

    play = ROOT / "store" / "playstore"
    # Feature graphic: brand gradient, mark, name, line.
    fg = gradient(1024, 500)
    d = ImageDraw.Draw(fg)
    mark = Image.open(ROOT / "assets" / "images" / "app_mark_white.png").convert("RGBA")
    mark.thumbnail((170, 170))
    fg.paste(mark, (90, (500 - mark.height) // 2), mark)
    d.text((300, 160), "1-2-1 Connect", font=font(76), fill="white")
    d.text((302, 262), "Structured 1-2-1 networking\nfor BNI conclaves", font=font(34, "Medium"), fill=(255, 225, 228), spacing=10)
    fg.save(play / "feature_graphic.png", optimize=True)

    Image.open(ROOT / "assets" / "branding" / "app_icon_1024.png").convert("RGB").resize(
        (512, 512), Image.LANCZOS
    ).save(play / "icon_512.png", optimize=True)
    print("done")


if __name__ == "__main__":
    main()
