#!/usr/bin/env bash
# Checks what docs/SETUP.md can check without a printer: the config is consistent, the README's sed
# edits all nine addresses, and every LED_* macro's values reach a (fake) WLED as valid JSON.
# Used by .github/workflows/setup-check.yml. Run it locally from the repo root too.
set -euo pipefail
step() { printf '\n== %s\n' "$*"; }
PORT=${PORT:-18090}

step "the shell script is valid bash"
bash -n scripts/wled_colour.sh && echo ok

step "wled.cfg: every macro, sane values, one address"
python3 - <<'PY'
import re
cfg = open("config/wled.cfg").read()
want = ["LED_IDLE", "LED_HEATING", "LED_MESHING", "LED_PRINTING", "LED_COMPLETE",
        "LED_ERROR", "LED_COOLDOWN", "LED_OFF"]
for m in want:
    assert f"[gcode_macro {m}]" in cfg, m
params = re.findall(r'PARAMS="([^"]+)"', cfg)
assert len(params) == 9, len(params)
ips = {p.split()[0] for p in params}
assert ips == {"192.0.2.50"}, ips                 # the shipped placeholder, in all nine places
for p in params[1:]:                              # params[0] is _WLED_POST's {r} {g} ... template
    ip, *vals = p.split()
    r, g, b, bri, fx = map(int, vals)
    assert all(0 <= v <= 255 for v in (r, g, b, bri)) and fx in (0, 1, 2), p
assert "command: bash /home/pi/klipper_config/scripts/wled_colour.sh" in cfg
print(len(want), "macros, 9 PARAMS lines, values in range")
PY

step "print_macros.cfg only calls macros that wled.cfg defines"
python3 - <<'PY'
import re
defined = set(re.findall(r"\[gcode_macro (LED_\w+)\]", open("config/wled.cfg").read()))
used = set(re.findall(r"^\s*(LED_\w+)", open("config/print_macros.cfg").read(), re.M))
assert used and used <= defined, used - defined
print("uses", sorted(used))
PY

step "step 4 of the guide: the sed edits all nine addresses"
tmp=$(mktemp); cp config/wled.cfg "$tmp"
sed -i -E 's/PARAMS="[0-9.]+ /PARAMS="198.51.100.50 /' "$tmp"
n=$(grep -c 'PARAMS="198.51.100.50 ' "$tmp"); echo "$n replaced"; [ "$n" -eq 9 ]

step "each macro's values reach WLED as valid JSON"
python3 scripts/fake_wled.py "$PORT" & fake=$!
trap 'kill $fake 2>/dev/null || true' EXIT
for i in $(seq 1 20); do curl -s "localhost:$PORT/_last" >/dev/null && break; sleep 0.3; done
python3 - <<'PY' > "${TMPDIR:-/tmp}/led-macros.txt"
import re
for name, body in re.findall(r"\[gcode_macro (LED_\w+)\]\n(.*?)(?=\n\[|\Z)", open("config/wled.cfg").read(), re.S):
    print(name, re.search(r'PARAMS="\S+ ([^"]+)"', body).group(1))
PY
[ "$(wc -l < "${TMPDIR:-/tmp}/led-macros.txt")" -eq 8 ]
while read -r macro vals; do
  bash scripts/wled_colour.sh "127.0.0.1:$PORT" $vals
  curl -s "localhost:$PORT/_last" | python3 -c "
import json, sys
d = json.load(sys.stdin); b = d['body']; r, g, bl, bri, fx = map(int, sys.argv[2].split())
assert d['path'] == '/json/state' and d['ctype'] == 'application/json', d
assert b == {'on': True, 'bri': bri, 'seg': [{'id': 0, 'frz': False, 'fx': fx, 'col': [[r, g, bl]]}]}, b
print('%-13s -> %s' % (sys.argv[1], json.dumps(b)))" "$macro" "$vals"
done < "${TMPDIR:-/tmp}/led-macros.txt"

step "an unreachable strip can't hang a print (curl gives up within its 5 s limit)"
start=$(date +%s); bash scripts/wled_colour.sh 192.0.2.1 0 0 0 0 0 || true; took=$(( $(date +%s) - start ))
echo "returned after ${took}s"; [ "$took" -le 6 ]

printf '\nSETUP CHECK PASSED\n'
