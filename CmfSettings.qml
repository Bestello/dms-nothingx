import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "cmfController"

    StyledText {
        width: parent.width
        text: "CMF Buds Pro 2 Configuration"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "macAddress"
        label: "Earbuds MAC Address"
        description: "Find this in your Bluetooth settings (e.g. AA:BB:CC:DD:EE:FF)"
        placeholder: "XX:XX:XX:XX:XX:XX"
        defaultValue: ""
    }
}
