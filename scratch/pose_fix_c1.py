# Phase 3 / C-1 pose normalizer
# Policy per charId:
#  remove      -> empty / no-dir asset chars: drop "pose" key entirely (omit)
#  default     -> default.jpg-only chars: force any present pose -> "default"
#  fixupset_jj-> jingjing: only "upset" -> "serious" (asset exists); keep default/shy
#  fixupset_xx-> xiaoxia: only "upset" -> "default" (no serious asset); keep default/shy
#  leave       -> yutong & others: keep valid poses as-is
import json, io, os

BASE = "D:/zkgame/scripts"

POLICY = {
    'keke': 'remove',
    'beichen': 'remove',
    'jingjing_m': 'remove',
    'zijun': 'remove',
    'wanqing': 'default',
    'yifei': 'default',
    'zicheng': 'default',
    'jingjing': 'fixupset_jj',
    'xiaoxia': 'fixupset_xx',
}

FILES = [
    'events_keke.json',
    'events_male.json',
    'events_wanqing.json',
    'events_jingjing.json',
    'events_xiaoxia.json',
]

def transform(pose, char):
    pol = POLICY.get(char, 'leave')
    if pol == 'remove':
        return None
    if pol == 'default':
        return 'default'
    if pol == 'fixupset_jj':
        return 'serious' if pose == 'upset' else pose
    if pol == 'fixupset_xx':
        return 'default' if pose == 'upset' else pose
    return pose

for fn in FILES:
    path = os.path.join(BASE, fn)
    with io.open(path, encoding='utf-8') as f:
        data = json.load(f)
    changed = 0
    for ev in data:
        if not isinstance(ev, dict):
            continue
        char = ev.get('charId')
        if char not in POLICY:
            continue
        for sc in ev.get('scenes', []):
            if not isinstance(sc, dict):
                continue
            if 'pose' in sc:
                new = transform(sc['pose'], char)
                if new is None:
                    del sc['pose']
                    changed += 1
                elif new != sc['pose']:
                    sc['pose'] = new
                    changed += 1
    if changed:
        with io.open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print(f"{fn}: {changed} pose field(s) adjusted")
    else:
        print(f"{fn}: no change")
