from PIL import Image, ImageDraw, ImageFont
import os

os.makedirs(r'd:\zkgame\assets\backgrounds', exist_ok=True)

# grad_olympiad — 奥赛金牌毕业 CG 占位图
img = Image.new('RGB', (1280, 720), color='#1a1240')
d = ImageDraw.Draw(img)
d.text((100, 320), 'grad_olympiad (Placeholder)', fill='#f0d060')
d.text((100, 370), '省级数学竞赛金牌 · 保送录取', fill='#c0a830')
path = r'd:\zkgame\assets\backgrounds\grad_olympiad.jpg'
img.save(path, quality=90)
print(f'Generated: {path}')
