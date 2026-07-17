# Nothing/CMF Controller CLI Cheatsheet

This document outlines the available commands for interacting with your Nothing or CMF earbuds using the refactored modular backend (`main.py`).

## Basic Syntax

```bash
python3 main.py [-v] <MAC_ADDRESS> <FEATURE> <ACTION> [VALUE] [EXTRA]
```

- **`-v` / `--verbose`**: (Optional) Enables detailed logging to the terminal (shows connection attempts).
- **`<MAC_ADDRESS>`**: The Bluetooth MAC address of your connected earbuds (e.g., `AA:BB:CC:DD:EE:FF`).
- **`<FEATURE>`**: The setting or sensor you want to control (e.g., `battery`, `anc`).
- **`<ACTION>`**: What to do. Choices are: `get`, `set`, `connect`, `disconnect`.
- **`[VALUE]`**: (Optional) The state or value you want to apply when using `set`.
- **`[EXTRA]`**: (Optional) Additional argument required by specific commands like `find_my`.

---

## 📖 Reading Device Data (`get`)

Read commands only require `<FEATURE> get` and will output a clean JSON response.

| Command | Description | Example Output |
| :--- | :--- | :--- |
| `battery get` | Reads Left, Right, and Case battery percentages and charging states. | `{"case": {"level": 75, "charging": false}, ...}` |
| `device_info get` | Gets firmware versions and MAC addresses. | `{"firmware": "0.0.8.8", ...}` |
| `anc get` | Returns the current Active Noise Cancellation mode. | `{"anc_mode": "high"}` |
| `eq get` | Returns the active EQ preset. | `{"eq": "dirac"}` |
| `in_ear get` | Gets the status of In-Ear Detection. | `{"in_ear": false}` |
| `low_latency get` | Gets the status of Low Latency (Gaming) mode. | `{"low_latency": false}` |
| `spatial_audio get` | Gets the status of Spatial Audio (Dirac). | `{"spatial_audio": false}` |
| `ultra_bass get` | Returns the Ultra Bass level. | `{"ultra_bass": 5}` |
| `ldac get` | Returns whether LDAC high-res audio is enabled. | `{"ldac": false}` |
| `dual_connect get` | Returns whether Dual Connection (Multipoint) is enabled. | `{"dual_connect": true}` |
| `custom_eq get` | Returns the raw custom EQ frequency/gain data. | `{"custom_eq": [...]}` |
| `devices get` | Lists all saved and active paired devices from the earbuds. | `{"devices": [{"mac": "...", "name": "Phone"}]}` |
| `gestures get` | Lists all currently bound touch gestures. | `{"gestures": [...]}` |

---

## ✍️ Modifying Settings (`set`)

Write commands require a `<VALUE>` to apply.

### Core Audio Features
| Feature | Command Format | Available Values |
| :--- | :--- | :--- |
| **ANC** | `anc set <value>` | `off`, `transparency`, `high`, `mid`, `low`, `adaptive` |
| **EQ Preset** | `eq set <value>` | `dirac`, `pop`, `rock`, `electronic`, `enhanced_vocals`, `classical`, `custom` |
| **Custom EQ** | `custom_eq set <b,m,t>` | Comma separated integers: `<bass>,<mid>,<treble>`. Example: `custom_eq set 5,0,-3` |
| **Ultra Bass** | `ultra_bass set <value>`| `off`, or level `1` through `5` |
| **Spatial Audio** | `spatial_audio set <value>`| `on`, `off` |
| **LDAC** | `ldac set <value>` | `on`, `off` |

### Device Toggles
| Feature | Command Format | Available Values |
| :--- | :--- | :--- |
| **In-Ear Detect** | `in_ear set <value>` | `on`, `off` |
| **Low Latency** | `low_latency set <value>`| `on`, `off` |
| **Dual Connect** | `dual_connect set <value>`| `on`, `off` |

### Special Commands

#### Find My Earbuds
Starts or stops the loud ringing sound to help locate lost earbuds. Requires specifying Left (`L`) or Right (`R`).
- **Start Left Ringing**: `find_my set on L`
- **Stop Left Ringing**: `find_my set off L`
- **Start Right Ringing**: `find_my set on R`

#### Gestures
Binds an action to a specific earbud gesture.
Format: `gestures set <device>,[button_id,],<type>,<action>`
- **Example 1**: `gestures set left,double,skip-forward`
- **Example 2**: `gestures set right,action-hold,volume-up`
- *Note: `button_id` defaults to `1` unless manually specified as the second parameter.*

#### Dual Connection Device Management
Disconnects or connects a specific saved device using its MAC address (grabbed from `devices get`).
- **Connect Device**: `devices connect <TARGET_MAC>`
- **Disconnect Device**: `devices disconnect <TARGET_MAC>`

---

## 🛠️ Troubleshooting & Logs

By default, the script only outputs JSON to standard output. 
If a command fails, or if you need to debug connectivity issues:

1. Use the **verbose flag** to print connection logs to the console:
   ```bash
   python3 main.py -v AA:BB:CC:DD:EE:FF battery get
   ```
2. Read the **persistent background log file**:
   ```bash
   tail -n 20 /tmp/cmf_widget.log
   ```
