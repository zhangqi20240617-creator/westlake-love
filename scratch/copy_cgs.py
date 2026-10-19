import os
import glob
from PIL import Image

src_dir = 'C:/Users/Administrator/.gemini/antigravity/brain/f34319ff-865a-4030-b776-24b1a9f87b42/'
dst_dir = 'd:/zkgame/assets/backgrounds/'

for f in glob.glob(os.path.join(src_dir, 'grad_club_*.png')):
    base = os.path.basename(f)
    print(base)
    # the filenames are like grad_club_astronomy_1785725406690.png
    # we want grad_club_astronomy.jpg
    name = base.rsplit('_', 1)[0]
    out_path = os.path.join(dst_dir, name + '.jpg')
    print(f"Converting {f} to {out_path}")
    img = Image.open(f).convert('RGB')
    img.save(out_path, format='JPEG', quality=95)
