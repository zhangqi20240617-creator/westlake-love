import json, glob, os
ROOT = "D:/zkgame/scripts"
files = sorted(glob.glob(os.path.join(ROOT, "events*.json")))
NODE = ['grad', 'graduation', 'end_pre']
REL = ['cold_war','cold_recover','_cold','close_','crush_','confess','breakup',
       'rel_state','relstate','makeup','reconcile','reunite','apolog','misunderstand','_rel']
def is_node(eid):
    l = (eid or '').lower(); return any(k in l for k in NODE)
def is_rel(eid):
    l = (eid or '').lower(); return any(k in l for k in REL)

total_char = covered = gap = 0
gaps = []
for f in files:
    data = json.load(open(f, encoding='utf-8'))
    evs = data if isinstance(data, list) else data.get('events', [])
    fc = fcv = fg = 0
    for e in evs:
        cid = e.get('charId')
        if cid in (None, '', 'player'):
            continue
        fc += 1; total_char += 1
        if 'excludeRelState' in e or 'requireRelState' in e or is_node(e.get('id','')) or is_rel(e.get('id','')):
            fcv += 1; covered += 1
        else:
            fg += 1; gap += 1
            gaps.append((os.path.basename(f), e.get('id'), cid))
    print(f"{os.path.basename(f):26s} char={fc:3d} covered={fcv:3d} gap={fg:3d}")
print(f"\nfiles={len(files)} total_char_events={total_char} covered={covered} gap={gap}")
if gaps:
    print("=== GAPS (should be empty) ===")
    for g in gaps:
        print("  GAP:", g)
else:
    print("=== ALL CLOSED, gap=0 ===")
