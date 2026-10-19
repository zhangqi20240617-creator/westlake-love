from PIL import Image, ImageDraw
import os

types = ['literature', 'astronomy', 'broadcast', 'basketball', 'art']
colors = {
    'literature': '#d2b48c',
    'astronomy': '#191970',
    'broadcast': '#ffdab9',
    'basketball': '#ff8c00',
    'art': '#f5deb3'
}

os.makedirs(r'd:\zkgame\assets\backgrounds', exist_ok=True)
for t in types:
    img = Image.new('RGB', (1280, 720), color=colors[t])
    d = ImageDraw.Draw(img)
    text = f'grad_club_{t} (A3 Placeholder)'
    d.text((100, 360), text, fill='white' if t=='astronomy' else 'black')
    path = rf'd:\zkgame\assets\backgrounds\grad_club_{t}.jpg'
    img.save(path, quality=90)
    print(f'Generated placeholder: {path}')
