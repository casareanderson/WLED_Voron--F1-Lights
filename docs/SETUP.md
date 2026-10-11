# Setting up WLED Voron F1 Lights

About 30 minutes, most of it flashing WLED and finding your strip's colour order. You need the printer
and the strip for most of this, so CI can only check part of it. The steps marked **CI checks this**
run every week on a fresh Ubuntu machine by [`setup-check`](../.github/workflows/setup-check.yml),
against a fake WLED.

## What you need

| | |
|---|---|
| Printer | Klipper with Moonraker, and Mainsail or Fluidd. Built on a Voron 2, works on any Klipper printer. |
| LED controller | an ESP32 or ESP8266 running [WLED](https://install.wled.me/), on the same network as the printer's Pi |
| Strip | WS2812B, SK6812 or COB. COB isn't individually addressable, but whole-strip colour and brightness work, which is all this uses. |
| On the Pi | `bash` and `curl` (both standard on MainsailOS and FluiddPi) |
| Klipper extra | `gcode_shell_command.py`. Klipper doesn't ship it; step 3 downloads it. |

## 1. Flash WLED and find two things (not checked by CI)

Flash the ESP from [install.wled.me](https://install.wled.me/) and join it to your WiFi. Then note:

- its **IP address** (give it a DHCP reservation in your router so it doesn't move), and
- the strip's **colour order**, at `http://<WLED-IP>/settings/leds`. Most WS2812B and COB strips are GRB.

Check WLED answers from the printer's Pi:

```bash
curl -s http://<WLED-IP>/json/state | head -c 200
```

## 2. Get the files onto the Pi

```bash
git clone https://github.com/casareanderson/WLED_Voron--F1-Lights
cd WLED_Voron--F1-Lights
mkdir -p ~/klipper_config/scripts
cp scripts/wled_colour.sh ~/klipper_config/scripts/
chmod +x ~/klipper_config/scripts/wled_colour.sh
cp config/wled.cfg ~/printer_data/config/
```

The config runs the script from `/home/pi/klipper_config/scripts/wled_colour.sh`. If your user isn't
`pi`, or you'd rather keep the script somewhere else, fix the `command:` line under
`[gcode_shell_command _wled_curl]` in `wled.cfg` to match.

## 3. Install gcode_shell_command (not checked by CI)

```bash
wget -O ~/klipper/klippy/extras/gcode_shell_command.py \
  https://raw.githubusercontent.com/Rat-OS/RatOS/master/src/modules/ratos/filesystem/home/pi/klipper/klippy/extras/gcode_shell_command.py
```

It's GPLv3, from RatOS, and isn't included in this repo.

## 4. Point wled.cfg at your strip (CI checks this)

Every `PARAMS=` line ships with the placeholder address `192.0.2.50`. There are nine of them and no
single variable, so change them all in one go (here to `198.51.100.50`, a documentation address: use your own):

```bash
sed -i -E 's/PARAMS="[0-9.]+ /PARAMS="198.51.100.50 /' ~/printer_data/config/wled.cfg
grep -c 'PARAMS="198.51.100.50 ' ~/printer_data/config/wled.cfg    # expect 9
```

CI runs this `sed` on the shipped file and checks all nine change.

## 5. Add the strip to Moonraker and include the config (not checked by CI)

In `moonraker.conf` (it's used by `_WLED_POST`, and puts the strip in the Mainsail UI):

```ini
[wled klipper]
type: http
address: 198.51.100.50
initial_red: 0.0
initial_green: 0.0
initial_blue: 0.71
chain_count: 330
```

Set `chain_count` to your strip's LED count. In `printer.cfg`:

```ini
[include wled.cfg]
```

Then restart:

```bash
sudo systemctl restart klipper moonraker
```

## 6. Test each colour

From the Mainsail or Fluidd console:

```
LED_IDLE
LED_HEATING
LED_MESHING
LED_PRINTING
LED_COMPLETE
LED_ERROR
LED_COOLDOWN
LED_OFF
```

Success is the strip changing on each one. **CI checks** that each macro's numbers reach WLED as a valid
`/json/state` request with the right colour, brightness and effect. It can't check what your strip shows.

**If the colours are wrong**, it's almost always colour order. The defaults are written for a strip where
red and green arrive swapped: `LED_HEATING` sends `80 255 0` to get orange, `LED_COMPLETE` sends
`255 50 0` to get green, `LED_ERROR` sends `0 255 0` to get red. If your WLED colour order already
matches the strip, swap R and G back in those three lines. `LED_MESHING` (`0 120 255`) is the one that
isn't pre-swapped; send `120 0 255` if your strip swaps and you want blue.

## 7. Wire it into your print macros

If you already have working `PRINT_START`, `PRINT_END`, `CANCEL_PRINT`, `PAUSE` and `RESUME`, keep
them and add the `LED_*` calls at the points shown in the README's Usage section.

`config/print_macros.cfg` has all five with the calls in place, but it's written for the author's Voron:
it waits on a Cartographer probe's coil sensor, optionally a chamber sensor, uses `Z_TILT_ADJUST` and
adaptive meshing, and renames the stock `CANCEL_PRINT`, `PAUSE` and `RESUME`. Read every line against
your printer before you include it. CI only checks it calls macros that `wled.cfg` defines.

## Settings

| setting | where | default | what it does |
|---|---|---|---|
| WLED address | every `PARAMS=` line in `wled.cfg` | `192.0.2.50` (placeholder) | where the colour is posted |
| colour, brightness, effect | the six values after the address | per macro | `R G B BRIGHTNESS EFFECT`. Brightness 0–255. Effect `0` solid, `1` blink, `2` breathe. |
| script path | `command:` under `[gcode_shell_command _wled_curl]` | `/home/pi/klipper_config/scripts/wled_colour.sh` | the script Klipper runs |
| `timeout` | same section | `5` s | Klipper gives up on the script after this |
| `--connect-timeout`, `--max-time` | `wled_colour.sh` | `3` s, `5` s | curl's limits, so a strip that's off can't hang a print. **CI checks** an unreachable address returns within 6 s. |
| `[wled klipper]` | `moonraker.conf` | 330 LEDs, starts blue | Moonraker's own handle on the strip |

## Common errors

| you see | what's wrong |
|---|---|
| `Unknown command:"LED_IDLE"` | `[include wled.cfg]` is missing from `printer.cfg`, or Klipper hasn't restarted. Check `~/printer_data/logs/klippy.log`. |
| `Unknown command:"RUN_SHELL_COMMAND"` | step 3 not done. Check `ls ~/klipper/klippy/extras/gcode_shell_command.py`, then restart Klipper. |
| Klipper says the shell command failed or timed out | the script path in `wled.cfg` doesn't exist, or the strip is unreachable. Run it by hand: `bash ~/klipper_config/scripts/wled_colour.sh <WLED-IP> 0 0 180 180 0`. |
| strip ignores every command | a segment is frozen, or AudioReactive is on. `curl -s http://<WLED-IP>/json/state` and look for `"frz": true` (the script clears it on every call), and turn AudioReactive off at `http://<WLED-IP>/settings/um`. |
| wrong colours | colour order. See step 6. |
| Mainsail shows the strip in the wrong state | expected: `LED_*` macros go straight to WLED, not through Moonraker, so Moonraker's view can be out of date. |

## Updating

```bash
cd WLED_Voron--F1-Lights && git pull
cp scripts/wled_colour.sh ~/klipper_config/scripts/
```

Don't copy `wled.cfg` over yours blindly: it would put the placeholder address back. Compare first with
`diff config/wled.cfg ~/printer_data/config/wled.cfg`.

## Uninstalling

Remove `[include wled.cfg]` from `printer.cfg`, the `LED_*` calls from your print macros, and
`[wled klipper]` from `moonraker.conf`, then:

```bash
rm ~/printer_data/config/wled.cfg ~/klipper_config/scripts/wled_colour.sh
sudo systemctl restart klipper moonraker
```

## What CI can't prove

There's no printer and no strip in CI. The weekly check proves the config is consistent (all eight
macros, nine addresses, values in range), that the guide's `sed` edits all nine addresses, that
`print_macros.cfg` only calls macros that exist, that every macro's values arrive at WLED as valid JSON,
and that a strip that's off can't hang a print. It doesn't run Klipper or Moonraker, so it can't catch a
Klipper config syntax error, and it can't tell you what colour your strip shows.
