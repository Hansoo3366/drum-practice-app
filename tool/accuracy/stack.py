"""stack.py out.png song/pP-sNN [song/pP-sNN ...]: the named line crops, one under another."""
import sys
from PIL import Image, ImageDraw
import os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Pictures, answer keys and results live outside git (they hold whole lyrics).
DATA = os.environ.get('ACCURACY_DATA', os.path.join(ROOT, 'score_sample', '_accuracy'))
ims = []
for name in sys.argv[2:]:
    im = Image.open(f'{DATA}/lines/{name}.png').convert('RGB')
    w = 1900; im = im.resize((w, int(im.size[1] * w / im.size[0])))
    d = ImageDraw.Draw(im); d.rectangle([0, 0, 230, 16], fill='black'); d.text((3, 2), name, fill='yellow')
    ims.append(im)
sheet = Image.new('RGB', (1900, sum(i.size[1] for i in ims) + 5 * len(ims)), 'red'); y = 0
for im in ims: sheet.paste(im, (0, y)); y += im.size[1] + 5
sheet.save(sys.argv[1])
