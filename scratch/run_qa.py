import subprocess, sys, os

os.chdir('d:/zkgame')

scripts = [
    ['python', 'tests/olympiad_smoke/verify_qa.py'],
    ['python', 'tests/life_smoke/validate_life.py'],
]

out_lines = []
overall_ok = True
for cmd in scripts:
    out_lines.append(f"\n{'='*60}")
    out_lines.append(f"Running: {' '.join(cmd)}")
    out_lines.append('='*60)
    r = subprocess.run(cmd, capture_output=True, encoding='utf-8', errors='replace')
    out_lines.append(r.stdout)
    if r.stderr:
        out_lines.append("STDERR: " + r.stderr[:1000])
    if r.returncode != 0:
        overall_ok = False
        out_lines.append(f"EXIT CODE: {r.returncode}")

out_lines.append("\n" + "="*60)
out_lines.append("OVERALL: " + ("PASS" if overall_ok else "FAIL"))

result = "\n".join(out_lines)

with open('scratch/qa_result.txt', 'w', encoding='utf-8') as f:
    f.write(result)

print("Done. Written to scratch/qa_result.txt")
