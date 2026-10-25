# Nothing X (Dux Shell / DMS)

A [Dux Shell](https://github.com/duxlabs-dev/dux-shell) (formerly DankMaterialShell) plugin to control and monitor CMF by Nothing and Nothing audio devices directly from your desktop bar pill, popout menu, or standalone settings window. Compatible with DMS 2.0+.

## Features

- **Battery Monitoring**: View real-time battery levels for the Left Bud, Right Bud, and Charging Case in the bar pill and popout.
- **ANC Control**: Switch between Noise Cancellation (with Low, Mid, High, Adaptive submodes), Transparency, and Off.
- **Equalizer Presets**: Select between various EQ presets (D-ack, Pop, Rock, Electronic, Enhanced Vocals, Classical) or configure your own Custom EQ sliders.
- **Toggles**: Easily toggle Spatial Audio, Low Latency (Gaming Mode), and In-Ear Detection.
- **Ultra Bass**: Dynamically control your Ultra Bass level (1–5).
- **Find My Earbuds**: Remotely ring your left or right earbud to locate them.


*Note: Available features dynamically adapt to your connected device's configuration profile.*

## Supported Devices

The plugin communicates over the Nothing/CMF Bluetooth RFCOMM protocol.

### CMF by Nothing

| Device | Support Level | Testing Status |
| :--- | :---: | :---: |
| **CMF Buds Pro 2** | Full | ✅ Tested |
| **CMF Buds** | Full | ✅ Tested |
| **CMF Buds 2** | Full | ✅ Tested |
| **CMF Buds Pro** | Partial | ⚠️ Untested |
| **CMF Buds 2a** | Full | ⚠️ Untested |
| **CMF Buds 2 Plus** | Partial | ⚠️ Untested |
| **CMF Neckband Pro** | Not Supported | ⚠️ Untested |
| **CMF Headphone Pro** | Not Supported | ⚠️ Untested |

### Nothing

| Device | Support Level | Testing Status |
| :--- | :---: | :---: |
| **Nothing Ear** | Partial | ⚠️ Untested |
| **Nothing Ear (a)** | Partial | ⚠️ Untested |
| **Nothing Ear (1)** | Partial | ⚠️ Untested |
| **Nothing Ear (2)** | Partial | ⚠️ Untested |
| **Nothing Ear (3)** | Partial | ⚠️ Untested |
| **Nothing Ear (open)** | Partial | ⚠️ Untested |
| **Nothing Ear (stick)** | Partial | ⚠️ Untested |
| **Nothing Headphone (1)** | Not Supported | ⚠️ Untested |


*If you own an untested device, test it out and report your findings or open a PR to help confirm support!*

## Architecture

The plugin uses a two-layer architecture:
- **Backend (`cmf_core`)**: A lightweight Python module and CLI (`main.py`) communicating with the earbuds over Bluetooth RFCOMM socket to read/push state changes as JSON.
- **Frontend (`qml`)**: A native QML interface built with Quickshell and Dux Shell components (`qs.DCommon.Widgets` / `qs.Widgets`), fully styled with the active Material 3 theme.

## Installation

1. Navigate to your DMS plugins directory:
   ```bash
   cd ~/.config/dms/plugins/
   # (or ~/.config/DankMaterialShell/plugins/ on older DMS versions)
   ```
2. Clone this repository:
   ```bash
   git clone https://github.com/Bestello/dms-nothingx.git dmsNothingX
   ```
3. Ensure you have `python3` installed on your system with standard bluetooth socket support available.

## Configuration

Before the widget can communicate with your earbuds, configure your device:

1. Connect your earbuds to your computer via Bluetooth.
2. Open **DMS / Dux Settings**.
3. Navigate to **Plugins** → **DMS Nothing X**.
4. Configure your device settings:
   - **Device Name**: Choose your earbud model from the dropdown (e.g., CMF Buds Pro 2, Nothing Ear, etc.).
   - **Device Color**: Choose your color variant (adjusts bud visual assets in the UI).
   - **Earbuds MAC Address**: Enter your device's Bluetooth MAC address (e.g., `AA:BB:CC:DD:EE:FF`).
   - **Show When Disconnected**: Toggle whether the bar pill stays visible when earbuds are disconnected.

## Troubleshooting

If the widget fails to connect or update settings:
- Ensure your earbuds are connected to your computer via Bluetooth.
- Double-check that the MAC Address in the plugin settings matches your Bluetooth settings exactly.
- Check the logs located at `/tmp/cmf_widget.log` and `/tmp/cmf_bash.log` for any Python or Bluetooth connectivity errors.
- Test CLI communication directly:
  ```bash
  python3 main.py -v AA:BB:CC:DD:EE:FF battery get
  ```

## Credits 

Credits to the creators and maintainers of these projects:
- [nothing-bar](https://github.com/bestK1ngArthur/nothing-bar)
- [Bluetooth-Battery-Meter](https://github.com/maniacx/Bluetooth-Battery-Meter)
- [ear-web](https://github.com/radiance-project/ear-web)

## License

This project is open-source and free to use under the MIT License. Feel free to contribute or fork!
