import os
import re

path = 'd:/zkgame/scripts/events_life.json'
with open(path, 'rb') as f:
    raw = f.read()

# determine encoding
if raw.startswith(b'\xff\xfe'):
    text = raw.decode('utf-16')
elif raw.startswith(b'\xef\xbb\xbf'):
    text = raw.decode('utf-8-sig')
else:
    text = raw.decode('utf-8')

# The corruption happened when I did  = ...TrimEnd() ... Substring ... + 
# So I just need to find the Olympiad event "olympiad_invite" and remove everything from it onwards.
idx = text.find('olympiad_invite')
if idx != -1:
    # Find the { before this
    idx_brace = text.rfind('{', 0, idx)
    # Find the comma before this brace
    idx_comma = text.rfind(',', 0, idx_brace)
    if idx_comma != -1:
        text = text[:idx_comma] + '\n]'
        print('Successfully stripped corrupted append.')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
