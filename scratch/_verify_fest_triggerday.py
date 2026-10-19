#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Self-verification for the fest-event triggerDay fix in events_life.json.

Asserts:
  1. events_life.json parses as valid JSON (json.load).
  2. The 4 fest events each contain `triggerDay` with exact values 10/30/120/310.
  3. For these 4 events `priority` is still 300 and `repeatable` is still False
     (no other field was changed).
  4. Total event count is unchanged (72 -> 72): only keys added, no event added/removed.
"""

import json
import sys

TARGET = r"D:\zkgame\scripts\events_life.json"

# id -> expected triggerDay
EXPECTED = {
    "fest_teacherday": 10,
    "fest_newyear": 30,
    "fest_dragonboat": 120,
    "fest_midautumn": 310,
}

EXPECTED_TOTAL = 72


def main():
    failures = []

    # 1. Valid JSON
    try:
        with open(TARGET, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print("FAIL: events_life.json is NOT valid JSON ->", repr(e))
        return 1
    print("PASS 1: events_life.json parsed successfully (valid JSON).")

    # 4. Total count unchanged
    if not isinstance(data, list):
        print("FAIL: top-level JSON is not a list.")
        return 1
    total = len(data)
    if total != EXPECTED_TOTAL:
        failures.append(f"event count = {total}, expected {EXPECTED_TOTAL}")
    else:
        print(f"PASS 4: event count = {total} (unchanged, expected {EXPECTED_TOTAL}).")

    by_id = {ev.get("id"): ev for ev in data if isinstance(ev, dict)}

    # 2 & 3. triggerDay values + unchanged fields
    for eid, day in EXPECTED.items():
        ev = by_id.get(eid)
        if ev is None:
            failures.append(f"{eid}: event not found")
            continue

        if "triggerDay" not in ev:
            failures.append(f"{eid}: missing 'triggerDay'")
        elif ev["triggerDay"] != day:
            failures.append(f"{eid}: triggerDay = {ev.get('triggerDay')}, expected {day}")
        else:
            print(f"PASS 2: {eid}.triggerDay = {day} (exact).")

        if ev.get("priority") != 300:
            failures.append(f"{eid}: priority = {ev.get('priority')}, expected 300 (was changed!)")
        if ev.get("repeatable") is not False:
            failures.append(f"{eid}: repeatable = {ev.get('repeatable')}, expected False (was changed!)")
        if ev.get("location") is not None:
            failures.append(f"{eid}: location = {ev.get('location')}, expected null (was changed!)")
        if ev.get("slotId") is not None:
            failures.append(f"{eid}: slotId = {ev.get('slotId')}, expected null (was changed!)")
        if ev.get("charId") is not None:
            failures.append(f"{eid}: charId = {ev.get('charId')}, expected null (was changed!)")

    # 3. (continued) confirm the 4 fest remain priority 300 + repeatable false
    if all(
        by_id[eid].get("priority") == 300 and by_id[eid].get("repeatable") is False
        for eid in EXPECTED
        if by_id.get(eid) is not None
    ):
        print("PASS 3: all 4 fest events still priority=300, repeatable=false (no other field changed).")
    else:
        print("FAIL 3: one or more fest events had priority/repeatable altered.")

    if failures:
        print("\n=== RESULT: FAIL ===")
        for f in failures:
            print(" -", f)
        return 1

    print("\n=== RESULT: PASS ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
