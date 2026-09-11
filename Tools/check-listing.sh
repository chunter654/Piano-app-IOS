#!/bin/bash
# Measures the store listing against Apple's field limits, and checks that the
# credit the sound's licence requires is still in it.
set -e
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re, sys
text = open("StoreListing.md").read()
limits = {"Name": 30, "Subtitle": 30, "Promotional text": 170,
          "Keywords": 100, "Description": 4000}
sections = re.split(r"^## ", text, flags=re.M)[1:]
seen, bad = {}, False
for s in sections:
    head, _, body = s.partition("\n")
    name = head.split(" (")[0].strip()
    if name not in limits:
        continue
    body = body.strip()
    # Wrapping in this file is for reading; the store field is one flow.
    flow = re.sub(r"\n(?!\n)", " ", body)
    n = len(flow)
    seen[name] = n
    mark = "ok " if n <= limits[name] else "OVER"
    if n > limits[name]:
        bad = True
    print(f"{mark} {name}: {n} of {limits[name]}")
credit = "Salamander Grand Piano by Alexander Holm"
if credit not in text:
    print("MISSING the attribution the sound's licence requires")
    bad = True
else:
    print("ok  attribution present")
missing = set(limits) - set(seen)
if missing:
    print("MISSING sections:", ", ".join(sorted(missing)))
    bad = True
sys.exit(1 if bad else 0)
PY
