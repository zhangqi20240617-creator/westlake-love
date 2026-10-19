import subprocess, os

os.chdir('d:/zkgame')
r = subprocess.run(['python', 'scripts/validate_events.py'],
    capture_output=True, encoding='utf-8', errors='replace')

with open('scratch/validate_result.txt', 'w', encoding='utf-8') as f:
    f.write(r.stdout)
    if r.stderr:
        f.write('\nSTDERR:\n' + r.stderr[:2000])
    f.write(f'\nEXIT CODE: {r.returncode}')

print("Done. Exit code:", r.returncode)
print(r.stdout[-800:])
