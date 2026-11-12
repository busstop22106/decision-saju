#!/usr/bin/env python3
"""결정사주 앱 이미지 생성기 (아이콘 + 스플래시 + 스토어 이미지).

디자인: 한옥 클래식 — 주홍(#B3402A) 바탕 + 흰색 '결'(Noto Serif KR Bold) 도장.
앱 안 '결' 도장과 동일한 디자인입니다. AI 생성이 아니라 Python PIL로
앱에 들어 있는 실제 폰트와 테마 색상을 그대로 써서 만듭니다.

맥북에서 한 번 실행하면 모든 이미지가 제자리에 생깁니다.

    pip3 install pillow   # Pillow가 없을 때만
    python3 tools/make_icon.py

이 스크립트를 쓰는 이유: VM에서 만든 PNG는 스냅샷 푸시로 올릴 수 없어서(바이너리 불가),
폰트(assets/fonts/)와 이 스크립트만 저장소에 두고 맥북에서 생성합니다.
"""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERMILION = (179, 64, 42, 255)
PAPER = (246, 241, 227, 255)
INK = (33, 29, 24, 255)
MUTED = (122, 114, 100, 255)
CREAM = (255, 247, 237, 255)
WHITE = (255, 255, 255, 255)
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
    """텍스트가 max_width 안에 들어가도록 폰트 크기를 줄여서 반환."""
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


# ---------- 1. '결' 글리프 (600px 박스, 어댑티브 아이콘 안전 영역 안) ----------
f = font_bold(800)
tmp = Image.new("RGBA", (1200, 1200), (0, 0, 0, 0))
d = ImageDraw.Draw(tmp)
d.text((600, 600), "결", font=f, fill=WHITE, anchor="mm")
glyph = tmp.crop(tmp.getbbox())
scale = 600 / max(glyph.size)
glyph = glyph.resize((round(glyph.size[0] * scale), round(glyph.size[1] * scale)), Image.LANCZOS)


def paste_center(base, img):
    x = (base.size[0] - img.size[0]) // 2
    y = (base.size[1] - img.size[1]) // 2
    base.alpha_composite(img, (x, y))
    return base


def make_seal(size, bg=VERMILION, fg=WHITE):
    """둥근 모서리 도장: 배경색 사각형 + '결' 글자."""
    seal = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(seal)
    d.rounded_rectangle([0, 0, size, size], radius=int(size * 0.21), fill=bg)
    g = glyph.resize((int(glyph.size[0] * size * 0.78 / 600), int(glyph.size[1] * size * 0.78 / 600)), Image.LANCZOS)
    # 글리프 색상을 fg로 변경 (글리프는 흰색으로 렌더링됨)
    if fg != WHITE:
        alpha = g.split()[3]
        g = Image.new("RGBA", g.size, fg)
        g.putalpha(alpha)
    seal.alpha_composite(g, ((size - g.size[0]) // 2, (size - g.size[1]) // 2))
    return seal


# ---------- 2. 앱 아이콘 ----------
master = paste_center(Image.new("RGBA", (1024, 1024), VERMILION), glyph)
foreground = paste_center(Image.new("RGBA", (1024, 1024), (0, 0, 0, 0)), glyph)
background = Image.new("RGBA", (1024, 1024), VERMILION)

dens = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for name, px in dens.items():
    dd = os.path.join(ROOT, "android/app/src/main/res", f"mipmap-{name}")
    os.makedirs(dd, exist_ok=True)
    master.resize((px, px), Image.LANCZOS).save(os.path.join(dd, "ic_launcher.png"))
    foreground.resize((px, px), Image.LANCZOS).save(os.path.join(dd, "ic_launcher_foreground.png"))
    background.resize((px, px), Image.LANCZOS).save(os.path.join(dd, "ic_launcher_background.png"))

xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
xd = os.path.join(ROOT, "android/app/src/main/res/mipmap-anydpi-v26")
os.makedirs(xd, exist_ok=True)
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

# ---------- 3. 스플래시 ----------
# launch_background.xml에 들어가는 로고 블록 (투명 배경, 도장 + 앱 이름 + 한 줄 소개)
logo = Image.new("RGBA", (1024, 1000), (0, 0, 0, 0))
seal = make_seal(520)
logo.alpha_composite(seal, ((1024 - 520) // 2, 0))
d = ImageDraw.Draw(logo)
title_f = fit_font(FONT_BOLD, 700, "결정사주", 150, 900)
d.text((512, 640), "결정사주", font=title_f, fill=INK, anchor="ma")
tag_f = fit_font(FONT_REG, 400, "가족 사주로 결정을 돕습니다", 62, 900)
d.text((512, 810), "가족 사주로 결정을 돕습니다", font=tag_f, fill=MUTED, anchor="ma")
dd = os.path.join(ROOT, "android/app/src/main/res/drawable-xxxhdpi")
os.makedirs(dd, exist_ok=True)
logo.save(os.path.join(dd, "splash_logo.png"))

# 스플래시 전체 화면 미리보기 (1080x1920, 종이 배경 + 로고 블록 중앙)
preview = Image.new("RGBA", (1080, 1920), PAPER)
preview.alpha_composite(logo, ((1080 - 1024) // 2, (1920 - 1000) // 2))
preview.save(os.path.join(extra, "splash-preview-1080x1920.png"))

# ---------- 4. 피처 그래픽 (Play 스토어 상단 배너, 1024x500) ----------
fg_img = Image.new("RGBA", (1024, 500), PAPER)
fg_img.alpha_composite(make_seal(340), (70, 80))
d = ImageDraw.Draw(fg_img)
t_f = fit_font(FONT_BOLD, 700, "결정사주", 110, 480)
d.text((470, 150), "결정사주", font=t_f, fill=INK, anchor="la")
tg_f = fit_font(FONT_REG, 400, "가족 사주로 결정을 돕습니다", 44, 480)
d.text((472, 300), "가족 사주로 결정을 돕습니다", font=tg_f, fill=MUTED, anchor="la")
fg_img.save(os.path.join(extra, "feature-graphic-1024x500.png"))

print("완료: 아이콘(Android mipmap 5종 + anydpi-v26 + iOS 15종 + 스토어용 512) + 스플래시 + 피처 그래픽")
