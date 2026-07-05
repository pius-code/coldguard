# ColdGuard

An on-device AI agent for cold chain vaccine storage monitoring. Built with Flutter + ESP32 + Qwen2.5-1.5B. No internet required — everything runs locally on the phone and your network.

---

## What it does

ColdGuard gives healthcare workers a plain-English chat interface to monitor and control a vaccine cold storage unit. You talk to it like a person; it translates your instructions into hardware commands.

**Capabilities:**
- Read live temperature and humidity from a DHT sensor
- Control LEDs, a buzzer, and a cooling fan via MQTT
- Send autonomous Lua monitoring scripts to the ESP32 (e.g. "turn on the fan if temperature rises above 30°C")
- Fully offline — the LLM runs on the phone, no cloud API needed

---

## Architecture

```
Android phone              MQTT Broker             ESP32
┌─────────────────┐        ┌───────────┐        ┌─────────────────┐
│ Flutter app     │        │ Mosquitto │        │ ESP32 firmware  │
│ Qwen2.5-1.5B   │ ◄────► │ port 1883 │ ◄────► │ Lua runtime     │
│ LiteRT runtime  │        │ (PC/RPi)  │        │ DHT · LEDs · Fan│
└─────────────────┘        └───────────┘        └─────────────────┘
```

The LLM picks the right tool for each user message, the app sends a JSON command over MQTT, and the ESP32 executes it. Sensor readings flow back the same way.

---

## Prerequisites

### Hardware
| Component | Notes |
|---|---|
| ESP32 dev board | Any variant |
| DHT11 or DHT22 | Temperature & humidity sensor |
| Red LED + 220Ω resistor | Alarm indicator |
| Green LED + 220Ω resistor | Status indicator |
| Passive buzzer | Must be passive (PWM-driven) |
| DC fan + transistor/relay | 2N2222 or relay module as driver |
| Android phone | Android 7.0+, 4 GB RAM recommended |
| PC or Raspberry Pi | Runs the MQTT broker |

### Software
- [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install)
- Android Studio (with Android NDK installed via SDK Manager)
- Mosquitto MQTT broker
- Git

### AI model file
You need **Qwen2.5-1.5B-Instruct** in LiteRT format (`.litertlm` extension). This file is ~1.5 GB and is not included in the repo. Search HuggingFace for a LiteRT or `.task` format build of this model. Transfer it to your Android device's storage.

---

## ESP32 wiring (default pins)

All pins are configurable inside the app's Settings screen.

| Device | GPIO | Signal type |
|---|---|---|
| Red LED | 18 | Digital out |
| Green LED | 19 | Digital out |
| Buzzer | 21 | PWM |
| Fan | 26 | Digital out (via driver) |
| DHT sensor | 22 | 1-Wire data (10kΩ pull-up to 3.3V) |

---

## ESP32 firmware requirements

ColdGuard does not include ESP32 firmware — you write your own. Your firmware must:

1. Connect to the same WiFi network as the phone
2. Connect to the MQTT broker
3. Subscribe to the command topic: `coldGuard/command`
4. Handle these JSON payload formats:

```json
// Digital pin control
{"pin": 18, "action": "digital", "value": 1}

// PWM (buzzer)
{"pin": 21, "action": "pwm", "channel": 0, "freq": 440, "duty": 32767}

// DHT sensor read — reply with same correlation_id
{"pin": 22, "action": "DHT", "correlation_id": "abc12345"}

// Execute Lua script autonomously
{"action": "lua", "script": "while true do ... end"}
```

5. For DHT commands, publish the response to `coldGuard/response`:

```json
{"temperature": 24.5, "humidity": 68.0, "correlation_id": "abc12345"}
```

6. Implement a Lua runtime with these functions under the `asha` module:

| Function | Description |
|---|---|
| `asha.getTemperature()` | Returns current temperature in °C |
| `asha.getHumidity()` | Returns current humidity % |
| `asha.command(jsonStr)` | Execute a command JSON string |
| `asha.sleep(ms)` | Sleep — **mandatory in every while loop or device will crash** |

---

## MQTT broker setup

Install Mosquitto on a machine on the same WiFi network as the phone and the ESP32.

```bash
# Ubuntu / Raspberry Pi
sudo apt install mosquitto mosquitto-clients
sudo systemctl enable mosquitto && sudo systemctl start mosquitto

# macOS
brew install mosquitto && brew services start mosquitto
```

Edit `/etc/mosquitto/mosquitto.conf` to allow external connections:

```
listener 1883
allow_anonymous true
```

Find the broker's local IP with `hostname -I` (Linux) or `ipconfig` (Windows). You'll enter this in the app.

**Test it:**
```bash
# Terminal 1 — listen to all ColdGuard traffic
mosquitto_sub -h 192.168.x.x -t "coldGuard/#" -v

# Terminal 2 — publish a test message
mosquitto_pub -h 192.168.x.x -t "coldGuard/test" -m "hello"
```

---

## Project setup

```bash
# 1. Clone
git clone https://github.com/yourname/coldguard.git
cd coldguard

# 2. Install dependencies
flutter pub get

# 3. Create android/local.properties if it doesn't exist, add:
#    flutter.compileSdkVersion=36
#    (required by the LiteRT plugin)

# 4. Run on a physical Android device (not emulator)
flutter run
```

> **Physical device required.** The on-device LLM needs real hardware performance and GPU access. Emulators will not work well.

---

## Using the app

### First launch
1. Enter the **broker IP** — the local IP of the machine running Mosquitto
2. Tap **Load Model** — pick your `.litertlm` file from storage. First load takes 30–90 seconds; keep the app open. Subsequent launches remember the path and show a **Connect & Start** button instead.
3. The status dot turns green when ready — start chatting.

### Example commands
| You say | What happens |
|---|---|
| "What's the temperature?" | Reads DHT sensor, reports live value |
| "Turn on the red light" | Sets GPIO 18 HIGH |
| "Turn fan off and green light on" | Executes both commands in one response |
| "Alert me if temp goes above 30°C" | Sends a Lua monitoring script to the ESP32 |

### Settings
Tap the **sliders icon** (top right in chat) to open Settings. You can change:
- **AI Persona Prompt** — how the agent speaks and behaves
- **Device Pins** — GPIO numbers for each device
- **Buzzer PWM** — frequency, duty cycle, LEDC channel
- **MQTT Topics** — command and response topic strings

After changing the persona prompt, tap **Reset Chat** in the banner that appears.

---

## Project structure

```
lib/
├── main.dart             — App entry, onboarding (IP entry + model picker)
├── chat_screen.dart      — Chat UI, LLM streaming, tool call parsing & execution
├── mqtt_services.dart    — MQTT client (connect, publish, subscribe, message stream)
├── raw_tools.dart        — Tool implementations: MQTT commands + sensor waiting
├── tools.dart            — LLM tool schemas and handler map
├── device_config.dart    — Settings singleton, load/save via SharedPreferences
└── settings_screen.dart  — Settings UI

android/app/src/main/
├── AndroidManifest.xml   — Permissions: MANAGE_EXTERNAL_STORAGE, INTERNET
└── res/
    ├── drawable*/        — Splash screen backgrounds
    ├── mipmap*/          — App icons (all densities + adaptive)
    └── values*/          — Themes, including v31 for Android 12+ splash screen
```

---

## Building the APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

The APK is ~90 MB because it bundles the LiteRT runtime. The model file is distributed separately.

To install on another device, enable **Install from unknown sources** in Android Settings → Apps → Special app access, then transfer and open the APK.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| App crashes on model load | Check the `.litertlm` file is valid and not corrupted. Close other apps to free RAM. |
| Build fails: `compileSdk must be 36` | Add `flutter.compileSdkVersion=36` to `android/local.properties` |
| MQTT not connecting | Confirm phone and broker are on the same WiFi. Check Mosquitto is listening on `0.0.0.0`, not just `localhost`. Check firewall on port 1883. |
| Sensor reads always time out | Use `mosquitto_sub -t "coldGuard/#" -v` to see what the ESP32 actually publishes. Confirm the response topic matches settings. |
| Agent makes up sensor values | Reset the chat and ask again. Small model limitation — the prompt instructs it not to guess but it sometimes does. |
| Lua script does wrong thing | Reset the chat after any code or settings change — the LLM context is initialised once at conversation start. |

---

## Dependencies

| Package | Role |
|---|---|
| `flutter_litert_lm` | On-device LLM inference. Provides `LiteLmEngine`, streaming token API. |
| `mqtt_client` | MQTT pub/sub client |
| `shared_preferences` | Persists settings and model path between sessions |
| `file_picker` | Android file picker for selecting the model file |
| `permission_handler` | Requests storage permission for file access |
