import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "dmsNothingX"

    StyledText {
        width: parent.width
        text: "Nothing/CMF buds Configuration"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    // fech earbuds name and colour
    SelectionSetting {
        id: deviceNameSetting
        settingKey: "deviceName"
        label: "Device Name"
        description: "Choose your Nothing/CMF Buds Name"
        options: [
            { label: "CMF Buds Pro 2", value: "CMF_Buds_Pro_2" },
            { label: "CMF Buds Pro", value: "CMF_Buds_Pro" },
            { label: "CMF Buds", value: "CMF_Buds" },
            { label: "Nothing Ear", value: "Ear" },
            { label: "Nothing Ear (a)", value: "Ear_a" },
            { label: "Nothing Ear (1)", value: "Ear_1" },
            { label: "Nothing Ear (2)", value: "Ear_2" },
            { label: "Nothing Ear (3)", value: "Ear_3" },
            { label: "Nothing Ear (open)", value: "Ear_Open" },
            { label: "Nothing Ear (stick)", value: "Ear_Stick" }
        ]
        defaultValue: "CMF_Buds_Pro_2"
    }

    SelectionSetting {
        settingKey: "deviceColor"
        label: "Device Color"
        description: "Choose your Nothing/CMF Buds Color"
        options: {
            if (deviceNameSetting.value === "CMF_Buds_Pro" || deviceNameSetting.value === "CMF_Buds") {
                return [
                    { label: "Black", value: "black" },
                    { label: "White", value: "white" },
                    { label: "Orange", value: "orange" }
                ]
            } else if (deviceNameSetting.value === "Ear_a") {
                return [
                    { label: "Black", value: "black" },
                    { label: "White", value: "white" },
                    { label: "Yellow", value: "yellow" }
                ]
            } else if (deviceNameSetting.value === "Ear" || deviceNameSetting.value === "Ear_1" || deviceNameSetting.value === "Ear_2" || deviceNameSetting.value === "Ear_3") {
                return [
                    { label: "Black", value: "black" },
                    { label: "White", value: "white" }
                ]
            } else if (deviceNameSetting.value === "Ear_Open" || deviceNameSetting.value === "Ear_Stick") {
                return [
                    { label: "White", value: "white" }
                ]
            } else {
                return [
                    { label: "Black", value: "black" },
                    { label: "White", value: "white" },
                    { label: "Blue", value: "blue" },
                    { label: "Orange", value: "orange" }
                ]
            }
        }
        defaultValue: "black" 
    }



    StringSetting {
        settingKey: "macAddress"
        label: "Earbuds MAC Address"
        description: "Find this in your Bluetooth settings (e.g. AA:BB:CC:DD:EE:FF) paste it and click Enter"
        placeholder: "XX:XX:XX:XX:XX:XX"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "alwaysShowPill"
        label: "Show When Disconnected"
        description: "Keep the earbuds widget visible in the bar even when disconnected"
        defaultValue: true
    }

}
