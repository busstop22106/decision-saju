#!/usr/bin/env python3
"""결정사주 앱 아이콘 생성기.

주홍(#B3402A) 바탕 + 흰색 '결'(Noto Serif KR Bold) 도장 디자인.
맥북에서 한 번 실행하면 Android/iOS 아이콘 파일이 제자리에 생깁니다.

    pip3 install pillow   # Pillow가 없을 때만
    python3 tools/make_icon.py

이 스크립트를 쓰는 이유: VM에서 만든 PNG는 스냅샷 푸시로 올릴 수 없어서(바이너리 불가),
폰트(assets/fonts/)와 이 스크립트만 저장소에 두고 맥북에서 생성합니다.
"""
from PIL import Image, ImageDraw, ImageFont
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERMILION = (179, 64, 42, 255)
WHITE = (255, 255, 255, 255)
FONT = os.path.join(ROOT, "assets/fonts/NotoSerifKR-Bold.ttf")

# 1. '결' 글리프 렌더링 후 600px 박스에 맞게 조정 (어댑티브 아이콘 안전 영역 안)
f = ImageFont.truetype(FONT, 800)
f.set_variation_by_axes([700])
tmp = Image.new("RGBA", (1200, 1200), (0, 0, 0, 0))
d = ImageDraw.Draw(tmp)
d.text((600, 600), "결", font=f, fill=WHITE, anchor="mm")
glyph = tmp.crop(tmp.getbbox())
scale = 600 / max(glyph.size)
glyph = glyph.resize((round(glyph.size[0] * scale), round(glyph.size[1] * scale)), Image.LANCZOS)


def paste_center(base, glyph_img):
    x = (base.size[0] - glyph_img.size[0]) // 2
    y = (base.size[1] - glyph_img.size[1]) // 2
    base.alpha_composite(glyph_img, (x, y))
    return base


master = paste_center(Image.new("RGBA", (1024, 1024), VERMILION), glyph)
foreground = paste_center(Image.new("RGBA", (1024, 1024), (0, 0, 0, 0)), glyph)
background = Image.new("RGBA", (1024, 1024), VERMILION)

# 2. Android: 레거시 아이콘 + 어댑티브 아이콘(전경/배경) + anydpi-v26 XML
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

# 3. iOS AppIcon (Contents.json의 파일명 그대로)
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

# 4. 스토어 등록정보용 512 + 마스터 원본
extra = os.path.join(ROOT, "tools/icon")
os.makedirs(extra, exist_ok=True)
master.resize((512, 512), Image.LANCZOS).save(os.path.join(extra, "play-store-icon-512.png"))
master.save(os.path.join(extra, "icon-1024-master.png"))
print("아이콘 생성 완료: Android mipmap 5종 + anydpi-v26 + iOS AppIcon 15종 + 스토어용 512")
