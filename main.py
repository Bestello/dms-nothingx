"""Main CLI entrypoint for CMF / Nothing earbuds controller."""

import argparse
import sys
import json
import logging
from pathlib import Path

from cmf_core.device_manager import DeviceManager
from cmf_core.config_loader import ConfigManager
from cmf_core.protocol import encode_custom_eq_payload
from cmf_core import parsers
from cmf_core.enums import (
    CommandType,
    ANC_MODES,
    EQ_PRESETS,
    REV_GESTURE_DEVICES,
    REV_GESTURE_TYPES,
    REV_GESTURE_ACTIONS
)

logger = logging.getLogger(__name__)

# Map readable features to their Hex Command and Parser function
GET_MAPPINGS = {
    "battery": (CommandType.BATTERY, parsers.parse_battery_response),
    "device_info": (CommandType.DEVICE_INFO, parsers.parse_device_info_response),
    "anc": (CommandType.ANC, parsers.parse_anc_response),
    "eq": (CommandType.EQ, parsers.parse_eq_response),
    "in_ear": (CommandType.IN_EAR, parsers.parse_in_ear_response),
    "low_latency": (CommandType.LATENCY, parsers.parse_latency_response),
    "spatial_audio": (CommandType.SPATIAL_AUDIO, parsers.parse_spatial_audio_response),
    "ultra_bass": (CommandType.ENHANCED_BASS, parsers.parse_enhanced_bass_response),
    "ldac": (CommandType.LDAC, parsers.parse_ldac_response),
    "dual_connect": (CommandType.DUAL_CONNECTION, parsers.parse_dual_response),
    "custom_eq": (CommandType.CUSTOM_EQ, parsers.parse_custom_eq_response),
    "devices": (CommandType.DEVICES, parsers.parse_devices_response),
    "gestures": (CommandType.GESTURES, parsers.parse_gestures_response)
}

def handle_get(device: DeviceManager, feature: str) -> None:
    """Handles read commands.
    
    Args:
        device: Connected DeviceManager instance.
        feature: The feature to query.
    """
    if feature not in GET_MAPPINGS:
        logger.error(f"Unsupported get feature: {feature}")
        sys.exit(1)
        
    cmd_code, parser_func = GET_MAPPINGS[feature]
    
    try:
        if feature == "devices":
            # Devices require multiple iterative queries (slots 0-9)
            all_devices = []
            seen_macs = set()
            for i in range(10):
                response = device.send_command(cmd_code, False, [i])
                if response:
                    res = parser_func(response)
                    if res and "devices" in res:
                        for d in res["devices"]:
                            if d["mac"] not in seen_macs:
                                seen_macs.add(d["mac"])
                                all_devices.append(d)
            print(json.dumps({"devices": all_devices}, indent=2))
        else:
            response = device.send_command(cmd_code, False, [])
            if response:
                parsed_data = parser_func(response)
                print(json.dumps(parsed_data, indent=2))
            else:
                logger.error("No response received from device.")
    except Exception as e:
        logger.error(f"Failed to read {feature}: {e}")
        sys.exit(1)

def handle_set(device: DeviceManager, feature: str, value: str, extra: str = None) -> None:
    """Handles write commands.
    
    Args:
        device: Connected DeviceManager instance.
        feature: The feature to configure.
        value: The value string to set.
        extra: Optional secondary argument.
    """
    if not value:
        logger.error("Set command requires a value.")
        sys.exit(1)

    cmd_code = None
    payload = []

    if feature == "anc":
        if value not in ANC_MODES:
            logger.error(f"Invalid ANC mode. Choices: {list(ANC_MODES.keys())}")
            sys.exit(1)
        cmd_code, payload = ANC_MODES[value]

    elif feature == "spatial_audio":
        cmd_code = 0x52
        payload = [0x01 if value == "on" else 0x00, 0x00]

    elif feature == "low_latency":
        cmd_code = 0x40
        payload = [0x01, 0x00] if value == "on" else [0x02, 0x00]

    elif feature == "in_ear":
        cmd_code = 0x04
        payload = [0x01, 0x01, 0x01 if value == "on" else 0x00]

    elif feature == "ultra_bass":
        cmd_code = 0x51
        if value == "off":
            payload = [0x00, 0x00]
        else:
            try:
                payload = [0x01, int(value) * 2]
            except ValueError:
                logger.error("Invalid enhanced bass level. Must be 'off' or an integer.")
                sys.exit(1)

    elif feature == "eq":
        if value not in EQ_PRESETS:
            logger.error(f"Invalid EQ preset. Choices: {list(EQ_PRESETS.keys())}")
            sys.exit(1)
        cmd_code = 0x1D
        payload = [EQ_PRESETS[value], 0x00]

    elif feature == "ldac":
        cmd_code = 0x1C
        payload = [0x02 if value == "on" else 0x00]

    elif feature == "dual_connect":
        cmd_code = 0x1A
        payload = [0x01 if value == "on" else 0x00]

    elif feature == "custom_eq":
        cmd_code = 0x41
        try:
            parts = value.split(',')
            bass, mid, treble = int(parts[0]), int(parts[1]), int(parts[2])
            payload = encode_custom_eq_payload(bass, mid, treble)
        except Exception:
            logger.error("Custom EQ requires exactly 3 comma-separated integers (e.g. 5,0,-3).")
            sys.exit(1)

    elif feature == "gestures":
        cmd_code = CommandType.SET_GESTURE
        try:
            parts = value.split(',')
            if len(parts) == 3:
                device_str, type_str, action_str = parts
                button_id = 1
            elif len(parts) == 4:
                device_str, btn_str, type_str, action_str = parts
                button_id = int(btn_str, 0)
            else:
                raise ValueError()
                
            device_byte = REV_GESTURE_DEVICES.get(device_str)
            type_byte = REV_GESTURE_TYPES.get(type_str)
            action_byte = REV_GESTURE_ACTIONS.get(action_str)
            
            if None in (device_byte, type_byte, action_byte):
                logger.error("Invalid gesture mapping parameters.")
                sys.exit(1)
                
            payload = [0x01, device_byte, button_id, type_byte, action_byte]
        except Exception:
            logger.error("Gestures require format: device,[button_id,]type,action")
            sys.exit(1)

    elif feature == "find_my":
        cmd_code = 0x02
        if value == "off":
            if extra == "L": payload = [0x02, 0x00]
            elif extra == "R": payload = [0x03, 0x00]
            else:
                logger.error("find_my requires L or R extra param")
                sys.exit(1)
        elif value == "on":
            if extra == "L": payload = [0x02, 0x01]
            elif extra == "R": payload = [0x03, 0x01]
            else:
                logger.error("find_my requires L or R extra param")
                sys.exit(1)

    if cmd_code is not None:
        device.send_command(cmd_code, True, payload)
        logger.info(f"Successfully set {feature}.")
    else:
        logger.error(f"Unsupported set feature: {feature}")
        sys.exit(1)

def handle_devices(device: DeviceManager, action: str, value: str) -> None:
    """Handles device connection/disconnection via the earbuds.
    
    Args:
        device: Connected DeviceManager instance.
        action: 'connect' or 'disconnect'.
        value: The MAC address to act upon.
    """
    if not value:
        logger.error("Device operation requires a MAC address target.")
        sys.exit(1)
        
    try:
        target_mac = bytes.fromhex(value.replace(":", ""))
        action_byte = 0x01 if action == "disconnect" else 0x00
        payload = [action_byte] + list(target_mac)
        device.send_command(0x1B, True, payload)
        logger.info(f"Successfully sent {action} command for {value}.")
    except Exception as e:
        logger.error(f"Error parsing MAC address: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="CMF/Nothing Earbuds Controller")
    parser.add_argument("mac", help="MAC address of the connected earbuds")
    parser.add_argument("feature", help="Feature to control (anc, eq, battery, etc)")
    parser.add_argument("action", choices=["get", "set", "connect", "disconnect"], help="Action to perform")
    parser.add_argument("value", nargs='?', default=None, help="Value for set/connect actions")
    parser.add_argument("extra", nargs='?', default=None, help="Extra param (e.g. L or R for find_my)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    # Configure logging
    log_level = logging.INFO if args.verbose else logging.WARNING
    
    # Root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    # Always log everything (DEBUG and up) to the file
    file_handler = logging.FileHandler("/tmp/cmf_widget.log", mode="a")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    
    # Only log WARNING (or INFO if verbose) to stderr to keep stdout clean for JSON
    console_handler = logging.StreamHandler(sys.stderr)
    console_handler.setLevel(log_level)
    console_handler.setFormatter(formatter)
    
    # Clear any existing handlers and add ours
    root_logger.handlers = []
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)
    
    # Load Configurations
    config_dir = Path(__file__).parent / "configs"
    config_mgr = ConfigManager(config_dir)
    
    # Optional: We could check if feature is supported by config_mgr here, 
    # but for manual CLI use, we just attempt it.

    try:
        with DeviceManager(args.mac) as device:
            if args.action == "get":
                handle_get(device, args.feature)
            elif args.action == "set":
                handle_set(device, args.feature, args.value, args.extra)
            elif args.feature == "devices" and args.action in ("connect", "disconnect"):
                handle_devices(device, args.action, args.value)
            else:
                logger.error("Invalid action/feature combination.")
                sys.exit(1)
    except Exception as e:
        logger.error(f"Failed to communicate with device {args.mac}: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
