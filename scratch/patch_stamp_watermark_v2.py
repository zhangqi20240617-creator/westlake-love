from PIL import Image, ImageFilter
import shutil

src = r"D:\zkgame\assets\backgrounds\west_lake_stamps_complete.jpg"
bak = src + ".bak"

img = Image.open(bak)
w, h = img.size
print("原图尺寸:", w, h)

TW, TH = 160, 120
# 目标：右下角水印区
target_box = (w - TW, h - TH, w, h)
# 源：目标正上方 120px，同宽度，纹理垂直连续更自然
src_box = (w - TW, h - TH - TH - 20, w, h - TH - 20)
patch = img.crop(src_box)
# 轻微模糊消接缝
patch = patch.filter(ImageFilter.GaussianBlur(radius=1))
img.paste(patch, target_box)

img.save(src, "JPEG", quality=92)
print("v2 覆盖完成，尺寸:", img.size)
