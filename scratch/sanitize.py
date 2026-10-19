import json
import codecs
import string

path = 'd:/zkgame/scripts/events_life.json'
with open(path, 'rb') as f:
    raw = f.read()

# force utf-8 fallback
try:
    text = raw.decode('utf-8-sig')
except:
    try:
        text = raw.decode('utf-8', errors='ignore')
    except:
        text = raw.decode('cp936', errors='ignore')
        
# ensure it starts directly with [
start = text.find('[')
text = text[start:]

# sanitize to ensure json loads can parse it despite some control characters Godot might tolerate
# wait, actually json.loads handles proper utf-8. I'll just remove unescaped newlines in middle of strings?
# actually, just let's try to json load it. if it fails at line X, we remove that line or fix that char.
while True:
    try:
        data = json.loads(text)
        break
    except Exception as e:
        # e.args[0] looks like "Invalid control character at: line 10 column 33 (char 208)"
        import re
        m = re.search(r'\(char (\d+)\)', str(e))
        if m:
            pos = int(m.group(1))
            # replace the control char with a space
            text = text[:pos] + ' ' + text[pos+1:]
        else:
            print("Unknown parsing error:", e)
            break

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print("Sanitized and dumped JSON.")
