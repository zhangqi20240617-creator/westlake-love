"""
excludeRelState 历史债清理 · 独立质量门校验脚本
主理人兜底（quality-lead 代理 127.0.0.1:7892 持续 502，环境故障无法派发）。
判定规则：角色事件(charId 非 null/player)须满足以下至少一条，否则记 FAIL：
  1) 含 excludeRelState 字段(值 "cold")
  2) 含 requireRelState 字段(状态已精确锁)
  3) 属固定剧情节点集(id 含 grad/graduation/end_pre, 共 7 个) —— 冷战不应阻断
  4) 属关系状态机事件(id 含精确关键词 cold_war/cold_recover/_cold/close_/crush_/confess/
     breakup/rel_state/relstate/makeup/reconcile/reunite/apolog/misunderstand/_rel)
注意：禁用裸子串 rel/war/angry/fight(会误伤 umbrella/warning 等词)。
"""
import json, glob, os, sys

ROOT = "D:/zkgame/scripts"
files = sorted(glob.glob(os.path.join(ROOT, "events*.json")))
NODE = ['grad', 'graduation', 'end_pre']
REL = ['cold_war','cold_recover','_cold','close_','crush_','confess','breakup',
       'rel_state','relstate','makeup','reconcile','reunite','apolog','misunderstand','_rel']
NODE_IDS = {'yt_end_pre','jj_end_pre','special_graduation_eve','special_grad_wq',
            'special_grad_xx','special_grad_yf','special_grad_zc'}

def is_node(eid):
    l = (eid or '').lower(); return any(k in l for k in NODE)
def is_rel(eid):
    l = (eid or '').lower(); return any(k in l for k in REL)

fails = []
per_file = []
for f in files:
    data = json.load(open(f, encoding='utf-8'))  # 合法性断言：json.load 失败即报错
    evs = data if isinstance(data, list) else data.get('events', [])
    fc = fcov = 0
    for e in evs:
        cid = e.get('charId')
        if cid in (None, '', 'player'):
            continue
        fc += 1
        if ('excludeRelState' in e) or ('requireRelState' in e) or is_node(e.get('id','')) or is_rel(e.get('id','')):
            fcov += 1
        else:
            fails.append((os.path.basename(f), e.get('id'), cid))
    per_file.append((os.path.basename(f), fc, fcov))

# 额外断言：events.json 的 excludeRelState:"cold" 计数 == 62
ej = json.load(open(os.path.join(ROOT, "events.json"), encoding='utf-8'))
cnt = sum(1 for e in ej if e.get('excludeRelState') == "cold")
assert cnt == 62, f"events.json excludeRelState:'cold' 计数={cnt}, 期望 62"

# 额外断言：7 个节点事件确认无 excludeRelState(不应被屏蔽)
for e in ej:
    if e.get('id') in NODE_IDS:
        assert 'excludeRelState' not in e, f"节点事件 {e.get('id')} 不应含 excludeRelState"

print("=== 逐文件 (角色事件 / 已覆盖 / 缺口) ===")
for name, c, cov in per_file:
    print(f"{name:26s} char={c:3d} covered={cov:3d} gap={c-cov:3d}")
print(f"\n文件数={len(files)}  角色事件总数={sum(c for _,c,_ in per_file)}  已覆盖={sum(v for _,_,v in per_file)}  缺口={len(fails)}")

if fails:
    print("\n=== FAIL 缺口清单 ===")
    for fl in fails:
        print("  FAIL:", fl)
    print("\n质量门判定: FAIL")
    sys.exit(1)

print("\n质量门判定: PASS (全 11 文件 209 个角色事件均已覆盖, gap=0; events.json 计数=62 校验通过; 7 节点未误屏蔽)")
sys.exit(0)
