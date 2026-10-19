import json
data = json.load(open("D:/zkgame/scripts/events.json", encoding='utf-8'))
char = [e for e in data if e.get('charId') not in (None,'','player')]
node_kw = ['grad','graduation','end_pre']
nodes = [e for e in char if any(k in e.get('id','').lower() for k in node_kw)]
with_excl = [e for e in char if 'excludeRelState' in e]
with_req  = [e for e in char if 'requireRelState' in e]
leaked = [e for e in char if 'excludeRelState' not in e and 'requireRelState' not in e
          and not any(k in e.get('id','').lower() for k in node_kw)]
print("char_events:", len(char))
print("with_excludeRelState:", len(with_excl))
print("with_requireRelState:", len(with_req))
print("nodes(grad/graduation/end_pre):", len(nodes))
print("nodes_WITH_excludeRelState (should be 0):", sum(1 for e in nodes if 'excludeRelState' in e))
print("leaked (no excl/req & not node):", len(leaked))
for e in leaked:
    print("  LEAK:", e.get('id'), e.get('charId'))
# 抽查：节点事件 id
print("node ids:", [e.get('id') for e in nodes])
