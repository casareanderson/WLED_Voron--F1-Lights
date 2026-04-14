# WLED_Voron — F1 Lights 🏎️

A complete guide to integrating WLED LED control with your Voron 2 / Klipper printer using an F1 race car colour theme.

Based on the original work by [Gliptopolis](https://github.com/Gliptopolis/WLED_Klipper), expanded and improved with real-world Voron 2 experience.

---

## Colour Theme — F1 Race Car

| State | Colour | Vibe |
|---|---|---|
| IDLE | Deep blue | Parked in the garage |
| HEATING | Orange | Engine warming up |
| MESHING | Electric blue | Systems check |
| PRINTING | Bright white | Race lights on |
| COMPLETE | Green flash | Chequered flag |
| ERROR | Red flash | Safety car |
| COOLDOWN | Blue breathe | Cool down lap |

---

## Hardware

- ESP32 or ESP8266 flashed with [WLED](https://install.wled.me/)
- LED strip wired to your ESP (WS2812B, SK6812, or COB for single-zone lighting)
- ESP connected to your network

> **COB strips**: Not individually addressable but work perfectly for full-strip colour and brightness control.

---

## Installation

### 1 — Flash WLED

Go to [install.wled.me](https://install.wled.me/) and flash your ESP. Note the IP address.

### 2 — Set colour order in WLED

Open `http://YOUR_WLED_IP/settings/leds` and set **Color Order** to match your strip. Most WS2812B and COB strips are **GRB**.

### 3 — Install gcode_shell_command

```bash
wget -O ~/klipper/klippy/extras/gcode_shell_command.py \
  https://raw.githubusercontent.com/Rat-OS/RatOS/master/src/modules/ratos/filesystem/home/pi/klipper/klippy/extras/gcode_shell_command.py
```

### 4 — Copy files to your Pi

```bash
mkdir -p ~/klipper_config/scripts
cp scripts/wled_colour.sh ~/klipper_config/scripts/
chmod +x ~/klipper_config/scripts/wled_colour.sh
cp config/wled.cfg ~/printer_data/config/
cp config/print_macros.cfg ~/printer_data/config/
```

### 5 — Add to moonraker.conf

```ini
[wled klipper]
type: http
address: 192.168.x.x
initial_red: 0.0
initial_green: 0.0
initial_blue: 0.71
chain_count: 330
```

### 6 — Add includes to printer.cfg

```ini
[include wled.cfg]
[include print_macros.cfg]
```

### 7 — Restart

```bash
sudo systemctl restart klipper moonraker
```

### 8 — Test in Mainsail console
LED_IDLE
LED_HEATING
LED_MESHING
LED_PRINTING
LED_COMPLETE
LED_ERROR
LED_COOLDOWN

---

## Customising Colours

Colours are set in `wled.cfg` as direct API calls. The format is:
IP  R  G  B  BRIGHTNESS  EFFECT

Effect: `0` = solid, `1` = blink, `2` = breathe

> **GRB strips**: R and G are swapped. Orange (R=255, G=80) is sent as `80 255 0`. Already handled in the default wled.cfg.

---

## Troubleshooting

**Strip not responding**
- Check for frozen segment: `curl -s http://YOUR_IP/json/state` — look for `"frz": true`
- Disable AudioReactive: `http://YOUR_IP/settings/um`

**Wrong colours**
- Check colour order in WLED: `http://YOUR_IP/settings/leds`
- GRB strips: swap R and G in your PARAMS values

**Macros not found**
- Confirm includes are in printer.cfg
- Check logs: `tail -f ~/printer_data/logs/klippy.log`

---

## File Structure
WLED_Voron--F1-Lights/
├── README.md
├── config/
│   ├── wled.cfg           # LED macros, direct WLED API calls
│   └── print_macros.cfg   # PRINT_START, PRINT_END, PAUSE, RESUME, CANCEL
└── scripts/
└── wled_colour.sh     # Shell script posting colours to WLED JSON API

---

## Credits

- Original concept: [Gliptopolis/WLED_Klipper](https://github.com/Gliptopolis/WLED_Klipper)
- WLED firmware: [Aircoookie/WLED](https://github.com/Aircoookie/WLED)
- gcode_shell_command: [Arksine / RatOS](https://github.com/Rat-OS/RatOS)
