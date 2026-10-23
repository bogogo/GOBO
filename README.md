# Gobo: home smart LED system

Local-only smart lighting, like Hue or LIFX, with no cloud and no hub.

```
 iPhone / iPad / Mac / Windows / Fire tablet        ESP32 button remotes
              (Gobo Flutter app)                     (firmware/button_remote)
                    │   finds lights via mDNS (_wled._tcp)        │
                    │   live control over WebSocket /ws           │ HTTP POST /json/state
                    ▼                                             ▼
        ┌───────────── home Wi-Fi ─────────────────────────────────────┐
        │  ESP32 + WLED  ──►  LED strip (kitchen)                      │
        │  ESP32 + WLED  ──►  LED strip (living room)   ...one per zone│
        └──────────────────────────────────────────────────────────────┘
```

## Parts (per zone)

| Part | Pick | Notes |
|---|---|---|
| Controller | Athom WLED controller or QuinLED Dig-Uno (ESP32) | Comes with WLED or flashes it in a browser. A bare ESP32 DevKit works too, add a 74AHCT125 level shifter. |
| Strip | SK6812 RGBW 5V, 60 LED/m | Real warm white. For runs over ~5 m use WS2815 12V instead. |
| Power supply | 5V (or 12V) Mean Well | Budget ~60 mA per LED at full white, then add 20%. 5 m × 60 LED/m ≈ 18 A max, but WLED's current limiter lets you use a smaller supply. |
| Extras | 1000 µF capacitor across power, 330 Ω on data line, inline fuse | Prebuilt controllers already include these. |

Button remote: any ESP32 DevKit, 4 momentary buttons, a USB power adapter or 18650 battery.

## Setting up a light

1. Flash WLED from https://install.wled.me in Chrome (skip if the board shipped with it).
2. Join its `WLED-AP` Wi-Fi (password `wled1234`), and enter your home Wi-Fi.
3. In WLED: **Config → LED Preferences**, set the LED type (SK6812 RGBW), count, data GPIO, and a current limit that matches your supply.
4. **Config → WiFi Setup**, give it a name like `kitchen` (that's the mDNS name the app sees).
5. Save a few presets in WLED (e.g. Relax, Bright, Movie). They show up as **Scenes** in the app, and button 4 cycles presets 1-4.

## The app (`app/`)

Requires Flutter 3.27 or newer.

```sh
cd app
flutter pub get
flutter run            # pick your iPhone, iPad, Mac, Windows PC or Fire tablet
flutter build apk      # Fire tablet: sideload the APK, or publish to the Amazon Appstore
```

Local network permissions (iOS/macOS Bonjour + local networking, Android cleartext HTTP) are already set in the platform folders.

No lights yet? Run it with pretend lights: `flutter run -d chrome --dart-define=DEMO=true`.

What it does: auto-discovers lights, tile grid with on/off and brightness, an All off button, and a detail page per light with color, saturation, white channel, swatches, scenes (WLED presets), and effects. Long-press a tile to forget it; tap + to add one by IP if discovery is blocked on your network.

## Button remote (`firmware/button_remote/`)

Open `button_remote.ino` in the Arduino IDE, set your Wi-Fi and the light IPs, flash. Buttons: GPIO13 toggle, GPIO12 brighter, GPIO14 dimmer, GPIO27 next scene. Wire each button from the pin to GND.

Tip: buttons wired straight into a WLED controller's spare GPIO also work (Config → LED Preferences → Button), no second board needed.
