"""Makes the piano app's launcher icon, system splash icon and in-app splash picture
from the artwork in branding/piano/.

  python3 tool/brand/piano_brand.py

Writes android/app/src/piano/res/ (resources that replace the shared ones in the piano
flavor only) and assets/piano/splash.jpg.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'piano', 'res')
DENSITIES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}
# The colour of the artwork's rim, behind it where a launcher shows more than the picture.
BACKGROUND = '#FB8C3C'


def artwork():
    """The icon picture cut out of its white sheet, as RGBA cropped to the picture."""
    source = Image.open(os.path.join(ROOT, 'branding', 'piano', 'app_icon.png')).convert('RGB')
    pixels = np.asarray(source).astype(int)
    ink = pixels.min(axis=2) < 240
    # The picture is a rounded square with white inside it too (the cross, the pages):
    # what lies between its first and last inked pixel, by row and by column, is picture.
    rows = np.maximum.accumulate(ink, axis=1) & np.maximum.accumulate(ink[:, ::-1], axis=1)[:, ::-1]
    columns = np.maximum.accumulate(ink, axis=0) & np.maximum.accumulate(ink[::-1], axis=0)[::-1]
    mask = Image.fromarray(((rows & columns) * 255).astype('uint8'))
    # Off the white fringe of the edge, then a soft edge again.
    mask = mask.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    cut = source.convert('RGBA')
    cut.putalpha(mask)
    return cut.crop(mask.getbbox())


def on_canvas(art, canvas, side):
    """[art] scaled to [side] pixels, centred on a transparent square of [canvas] pixels."""
    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    scaled = art.resize((side, side), Image.LANCZOS)
    out.alpha_composite(scaled, ((canvas - side) // 2, (canvas - side) // 2))
    return out


def save(image, folder, name):
    path = os.path.join(RES, folder)
    os.makedirs(path, exist_ok=True)
    image.save(os.path.join(path, name), optimize=True)


def main():
    art = artwork()
    art = art.resize((max(art.size),) * 2, Image.LANCZOS)
    for density, scale in DENSITIES.items():
        dp = lambda value: round(value * scale)
        # Launchers older than adaptive icons: the rounded square as drawn.
        save(on_canvas(art, dp(48), dp(46)), f'mipmap-{density}', 'ic_launcher.png')
        # Adaptive icon: 108dp, of which launchers show the middle 72dp under their own
        # mask. The picture is a little wider than that, so the mask cuts only its rim.
        save(on_canvas(art, dp(108), dp(78)), f'drawable-{density}', 'ic_launcher_foreground.png')
        # System splash (Android 12+): 288dp, masked to a 192dp circle. The rounded
        # square fits inside it.
        splash = on_canvas(art, dp(288), dp(150))
        save(splash, f'drawable-{density}', 'android12splash.png')
        save(splash, f'drawable-night-{density}', 'android12splash.png')
        # Launch window before Android 12: the picture in the middle of the screen.
        save(on_canvas(art, dp(200), dp(200)), f'drawable-{density}', 'splash.png')
    os.makedirs(os.path.join(RES, 'mipmap-anydpi-v26'), exist_ok=True)
    with open(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '  <background android:drawable="@color/ic_launcher_background"/>\n'
                '  <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    os.makedirs(os.path.join(RES, 'values'), exist_ok=True)
    with open(os.path.join(RES, 'values', 'ic_launcher_background.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                f'    <color name="ic_launcher_background">{BACKGROUND}</color>\n</resources>\n')
    picture = Image.open(os.path.join(ROOT, 'branding', 'piano', 'splash.png')).convert('RGB')
    os.makedirs(os.path.join(ROOT, 'assets', 'piano'), exist_ok=True)
    picture.save(os.path.join(ROOT, 'assets', 'piano', 'splash.jpg'), quality=88, optimize=True, progressive=True)
    print('artwork', art.size, '| splash', picture.size)


if __name__ == '__main__':
    main()
