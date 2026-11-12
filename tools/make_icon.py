#!/usr/bin/env python3
"""결정사주 브랜드 이미지 생성기 (앱 아이콘 + 스플래시 + 스토어 이미지).

사용자가 만든 브랜드 이미지(왼쪽 나침반 아이콘 + 오른쪽 스플래시 카드)에서
아이콘과 스플래시를 잘라내어 Android/iOS/스토어용 파일로 만듭니다.
원본 이미지는 바이너리라 저장소에 못 올리므로, 맥북에 직접 받아서 실행합니다.

    # 원본 이미지를 맥북으로 옮긴 뒤 (에어드롭 등):
    cp ~/Downloads/decision-saju-brand.png tools/icon/brand-source.png
    pip3 install pillow   # Pillow가 없을 때만
    python3 tools/make_icon.py [--source 경로]

주의: 아이콘 위치(214,458,827,1072)와 카드 검출 시드(1400,300)는
이 브랜드 이미지(2048x1529)에 맞춘 값입니다. 이미지를 새로 만들면 좌표를 다시 잡아야 합니다.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from collections import Counter, deque
import argparse
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAPER = (246, 241, 227, 255)
INK = (33, 29, 24, 255)
MUTED = (122, 114, 100, 255)
FONT_BOLD = os.path.join(ROOT, "assets/fonts/NotoSerifKR-Bold.ttf")
FONT_REG = os.path.join(ROOT, "assets/fonts/NotoSerifKR-Regular.ttf")


def shape_alpha(crop, is_content):
    """바깥 모서리에서 flood fill로 배경을 0으로, 나머지는 255로. 내부는 보존."""
    w, h = crop.size
    cp = crop.load()
    content = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if is_content(*cp[x, y][:3]):
                content[y * w + x] = 1
    outside = bytearray(w * h)
    q = deque()
    for sx, sy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if not content[sy * w + sx] and not outside[sy * w + sx]:
            outside[sy * w + sx] = 1
            q.append((sx, sy))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                i = ny * w + nx
                if not content[i] and not outside[i]:
                    outside[i] = 1
                    q.append((nx, ny))
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if outside[y * w + x]:
                ap[x, y] = 0
    return alpha.filter(ImageFilter.GaussianBlur(1.2))


def fit_font(path, weight, text, start_size, max_width):
    size = start_size
    while size > 10:
        f = ImageFont.truetype(path, size)
        try:
            f.set_variation_by_axes([weight])
        except Exception:
            pass
        w = ImageDraw.Draw(Image.new("RGBA", (10, 10))).textbbox((0, 0), text, font=f)[2]
        if w <= max_width:
            return f
        size -= 4
    return ImageFont.truetype(path, 10)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default=os.path.join(ROOT, "tools/icon/brand-source.png"))
    args = ap.parse_args()

    im = Image.open(args.source).convert("RGB")
    W, H = im.size
    px = im.load()

    # ---- 스플래시 카드 영역: 크림 마스크 + 시드에서 BFS ----
    cream = bytearray(W * H)
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            if r > 232 and g > 222 and 205 < b <= 242:
                cream[y * W + x] = 1
    seen = bytearray(W * H)
    q = deque([(1400, 300)])
    seen[300 * W + 1400] = 1
    minx, miny, maxx, maxy = W, H, 0, 0
    while q:
        x, y = q.popleft()
        minx = min(minx, x)
        maxx = max(maxx, x)
        miny = min(miny, y)
        maxy = max(maxy, y)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < W and 0 <= ny < H:
                i = ny * W + nx
                if cream[i] and not seen[i]:
                    seen[i] = 1
                    q.append((nx, ny))
    card_box = (minx, miny, maxx + 1, maxy + 1)
    print("card bbox:", card_box)

    # ---- 앱 아이콘: 왼쪽 나침반 아이콘 자르기 ----
    icon_box = (214, 458, 827, 1072)
    icon_rgb = im.crop(icon_box)
    reds = Counter()
    for r, g, b in list(icon_rgb.getdata())[::7]:
        if 120 <= r <= 205 and 25 <= g <= 105 and 10 <= b <= 85:
            reds[(r, g, b)] += 1
    icon_red = reds.most_common(1)[0][0]
    print("icon red: #%02x%02x%02x" % icon_red)

    def is_icon(r, g, b):
        return (r - g > 25) or (r - b > 60)

    def is_cream_px(r, g, b):
        return r > 232 and g > 222 and 205 < b <= 242

    icon_crop = icon_rgb.convert("RGBA")
    icon_crop.putalpha(shape_alpha(icon_crop, is_icon))
    master = icon_crop.resize((1024, 1024), Image.LANCZOS)
    foreground = master.copy()
    background = Image.new("RGBA", (1024, 1024), icon_red + (255,))

    dens = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, px_ in dens.items():
        dd = os.path.join(ROOT, "android/app/src/main/res", f"mipmap-{name}")
        os.makedirs(dd, exist_ok=True)
        master.resize((px_, px_), Image.LANCZOS).save(os.path.join(dd, "ic_launcher.png"))
        foreground.resize((px_, px_), Image.LANCZOS).save(os.path.join(dd, "ic_launcher_foreground.png"))
        background.resize((px_, px_), Image.LANCZOS).save(os.path.join(dd, "ic_launcher_background.png"))
    xd = os.path.join(ROOT, "android/app/src/main/res/mipmap-anydpi-v26")
    os.makedirs(xd, exist_ok=True)
    xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    open(os.path.join(xd, "ic_launcher.xml"), "w").write(xml)
    open(os.path.join(xd, "ic_launcher_round.xml"), "w").write(xml)

    ios_dir = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    os.makedirs(ios_dir, exist_ok=True)
    ios_files = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167, "Icon-App-1024x1024@1x.png": 1024,
    }
    for fn, px_ in ios_files.items():
        master.resize((px_, px_), Image.LANCZOS).save(os.path.join(ios_dir, fn))

    # ---- 스플래시 카드 (비율 유지) ----
    card = im.crop(card_box).convert("RGBA")
    card.putalpha(shape_alpha(card, is_cream_px))
    cw, ch = card.size
    card_w = card.resize((1080, round(1080 * ch / cw)), Image.LANCZOS)
    sd = os.path.join(ROOT, "android/app/src/main/res/drawable-xxxhdpi")
    os.makedirs(sd, exist_ok=True)
    card_w.save(os.path.join(sd, "splash_logo.png"))

    extra = os.path.join(ROOT, "tools/icon")
    os.makedirs(extra, exist_ok=True)
    preview = Image.new("RGBA", (1080, 2340), PAPER)
    pw = 810
    ph = round(pw * ch / cw)
    preview.alpha_composite(card.resize((pw, ph), Image.LANCZOS), ((1080 - pw) // 2, (2340 - ph) // 2))
    preview.save(os.path.join(extra, "splash-preview-1080x2340.png"))

    master.resize((512, 512), Image.LANCZOS).save(os.path.join(extra, "play-store-icon-512.png"))
    master.save(os.path.join(extra, "icon-1024-master.png"))

    # ---- 피처 그래픽 (1024x500, 종이 배경 + 새 아이콘 + 앱 이름) ----
    fg_img = Image.new("RGBA", (1024, 500), PAPER)
    fg_img.alpha_composite(master.resize((340, 340), Image.LANCZOS), (70, 80))
    d = ImageDraw.Draw(fg_img)
    t_f = fit_font(FONT_BOLD, 700, "결정사주", 110, 480)
    d.text((470, 150), "결정사주", font=t_f, fill=INK, anchor="la")
    tg_f = fit_font(FONT_REG, 400, "가족 사주로 결정을 돕습니다", 44, 480)
    d.text((472, 300), "가족 사주로 결정을 돕습니다", font=tg_f, fill=MUTED, anchor="la")
    fg_img.save(os.path.join(extra, "feature-graphic-1024x500.png"))

    print("완료: 아이콘(Android mipmap 5종 + anydpi-v26 + iOS 15종 + 스토어용 512) + 스플래시 + 피처 그래픽")


if __name__ == "__main__":
    main()
