import json, glob, os
from collections import Counter

ROOT = "D:/zkgame/scripts"
files = sorted(glob.glob(os.path.join(ROOT, "events*.json")))

# 关系状态机专门事件（处理冷战/状态推进/挽回），不应加 excludeRelState
REL_KW = ['cold_war','cold_recover','_cold','cold_','_war','war_','_recover','recover',
          '_close','close_','_crush','crush_','confess','breakup','rel_state','relstate',
          'makeup','reconcile','reunite','apolog','_angry','angry','fight','misunderstand','_rel']

def is_rel_event(eid):
    l = (eid or '').lower()
    return any(k in l for k in REL_KW)

total = 0
candidates = []
per_file = {}
for f in files:
    data = json.load(open(f, encoding='utf-8'))
    evs = data if isinstance(data, list) else data.get('events', [])
    char_events = [e for e in evs if e.get('charId') not in (None,'','player')]
    has_excl = [e for e in char_events if 'excludeRelState' in e]
    has_req  = [e for e in char_events if 'requireRelState' in e]
    rel      = [e for e in char_events if is_rel_event(e.get('id',''))]
    cand = [e for e in char_events
            if 'excludeRelState' not in e
            and 'requireRelState' not in e
            and not is_rel_event(e.get('id',''))]
    per_file[os.path.basename(f)] = {
        'char_events': len(char_events),
        'has_excl': len(has_excl),
        'has_req': len(has_req),
        'rel': len(rel),
        'cand': len(cand),
    }
    total += len(cand)
    for e in cand:
        candidates.append((os.path.basename(f), e.get('id'), e.get('charId')))

print("=== 每文件统计 (角色事件 / 已含excludeRelState / 已含requireRelState / 关系机事件 / 候选缺口) ===")
for f,s in per_file.items():
    print(f"{f:28s} char={s['char_events']:3d} excl={s['has_excl']:3d} req={s['has_req']:3d} rel={s['rel']:3d} cand={s['cand']:3d}")
print("\n=== 候选缺口总数 ===", total)
print("\n=== 候选清单 (file | id | charId) ===")
for c in candidates:
    print(f"{c[0]:28s} {c[1]:28s} {c[2]}")
