import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

/*
 * DeviceController.qml
 *
 * This module is responsible for all communication with the Python backend.
 * It manages background processes, fetching state, parsing JSON responses,
 * and executing device commands.
 *
 * It acts as the single source of truth for device status and connection logic,
 * eliminating the need to duplicate Process components across UI files.
 */
Item {
    id: rootController

    // Dependencies to be provided by the parent plugin/widget
    property string pluginDir: ""
    property string macAddress: ""
    property var pluginService: null
    property string pluginId: "dmsNothingX"

    // Exposed State (reactively bound to DMS / Quickshell BluetoothService)
    property bool _ready: false

    readonly property var btDevice: {
        if (!macAddress || !BluetoothService.adapter || !BluetoothService.adapter.devices)
            return null;
        var targetMac = macAddress.trim().toUpperCase();
        if (targetMac === "")
            return null;
        return BluetoothService.adapter.devices.values.find(d => d && (d.address || "").toUpperCase() === targetMac) ?? null;
    }

    readonly property bool isConnected: btDevice ? btDevice.connected : false
    property string deviceName: "CMF_Buds_Pro_2"
    property string deviceColor: "orange"

    readonly property string displayDeviceName: {
        var names = {
            "CMF_Buds_Pro_2": "CMF Buds Pro 2",
            "CMF_Buds_Pro": "CMF Buds Pro",
            "CMF_Buds": "CMF Buds",
            "Ear": "Nothing Ear",
            "Ear_a": "Nothing Ear (a)",
            "Ear_1": "Nothing Ear (1)",
            "Ear_2": "Nothing Ear (2)",
            "Ear_3": "Nothing Ear (3)",
            "Ear_Open": "Nothing Ear (open)",
            "Ear_Stick": "Nothing Ear (stick)"
        };
        return names[deviceName] || deviceName.replace(/_/g, " ");
    }

    readonly property string assetFolder: {
        if (deviceName === "Ear_Open" || deviceName === "Ear_Stick") {
            return deviceName;
        }
        var color = (deviceColor || "black").trim();
        var validColors = {
            "CMF_Buds_Pro_2": ["black", "white", "blue", "orange"],
            "CMF_Buds_Pro": ["black", "white", "orange"],
            "CMF_Buds": ["black", "white", "orange"],
            "Ear": ["black", "white"],
            "Ear_a": ["black", "white", "yellow"],
            "Ear_1": ["black", "white"],
            "Ear_2": ["black", "white"],
            "Ear_3": ["black", "white"]
        };
        var allowed = validColors[deviceName];
        if (allowed && allowed.indexOf(color) === -1) {
            color = allowed[0];
        }
        return deviceName + "_" + color;
    }

    signal stateUpdated(string key, var value)

    // Asset paths for UI and Notifications
    property string leftBudImg: pluginDir + "/assets/" + assetFolder + "/left_bud.png"
    property string rightBudImg: pluginDir + "/assets/" + assetFolder + "/right_bud.png"
    property string notifyIconImg: pluginDir + "/assets/" + assetFolder + "/notify_icon.png"
    property int batteryL: 0
    property int batteryR: 0
    property int batteryC: 0

    // Settings fetch queue logic
    property var settingsFetchQueue: []
    property int settingsFetchIndex: 0

    property var connectedDevices: [] // Used for dual connection devices list

    // Dynamic Capabilities loaded from JSON Config
    property var capabilities: ({})
    property var ancModes: []

    property int initialFetchRetries: 0
    property bool needsInitialSettingsRefresh: false

    onDeviceNameChanged: {
        loadCapabilities();
    }

    function _handleConnectionState(connected) {
        if (connected) {
            initialFetchRetries = 0;
            needsInitialSettingsRefresh = true;
            fetchBattery();
            postConnectBatteryTimer.restart();

            Quickshell.execDetached(["notify-send", "-a", "CMF Audio", "-i", notifyIconImg, displayDeviceName, "Connected and ready"]);
        } else {
            refreshDebounce.stop();
            batteryRetryTimer.stop();
            postConnectBatteryTimer.stop();
            settingsFetchNextTimer.stop();
            settingsFetchQueue = [];
            needsInitialSettingsRefresh = false;
            batteryL = 0;
            batteryR = 0;
            batteryC = 0;
        }
    }

    onIsConnectedChanged: {
        if (_ready) {
            _handleConnectionState(isConnected);
        }
    }

    // ---------------------------------------------------------
    // PUBLIC API
    // ---------------------------------------------------------

    // Sends a command to the device and optionally shows a toast
    function sendCommand(feature, action, value, extra, friendlyName) {
        if (macAddress === "") {
            ToastService.showError("CMF Buds", "Please configure MAC in Settings");
            return;
        }
        if (!isConnected && feature !== "connect" && feature !== "disconnect") {
            ToastService.showError("CMF Buds", "Earbuds are disconnected");
            return;
        }

        var args = ["python3", pluginDir + "/main.py", macAddress, feature, action];

        if (value !== undefined && value !== null && value !== "") {
            args.push(String(value));
        }
        if (extra !== undefined && extra !== null && extra !== "") {
            args.push(String(extra));
        }

        Quickshell.execDetached(args);

        if (friendlyName && friendlyName !== "") {
            ToastService.showInfo("Buds", "Set: " + friendlyName);
        }
    }

    // Fetches the latest battery levels
    function fetchBattery() {
        if (!isConnected || macAddress === "" || pluginDir === "")
            return;
        if (batteryProcess.running || settingsFetchProcess.running) {
            refreshDebounce.restart();
            return;
        }

        batteryProcess.command = ["python3", pluginDir + "/main.py", macAddress, "battery", "get"];
        batteryProcess.running = true;
    }

    // Starts the sequential fetching of all device settings
    function startSettingsRefresh() {
        if (!isConnected || macAddress === "" || pluginDir === "")
            return;
        settingsFetchQueue = [
            {
                feature: "anc",
                action: "get"
            },
            {
                feature: "eq",
                action: "get"
            },
            {
                feature: "spatial_audio",
                action: "get"
            },
            {
                feature: "low_latency",
                action: "get"
            },
            {
                feature: "in_ear",
                action: "get"
            },
            {
                feature: "ultra_bass",
                action: "get"
            }
        ];
        settingsFetchIndex = 0;
        settingsFetchNextTimer.start();
    }

    // Fetches connected devices (used by Dual Connection page)
    function fetchDevices() {
        if (isConnected && macAddress !== "" && pluginDir !== "" && !deviceFetchProcess.running) {
            deviceFetchProcess.command = ["python3", pluginDir + "/main.py", macAddress, "devices", "get"];
            deviceFetchProcess.running = true;
        }
    }

    // Safely update persistent state via PluginService
    function updateState(key, value) {
        stateUpdated(key, value);
        if (pluginService) {
            pluginService.savePluginData(pluginId, key, value);
        }
    }

    // Load device capabilities from local configs
    Timer {
        id: capabilitiesDebounceTimer
        interval: 20
        onTriggered: {
            if (capabilitiesProcess.running) {
                capabilitiesDebounceTimer.start();
                return;
            }
            if (!pluginDir || pluginDir === "" || !deviceName) return;
            var configMap = {
                "CMF_Buds_Pro_2": "CMFBudsPro2",
                "CMF_Buds_Pro": "BudsPro",
                "CMF_Buds": "CMFBuds",
                "Ear": "NothingEar",
                "Ear_a": "NothingEarA",
                "Ear_1": "NothingEar1",
                "Ear_2": "Ear2",
                "Ear_3": "NothingEar3",
                "Ear_Open": "NothingEarOpen",
                "Ear_Stick": "EarStick"
            };
            var configName = configMap[deviceName] || deviceName.replace(/_/g, "");
            capabilitiesProcess.command = ["cat", pluginDir + "/configs/" + configName + ".json"];
            capabilitiesProcess.running = true;
        }
    }

    function loadCapabilities() {
        capabilitiesDebounceTimer.restart();
    }

    // ---------------------------------------------------------
    // INTERNAL LOGIC & PROCESSES
    // ---------------------------------------------------------

    function _fetchNextSetting() {
        if (!isConnected || macAddress === "" || pluginDir === "")
            return;
        if (settingsFetchIndex >= settingsFetchQueue.length)
            return;
        if (settingsFetchProcess.running || batteryProcess.running) {
            settingsFetchNextTimer.start(); // back off and retry
            return;
        }
        var task = settingsFetchQueue[settingsFetchIndex];
        settingsFetchIndex++;
        settingsFetchProcess.currentSetting = task.feature;
        settingsFetchProcess.command = ["python3", pluginDir + "/main.py", macAddress, task.feature, task.action];
        settingsFetchProcess.running = true;
    }

    function _applySettingResponse(setting, jsonBuffer) {
        if (!pluginService)
            return;
        try {
            var jsonStart = jsonBuffer.indexOf("{");
            var jsonEnd = jsonBuffer.lastIndexOf("}");
            if (jsonStart === -1 || jsonEnd === -1)
                return;
            var data = JSON.parse(jsonBuffer.substring(jsonStart, jsonEnd + 1));

            if (setting === "anc" && data.anc_mode !== undefined && data.anc_mode !== "unknown") {
                var mode = data.anc_mode;
                if (mode === "off") {
                    updateState("currentMode", "off");
                } else if (mode === "transparency") {
                    updateState("currentMode", "transparency");
                } else {
                    updateState("currentMode", "anc");
                    updateState("ancSubMode", mode);
                }
            } else if (setting === "eq" && data.eq_preset !== undefined && data.eq_preset !== "unknown") {
                updateState("eqPreset", data.eq_preset);
            } else if (setting === "spatial_audio" && data.spatial_audio !== undefined && data.spatial_audio !== "unknown") {
                updateState("spatialAudio", (data.spatial_audio !== "off" && data.spatial_audio !== false));
            } else if (setting === "low_latency" && data.low_latency !== undefined) {
                updateState("gamingMode", (data.low_latency !== "off" && data.low_latency !== false));
            } else if (setting === "in_ear" && data.in_ear_detection !== undefined) {
                updateState("inEarDetection", (data.in_ear_detection !== "off" && data.in_ear_detection !== false));
            } else if (setting === "ultra_bass" && data.enhanced_bass !== undefined) {
                updateState("ultraBass", (data.enhanced_bass.enabled !== false));
            }
        } catch (e) {
            console.log("Error applying setting response: " + e);
        }
    }

    // Settings Fetch Process
    Process {
        id: settingsFetchProcess
        property string jsonBuffer: ""
        property string currentSetting: ""

        stdout: SplitParser {
            onRead: function (line) {
                settingsFetchProcess.jsonBuffer += line + "\n";
            }
        }

        onExited: function (code) {
            if (code === 0 && settingsFetchProcess.jsonBuffer.trim().length > 0) {
                _applySettingResponse(settingsFetchProcess.currentSetting, settingsFetchProcess.jsonBuffer);
            }
            settingsFetchProcess.jsonBuffer = "";
            settingsFetchNextTimer.start();
        }
    }

    Timer {
        id: settingsFetchNextTimer
        interval: 50
        repeat: false
        onTriggered: _fetchNextSetting()
    }


    // Config / Capabilities Fetch Process
    Process {
        id: capabilitiesProcess
        property string jsonBuffer: ""

        stdout: SplitParser {
            onRead: function (line) {
                capabilitiesProcess.jsonBuffer += line + "\n";
            }
        }

        onExited: function (code) {
            if (code === 0 && capabilitiesProcess.jsonBuffer.trim().length > 0) {
                try {
                    var json = JSON.parse(capabilitiesProcess.jsonBuffer);
                    if (json.capabilities) {
                        json.capabilities["find_my"] = true;
                        rootController.capabilities = json.capabilities;
                    }
                    if (json.anc_modes) {
                        rootController.ancModes = json.anc_modes;
                    }
                } catch (e) {
                    console.log("Error parsing config JSON: " + e);
                }
            }
            capabilitiesProcess.jsonBuffer = "";
        }
    }

    // Battery Fetch Process
    Process {
        id: batteryProcess
        property string jsonBuffer: ""

        stdout: SplitParser {
            onRead: function (line) {
                batteryProcess.jsonBuffer += line + "\n";
            }
        }

        onExited: function (code) {
            if (code === 0 && batteryProcess.jsonBuffer.trim().length > 0) {
                try {
                    var jsonStart = batteryProcess.jsonBuffer.indexOf("{");
                    var jsonEnd = batteryProcess.jsonBuffer.lastIndexOf("}");
                    if (jsonStart !== -1 && jsonEnd !== -1) {
                        var cleanJson = batteryProcess.jsonBuffer.substring(jsonStart, jsonEnd + 1);
                        var data = JSON.parse(cleanJson);
                        batteryL = (data.left && data.left.level !== null) ? data.left.level : 0;
                        batteryR = (data.right && data.right.level !== null) ? data.right.level : 0;
                        batteryC = (data["case"] && data["case"].level !== null) ? data["case"].level : 0;
                    }
                } catch (e) {}
            }
            batteryProcess.jsonBuffer = "";

            if (isConnected) {
                if (batteryL === 0 && batteryR === 0 && initialFetchRetries < 5) {
                    initialFetchRetries++;
                    batteryRetryTimer.restart();
                } else if (needsInitialSettingsRefresh) {
                    needsInitialSettingsRefresh = false;
                    startSettingsRefresh();
                }
            }
        }
    }

    // Device List Fetch Process
    Process {
        id: deviceFetchProcess
        property string jsonBuffer: ""

        stdout: SplitParser {
            onRead: function (line) {
                if (line.trim().length > 0) {
                    deviceFetchProcess.jsonBuffer += line + "\n";
                }
            }
        }

        onExited: function (code) {
            if (code === 0 && jsonBuffer.trim().length > 0) {
                try {
                    var jsonStart = jsonBuffer.indexOf("{");
                    var jsonEnd = jsonBuffer.lastIndexOf("}");
                    if (jsonStart !== -1 && jsonEnd !== -1) {
                        var cleanJson = jsonBuffer.substring(jsonStart, jsonEnd + 1);
                        var data = JSON.parse(cleanJson);
                        if (data.devices) {
                            connectedDevices = data.devices;
                        }
                    }
                } catch (e) {
                    console.log("Error parsing devices JSON: " + e);
                }
            }
            jsonBuffer = "";
        }
    }

    Timer {
        id: refreshDebounce
        interval: 500
        repeat: false
        onTriggered: fetchBattery()
    }

    Timer {
        id: batteryRetryTimer
        interval: 1500
        repeat: false
        onTriggered: fetchBattery()
    }

    Timer {
        id: postConnectBatteryTimer
        interval: 3500
        repeat: false
        onTriggered: fetchBattery()
    }

    Timer {
        id: mainBatteryTimer
        interval: 60000
        running: isConnected && macAddress !== ""
        repeat: true
        onTriggered: refreshDebounce.restart()
    }

    Component.onCompleted: {
        _ready = true;
        loadCapabilities();
        if (isConnected) {
            _handleConnectionState(true);
        }
    }
}
