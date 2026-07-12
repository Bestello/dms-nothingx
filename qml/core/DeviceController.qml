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

    // Exposed State
    property bool isConnected: false
    property string deviceName: "CMF_Buds_Pro_2"
    property string deviceColor: "orange"

    signal stateUpdated(string key, var value)

    // Asset paths for UI and Notifications
    property string leftBudImg: pluginDir + "/assets/" + deviceName + "_" + deviceColor + "/left_bud.png"
    property string rightBudImg: pluginDir + "/assets/" + deviceName + "_" + deviceColor + "/right_bud.png"
    property string notifyIconImg: pluginDir + "/assets/" + deviceName + "_" + deviceColor + "/notify_icon.png"
    property string caseImg: pluginDir + "/assets/" + deviceName + "_" + deviceColor + "/case.png"
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

    onDeviceNameChanged: {
        loadCapabilities();
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

        var script = pluginDir + "/main.py";
        var cmdArgs = macAddress + " " + feature + " " + action;

        if (value !== undefined && value !== null && value !== "") {
            cmdArgs += " " + value;
        }
        if (extra !== undefined && extra !== null && extra !== "") {
            cmdArgs += " " + extra;
        }

        var cmd = "python3 " + script + " " + cmdArgs + " >> /tmp/cmf_bash.log 2>&1";
        Quickshell.execDetached(["sh", "-c", cmd]);

        if (friendlyName && friendlyName !== "") {
            ToastService.showInfo("Buds", "Set: " + friendlyName);
        }
    }

    // Fetches the latest battery levels
    function fetchBattery() {
        if (!isConnected || macAddress === "")
            return;
        if (batteryProcess.running)
            return;

        batteryProcess.command = ["python3", pluginDir + "/main.py", macAddress, "battery", "get"];
        batteryProcess.running = true;
    }

    // Starts the sequential fetching of all device settings
    function startSettingsRefresh() {
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
        if (macAddress !== "" && !deviceFetchProcess.running) {
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
            var configName = deviceName.replace(/_/g, "");
            if (configName === "CMFBudsPro2") {
                configName = "CMFBudspro2";
            }
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
        if (!isConnected || macAddress === "")
            return;
        if (settingsFetchIndex >= settingsFetchQueue.length)
            return;
        if (settingsFetchProcess.running) {
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

    // Connection Check Process
    Process {
        id: connectionCheckProcess
        onExited: function (code) {
            var connected = (code === 0);
            if (connected !== isConnected) {
                isConnected = connected;
                if (connected) {
                    fetchBattery();
                    refreshDebounce.restart();
                    startSettingsRefresh();

                    var displayDeviceName = deviceName.replace(/_/g, " ");
                    Quickshell.execDetached(["notify-send", "-a", "CMF Audio", "-i", notifyIconImg, displayDeviceName, "Connected and ready"]);
                } else {
                    batteryL = 0;
                    batteryR = 0;
                    batteryC = 0;
                }
            }
        }
    }

    Timer {
        id: connCheckTimer
        interval: 5000
        running: macAddress !== ""
        repeat: true
        onTriggered: {
            if (!connectionCheckProcess.running) {
                connectionCheckProcess.command = ["sh", "-c", "bluetoothctl info " + macAddress + " | grep -q 'Connected: yes'"];
                connectionCheckProcess.running = true;
            }
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
        id: mainBatteryTimer
        interval: 60000
        running: isConnected && macAddress !== ""
        repeat: true
        onTriggered: refreshDebounce.restart()
    }

    Component.onCompleted: {
        loadCapabilities();
        if (macAddress !== "") {
            connectionCheckProcess.command = ["sh", "-c", "bluetoothctl info " + macAddress + " | grep -q 'Connected: yes'"];
            connectionCheckProcess.running = true;
        }
    }
}
