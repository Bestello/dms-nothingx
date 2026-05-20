# DankMaterialShell - CMF Buds Controller

A [DankMaterialShell](https://github.com/DankMaterialShell) plugin to control and monitor CMF by Nothing and Nothing audio devices directly from your desktop widget.

## Features

- **Battery Monitoring**: View real-time battery levels for the Left Bud, Right Bud, and Charging Case.
- **ANC Control**: Switch between Noise Cancellation, Transparency, and Off modes.
- **Equalizer Presets**: Select between various EQ presets (Dirac, Pop, Rock, Electronic, etc.).
- **Toggles**: Easily toggle Spatial Audio, Low Latency (Gaming Mode), and In-Ear Detection.
- **Ultra Bass**: Enable and adjust the Ultra Bass intensity level.

*Note: Features supported will depend on your specific earbud model.*

## Supported Devices

The plugin uses the standard Nothing/CMF Bluetooth RFCOMM protocol, so it should support:
- CMF Buds Pro 2
- CMF Buds / Buds Pro
- CMF Neckband Pro
- Nothing Ear (1), Ear (2), Ear (a)
- Nothing Ear (Stick), Ear (Open)

## Installation

1. Navigate to your DankMaterialShell plugins directory:
   ```bash
   cd ~/.config/DankMaterialShell/plugins/
   ```
2. Clone this repository:
   ```bash
   git clone https://github.com/Bestello/dms-nothingx.git cmfController
   ```
3. Ensure you have `python3` installed on your system with standard bluetooth libraries available.

## Configuration

Before the widget can communicate with your earbuds, you must configure your device's MAC Address:

1. Connect your earbuds to your computer via Bluetooth.
2. Open the **DankMaterialShell Settings**.
3. Navigate to the **Plugins** tab and select the **CMF Buds Pro** plugin.
4. Enter the Bluetooth MAC Address of your earbuds (e.g., `AA:BB:CC:DD:EE:FF`). You can find this in your system's Bluetooth settings.

## Troubleshooting

If the widget fails to connect or update settings:
- Ensure your earbuds are currently connected to your computer via Bluetooth.
- Double-check that the MAC Address in the plugin settings is exactly correct.
- Check the logs located at `/tmp/cmf_widget.log` and `/tmp/cmf_bash.log` for any python or bluetooth connectivity errors.

## License

This project is open-source and free to use. Feel free to contribute or fork!
