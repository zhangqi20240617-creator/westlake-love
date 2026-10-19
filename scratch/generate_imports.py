import os
import hashlib
import uuid
import glob

template = '''[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{file_name}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://assets/backgrounds/{file_name}"
dest_files=["res://.godot/imported/{file_name}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
'''

path = 'd:/zkgame/assets/backgrounds/'
for ext in ['*.jpg', '*.png']:
    for f in glob.glob(os.path.join(path, ext)):
        import_path = f + '.import'
        if not os.path.exists(import_path):
            print(f"Creating .import for {f}")
            file_name = os.path.basename(f)
            md5 = hashlib.md5(file_name.encode('utf-8')).hexdigest()
            uid = uuid.uuid4().hex[:13] # roughly godot length
            content = template.format(uid=uid, md5=md5, file_name=file_name)
            with open(import_path, 'w', encoding='utf-8') as out:
                out.write(content)
print("Done.")
