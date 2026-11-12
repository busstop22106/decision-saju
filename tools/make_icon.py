#!/usr/bin/env python3
"""결정사주 브랜드 이미지 생성기 (벡터 스타일 다시 그리기).

사용자 제공 브랜드 이미지의 나침반 디자인을 PIL 벡터 도형으로 다시 그립니다.
잘라낸 비트맵은 모서리가 거칠고 613px을 1024px로 늘려야 해서 화질이 떨어지므로,
도형을 직접 그려서 매끄럽고 고화질로 만듭니다. 아이콘은 4096px에서 그린 뒤
1024px로 축소(슈퍼샘플링)하고, 스플래시 카드는 2배 크기로 그립니다.

    pip3 install pillow   # Pillow가 없을 때만
    python3 tools/make_icon.py
"""
from PIL import Image, ImageDraw, ImageFont
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RED = (153, 55, 30, 255)        # #99371E 아이콘 주홍 (원본 실측)
GOLD = (220, 185, 126, 255)     # #DCB97E 나침반 금색 (원본 실측)
CREAM = (248, 242, 230, 255)    # #F8F2E6 카드 크림 (원본 실측)
PAPER = (246, 241, 227, 255)
INK = (77, 71, 59, 255)         # #4D473B 카드 제목 (원본 실측)
MUTED = (107, 101, 88, 255)
CREAM_TEXT = (255, 247, 237, 255)
DARK = (90, 80, 70, 255)        # 나침반 어두운 링
CLOUD = (239, 228, 204, 255)    # 구름 채움
NEEDLE_LIGHT = (245, 238, 221, 255)
FONT_BOLD = os.path.join(ROOT, "assets/fonts/NotoSerifKR-Bold.ttf")
FONT_REG = os.path.join(ROOT, "assets/fonts/NotoSerifKR-Regular.ttf")


def font_bold(size):
    f = ImageFont.truetype(FONT_BOLD, size)
    f.set_variation_by_axes([700])
    return f


def font_reg(size):
    f = ImageFont.truetype(FONT_REG, size)
    f.set_variation_by_axes([400])
    return f


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


def sparkle(d, cx, cy, R, r, fill):
    """4점 별."""
    pts = []
    for i in range(8):
        a = math.pi / 2 + i * math.pi / 4
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy - rad * math.sin(a)))
    d.polygon(pts, fill=fill)


def point(d, cx, cy, angle_deg, r_tip, r_base, half_w, fill):
    """나침반 뾰족점 (삼각형). angle_deg: 90=위."""
    a = math.radians(angle_deg)
    tip = (cx + r_tip * math.cos(a), cy - r_tip * math.sin(a))
    pa = a + math.pi / 2
    b1 = (cx + r_base * math.cos(a) + half_w * math.cos(pa),
          cy - r_base * math.sin(a) - half_w * math.sin(pa))
    b2 = (cx + r_base * math.cos(a) - half_w * math.cos(pa),
          cy - r_base * math.sin(a) + half_w * math.sin(pa))
    d.polygon([tip, b1, b2], fill=fill)


def gyul_glyph(target_h, fill):
    """'결' 글자를 target_h 높이에 맞게 렌더링한 이미지 반환."""
    f = font_bold(800)
    tmp = Image.new("RGBA", (1200, 1200), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    d.text((600, 600), "결", font=f, fill=fill, anchor="mm")
    g = tmp.crop(tmp.getbbox())
    s = target_h / g.size[1]
    return g.resize((round(g.size[0] * s), round(g.size[1] * s)), Image.LANCZOS)


# ================= 1. 앱 아이콘 (4096에서 그려 1024로 축소) =================
S = 4096
C = S // 2
icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(icon)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.11), fill=RED)
# 바깥 이중 링
d.ellipse([C - 1475, C - 1475, C + 1475, C + 1475], outline=GOLD, width=30)
d.ellipse([C - 1372, C - 1372, C + 1372, C + 1372], outline=GOLD, width=26)
# 안쪽 원
d.ellipse([C - 922, C - 922, C + 922, C + 922], outline=GOLD, width=26)
# 대각선 얇은 선 4개
for ang in (45, 135, 225, 315):
    a = math.radians(ang)
    d.line([(C + 950 * math.cos(a), C - 950 * math.sin(a)),
            (C + 1330 * math.cos(a), C - 1330 * math.sin(a))], fill=GOLD, width=22)
# 동서남북 뾰족점
for ang in (90, 0, 270, 180):
    point(d, C, C, ang, 1536, 922, 150, GOLD)
# 점 8개 (링 위, 22.5도 간격)
for k in range(8):
    a = math.radians(22.5 + k * 45)
    x, y = C + 1180 * math.cos(a), C - 1180 * math.sin(a)
    d.ellipse([x - 42, y - 42, x + 42, y + 42], fill=GOLD)
# 반짝이
sparkle(d, int(S * 0.16), int(S * 0.20), 150, 35, GOLD)
sparkle(d, int(S * 0.225), int(S * 0.145), 85, 20, GOLD)
sparkle(d, int(S * 0.84), int(S * 0.80), 150, 35, GOLD)
sparkle(d, int(S * 0.775), int(S * 0.855), 85, 20, GOLD)
# 가운데 도장 (금색 테두리 + 결)
seal = 1229
d.rounded_rectangle([C - seal // 2, C - seal // 2, C + seal // 2, C + seal // 2],
                    radius=150, outline=GOLD, width=45)
g = gyul_glyph(780, GOLD)
icon.alpha_composite(g, (C - g.size[0] // 2, C - g.size[1] // 2))

master = icon.resize((1024, 1024), Image.LANCZOS)
foreground = master.copy()
background = Image.new("RGBA", (1024, 1024), RED)

dens = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for name, px in dens.items():
    dd = os.path.join(ROOT, "android/app/src/main/res", f"mipmap-{name}")
    os.makedirs(dd, exist_ok=True)
    master.resize((px, px), Image.LANCZOS).save(os.path.join(dd, "ic_launcher.png"))
    foreground.resize((px, px), Image.LANCZOS).save(os.path.join(dd, "ic_launcher_foreground.png"))
    background.resize((px, px), Image.LANCZOS).save(os.path.join(dd, "ic_launcher_background.png"))
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
for fn, px in ios_files.items():
    master.resize((px, px), Image.LANCZOS).save(os.path.join(ios_dir, fn))

extra = os.path.join(ROOT, "tools/icon")
os.makedirs(extra, exist_ok=True)
master.resize((512, 512), Image.LANCZOS).save(os.path.join(extra, "play-store-icon-512.png"))
master.save(os.path.join(extra, "icon-1024-master.png"))

# ================= 2. 스플래시 카드 (2배 크기 1204x2546으로 그리기) =================
W2, H2 = 1204, 2546
card = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
d = ImageDraw.Draw(card)
d.rounded_rectangle([0, 0, W2 - 1, H2 - 1], radius=84, fill=CREAM)
# 작은 도장
ss = 360
sx = (W2 - ss) // 2
sy = 230
d.rounded_rectangle([sx, sy, sx + ss, sy + ss], radius=75, fill=RED)
g = gyul_glyph(230, CREAM_TEXT)
card.alpha_composite(g, (sx + (ss - g.size[0]) // 2, sy + (ss - g.size[1]) // 2))
# 제목 + 부제
d.text((W2 // 2, 630), "결정사주", font=fit_font(FONT_BOLD, 700, "결정사주", 150, 900),
       fill=INK, anchor="ma")
d.text((W2 // 2, 870), "중요한 결정을 위한", font=fit_font(FONT_REG, 400, "중요한 결정을 위한", 62, 900),
       fill=MUTED, anchor="ma")
d.text((W2 // 2, 950), "만세력 타이밍 플래너", font=fit_font(FONT_REG, 400, "만세력 타이밍 플래너", 62, 900),
       fill=MUTED, anchor="ma")
# 나침반
ccx, ccy = W2 // 2, 1500
d.ellipse([ccx - 430, ccy - 430, ccx + 430, ccy + 430], outline=RED, width=8)
d.ellipse([ccx - 400, ccy - 400, ccx + 400, ccy + 400], outline=GOLD, width=7)
d.ellipse([ccx - 350, ccy - 350, ccx + 350, ccy + 350], outline=DARK, width=6)
d.ellipse([ccx - 210, ccy - 210, ccx + 210, ccy + 210], outline=DARK, width=6)
# 대각선 얇은 선
for ang in (45, 135, 225, 315):
    a = math.radians(ang)
    d.line([(ccx + 230 * math.cos(a), ccy - 230 * math.sin(a)),
            (ccx + 330 * math.cos(a), ccy - 330 * math.sin(a))], fill=DARK, width=5)
# 동서남북 짧은 점 (위·아래 주홍, 좌·우 금색)
point(d, ccx, ccy, 90, 430, 330, 28, RED)
point(d, ccx, ccy, 270, 430, 330, 28, RED)
point(d, ccx, ccy, 0, 430, 330, 28, GOLD)
point(d, ccx, ccy, 180, 430, 330, 28, GOLD)
# 바늘: 북동 주홍 / 남서 밝은색
a_ne = math.radians(45)
a_sw = math.radians(225)
tip_ne = (ccx + 330 * math.cos(a_ne), ccy - 330 * math.sin(a_ne))
tip_sw = (ccx + 330 * math.cos(a_sw), ccy - 330 * math.sin(a_sw))
pa = a_ne + math.pi / 2
b1 = (ccx + 40 * math.cos(pa), ccy - 40 * math.sin(pa))
b2 = (ccx - 40 * math.cos(pa), ccy + 40 * math.sin(pa))
d.polygon([tip_ne, b1, b2], fill=RED)
d.polygon([tip_sw, b1, b2], fill=NEEDLE_LIGHT, outline=DARK)
d.ellipse([ccx - 16, ccy - 16, ccx + 16, ccy + 16], fill=CREAM, outline=DARK, width=4)
# 반짝이 (나침반 링 바깥쪽에 배치)
sparkle(d, 140, 1250, 55, 13, RED)
sparkle(d, 1050, 1130, 55, 13, GOLD)
sparkle(d, 300, 1075, 30, 8, GOLD)
sparkle(d, 1070, 1650, 50, 12, RED)


def cloud(d, cx, cy, s):
    """겹친 원으로 만든 납작한 구름. 금색 테두리를 먼저 크게 그린 뒤 크림을 덮어
    바깥쪽에만 얇은 금색 윤곽이 남게 한다 (내부 선은 안 보임)."""
    rim = 6
    for dx, dy, r in [(-0.55, 0.10, 0.42), (0, -0.18, 0.50), (0.55, 0.10, 0.42), (0, 0.12, 0.55)]:
        d.ellipse([cx + dx * s - (r * s + rim), cy + dy * s - (r * s + rim),
                   cx + dx * s + (r * s + rim), cy + dy * s + (r * s + rim)], fill=GOLD)
    for dx, dy, r in [(-0.55, 0.10, 0.42), (0, -0.18, 0.50), (0.55, 0.10, 0.42), (0, 0.12, 0.55)]:
        d.ellipse([cx + dx * s - r * s, cy + dy * s - r * s,
                   cx + dx * s + r * s, cy + dy * s + r * s], fill=CLOUD)


cloud(d, int(W2 * 0.28), 1980, 130)
cloud(d, int(W2 * 0.74), 1980, 130)
cloud(d, int(W2 * 0.58), 2130, 90)
# 하단 문구
d.text((W2 // 2, 2300), "나를 위한 의사결정 타이밍 가이드",
       font=fit_font(FONT_REG, 400, "나를 위한 의사결정 타이밍 가이드", 52, 1000),
       fill=MUTED, anchor="ma")

# 스플래시 drawable (너비 1080 기준 비율 유지) + 미리보기
cw, ch = card.size
card_w = card.resize((1080, round(1080 * ch / cw)), Image.LANCZOS)
sd = os.path.join(ROOT, "android/app/src/main/res/drawable-xxxhdpi")
os.makedirs(sd, exist_ok=True)
card_w.save(os.path.join(sd, "splash_logo.png"))
preview = Image.new("RGBA", (1080, 2340), PAPER)
pw = 810
ph = round(pw * ch / cw)
preview.alpha_composite(card.resize((pw, ph), Image.LANCZOS), ((1080 - pw) // 2, (2340 - ph) // 2))
preview.save(os.path.join(extra, "splash-preview-1080x2340.png"))

# ================= 3. 피처 그래픽 (1024x500) =================
fg_img = Image.new("RGBA", (1024, 500), PAPER)
fg_img.alpha_composite(master.resize((340, 340), Image.LANCZOS), (70, 80))
d = ImageDraw.Draw(fg_img)
t_f = fit_font(FONT_BOLD, 700, "결정사주", 110, 480)
d.text((470, 150), "결정사주", font=t_f, fill=INK, anchor="la")
tg_f = fit_font(FONT_REG, 400, "사주를 기반으로 중요한 결정을 돕습니다", 44, 500)
d.text((472, 300), "사주를 기반으로 중요한 결정을 돕습니다", font=tg_f, fill=MUTED, anchor="la")
fg_img.save(os.path.join(extra, "feature-graphic-1024x500.png"))

print("완료: 아이콘(Android mipmap 5종 + anydpi-v26 + iOS 15종 + 스토어용 512) + 스플래시 + 피처 그래픽")
