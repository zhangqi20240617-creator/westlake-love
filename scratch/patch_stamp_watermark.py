from PIL import Image
import shutil, os

src = r"D:\zkgame\assets\backgrounds\west_lake_stamps_complete.jpg"
bak = src + ".bak"

# 备份原图
shutil.copy2(src, bak)

img = Image.open(src)
w, h = img.size
print("原图尺寸:", w, h)

# 水印在右下角，用左侧同高度纹理覆盖，保持 1280x720 不变
TW, TH = 160, 120
patch = img.crop((w - 2*TW, h - TH, w - TW, h))
img.paste(patch, (w - TW, h - TH, w, h))

img.save(src, "JPEG", quality=92)
print("已覆盖右下角水印，保持尺寸:", img.size)
