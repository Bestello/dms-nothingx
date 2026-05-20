#SOMETHING WOKINGV
import socket
import sys
import argparse
import time
from datetime import datetime
import json

def log(message):
    with open("/tmp/cmf_widget.log", "a") as f:
        f.write(f"[{datetime.now().strftime('%H:%M:%S')}] {message}\n")

# ==========================================
# PROTOCOL FUNDAMENTALS
# ==========================================
def calculate_crc16(data: bytes) -> bytes:
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return bytes([crc & 0xFF, (crc >> 8) & 0xFF])

def build_packet(command: int, is_write: bool, payload: list, operation_id: int = 1) -> bytes:
    direction = 0xF0 if is_write else 0xC0
    length = len(payload)
    base_payload = bytes([0x55, 0x60, 0x01, command, direction, length, 0x00, operation_id] + payload)
    checksum = calculate_crc16(base_payload)
    return base_payload + checksum

# ==========================================
# PARSING FUNCTIONS
# ==========================================
def parse_battery_response(data: bytes) -> dict:
    """Parse battery response from the device"""
    if len(data) < 9:
        log(f"Battery response too short: {len(data)} bytes")
        return {}
    
    try:
        payload = data[8:]
        
        if len(payload) < 1:
            return {}
        
        num_devices = payload[0]
        battery_info = {
            "case": None,
            "left": None,
            "right": None
        }
        
        for i in range(num_devices):
            offset = 1 + (i * 2)
            if offset + 1 >= len(payload):
                break
            
            device_id = payload[offset]
            raw_byte = payload[offset + 1]
            
            level = int(raw_byte & 0x7F)
            is_charging = (raw_byte & 0x80) != 0
            
            device_info = {
                "level": level,
                "charging": is_charging
            }
            
            if device_id == 0x02:
                battery_info["left"] = device_info
                log(f"Battery LEFT: {level}% {'(charging)' if is_charging else '(discharging)'}")
            elif device_id == 0x03:
                battery_info["right"] = device_info
                log(f"Battery RIGHT: {level}% {'(charging)' if is_charging else '(discharging)'}")
            elif device_id == 0x04:
                battery_info["case"] = device_info
                log(f"Battery CASE: {level}% {'(charging)' if is_charging else '(discharging)'}")
            elif device_id == 0x06:
                battery_info["single"] = device_info
                log(f"Battery SINGLE: {level}% {'(charging)' if is_charging else '(discharging)'}")
        
        return battery_info
    except Exception as e:
        log(f"Error parsing battery: {e}")
        return {}

def parse_anc_response(data: bytes) -> dict:
    """Parse ANC mode response"""
    if len(data) < 10:
        log(f"ANC response too short: {len(data)} bytes")
        return {}
    
    try:
        payload = data[8:]
        if len(payload) < 2:
            return {}
        
        mode_byte = payload[1]
        
        anc_modes = {
            0x05: "off",
            0x07: "transparency",
            0x01: "high",
            0x02: "mid",
            0x03: "low",
            0x04: "adaptive"
        }
        
        mode = anc_modes.get(mode_byte, "unknown")
        log(f"ANC Mode: {mode}")
        return {"anc_mode": mode}
    except Exception as e:
        log(f"Error parsing ANC: {e}")
        return {}

def parse_eq_response(data: bytes) -> dict:
    """Parse EQ preset response (LISTENING_MODE_NTFY: 0x4050)"""
    if len(data) < 9:  # Header (8) + minimum payload (1)
        return {}
    
    try:
        # Extract payload after 8-byte header
        payload = data[8:]
        
        if len(payload) < 1:
            return {}
        
        # EQ preset is always the first byte of payload
        eq_byte = payload[0]
        
        eq_presets = {
            0x00: "dirac",
            0x01: "rock",
            0x02: "electronic",
            0x03: "pop",
            0x04: "enhanced_vocals",
            0x05: "classical",
            0x06: "custom"
        }
        
        preset = eq_presets.get(eq_byte, "unknown")
        print(f"EQ Preset: {preset}")
        return {"eq_preset": preset, "eq_byte": eq_byte}
        
    except Exception as e:
        print(f"Error parsing EQ: {e}")
        return {}

def parse_in_ear_response(data: bytes) -> dict:
    """Parse in-ear detection response"""
    if len(data) < 11:
        return {}
    
    try:
        payload = data[8:]
        if len(payload) < 3:
            return {}
        
        enabled = payload[2] != 0
        log(f"In-Ear Detection: {'enabled' if enabled else 'disabled'}")
        return {"in_ear_detection": enabled}
    except Exception as e:
        log(f"Error parsing in-ear: {e}")
        return {}

def parse_latency_response(data: bytes) -> dict:
    """Parse low latency response"""
    if len(data) < 9:
        return {}
    
    try:
        payload = data[8:]
        if len(payload) < 1:
            return {}
        
        enabled = payload[0] == 0x01
        log(f"Low Latency (Gaming): {'enabled' if enabled else 'disabled'}")
        return {"low_latency": enabled}
    except Exception as e:
        log(f"Error parsing latency: {e}")
        return {}

def parse_spatial_audio_response(data: bytes) -> dict:
    """Parse spatial audio response"""
    if len(data) < 9:
        log(f"Spatial audio response too short: {len(data)} bytes")
        return {}
    
    try:
        # Extract payload length from byte 5
        payload_length = data[5]
        log(f"Payload length: {payload_length}")
        
        # Extract ONLY the payload bytes (not CRC)
        payload = data[8:8 + payload_length]
        log(f"Spatial audio raw payload ({len(payload)} bytes): {payload.hex().upper()}")
        
        # Debug: log all payload bytes
        for i, b in enumerate(payload):
            log(f"  payload[{i}] = 0x{b:02X}")
        
        if len(payload) < 1:
            log("Payload is empty")
            return {}
        
        # Handle two-byte format (most devices)
        if len(payload) >= 2:
            first_byte = payload[0]
            second_byte = payload[1]
            log(f"Two-byte format: first=0x{first_byte:02X}, second=0x{second_byte:02X}")
            
            spatial_modes = {
                (0x00, 0x00): "off",
                (0x01, 0x00): "fixed",
                (0x01, 0x01): "headTracking",
                (0x02, 0x00): "concert",
                (0x03, 0x00): "cinema"
            }
            mode = spatial_modes.get((first_byte, second_byte), "unknown")
        else:
            # Single byte format (CMF Buds Pro 2, CMF Buds 2, etc.)
            mode_byte = payload[0]
            log(f"Single-byte format: 0x{mode_byte:02X}")
            
            spatial_modes_single = {
                0x00: "off",
                0x01: "fixed",
            }
            mode = spatial_modes_single.get(mode_byte, "unknown")
        
        log(f"Spatial Audio: {mode}")
        return {"spatial_audio": mode}
    except Exception as e:
        log(f"Error parsing spatial audio: {e}")
        import traceback
        log(traceback.format_exc())
        return {}
def parse_enhanced_bass_response(data: bytes) -> dict:
    """Parse enhanced bass response"""
    if len(data) < 10:
        return {}
    
    try:
        payload = data[8:]
        if len(payload) < 2:
            return {}
        
        enabled = payload[0] != 0
        level = int(payload[1]) / 2
        log(f"Enhanced Bass: {'enabled' if enabled else 'disabled'}, Level: {level}")
        return {"enhanced_bass": {"enabled": enabled, "level": level}}
    except Exception as e:
        log(f"Error parsing enhanced bass: {e}")
        return {}

def parse_firmware_response(data: bytes) -> dict:
    """Parse firmware version response"""
    if len(data) < 9:
        return {}
    
    try:
        firmware = data[8:].decode('utf-8', errors='ignore').strip()
        log(f"Firmware: {firmware}")
        return {"firmware": firmware}
    except Exception as e:
        log(f"Error parsing firmware: {e}")
        return {}

def parse_device_info_response(data: bytes) -> dict:
    """Parse device info response (serial/firmware/bluetooth address)"""
    if len(data) < 9:
        return {}
    
    try:
        payload = data[8:]
        response_text = payload.decode('utf-8', errors='ignore').strip()
        
        device_map = {
            2: "right",
            3: "left",
            4: "case",
            6: "single"
        }
        
        type_map = {
            2: "firmware",
            4: "serial",
            6: "bluetooth_address"
        }
        
        result = {}
        lines = response_text.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line or line.isspace():
                continue
            
            parts = line.split(',')
            if len(parts) < 3:
                continue
            
            try:
                device_id = int(parts[0])
                info_type = int(parts[1])
                value = parts[2].strip()
                
                device_name = device_map.get(device_id, f"device_{device_id}")
                type_name = type_map.get(info_type, f"type_{info_type}")
                
                if device_name not in result:
                    result[device_name] = {}
                
                result[device_name][type_name] = value
                log(f"Device {device_name}: {type_name} = {value}")
            except:
                pass
        
        return result
    except Exception as e:
        log(f"Error parsing device info: {e}")
        return {}

def parse_color_from_serial(serial: str) -> dict:
    """Extract device color and model from serial number"""
    if len(serial) < 8:
        return {"color": "unknown", "sku": "", "model": "unknown"}
    
    # SKU color map based on Swift DeviceModel.swift
    sku_to_model = {
        # Nothing Ear 1
        "01": ("Nothing Ear (1)", "white"),
        "02": ("Nothing Ear (1)", "black"),
        "03": ("Nothing Ear (1)", "white"),
        "04": ("Nothing Ear (1)", "black"),
        "06": ("Nothing Ear (1)", "black"),
        "07": ("Nothing Ear (1)", "white"),
        "08": ("Nothing Ear (1)", "black"),
        "10": ("Nothing Ear (1)", "black"),
        
        # Nothing Ear (Stick)
        "14": ("Nothing Ear (Stick)", "default"),
        "15": ("Nothing Ear (Stick)", "default"),
        "16": ("Nothing Ear (Stick)", "default"),
        
        # Nothing Ear (Open)
        "11200005": ("Nothing Ear (Open)", "white"),
        
        # Nothing Ear 2
        "17": ("Nothing Ear (2)", "white"),
        "18": ("Nothing Ear (2)", "white"),
        "19": ("Nothing Ear (2)", "white"),
        "27": ("Nothing Ear (2)", "black"),
        "28": ("Nothing Ear (2)", "black"),
        "29": ("Nothing Ear (2)", "black"),
        
        # Nothing Ear 3
        "25": ("Nothing Ear (3)", "white"),
        "26": ("Nothing Ear (3)", "black"),
        
        # Nothing Ear
        "61": ("Nothing Ear", "black"),
        "62": ("Nothing Ear", "white"),
        "69": ("Nothing Ear", "black"),
        "70": ("Nothing Ear", "white"),
        "74": ("Nothing Ear", "black"),
        "75": ("Nothing Ear", "white"),
        
        # Nothing Ear (a)
        "63": ("Nothing Ear (a)", "black"),
        "64": ("Nothing Ear (a)", "white"),
        "65": ("Nothing Ear (a)", "yellow"),
        "66": ("Nothing Ear (a)", "black"),
        "67": ("Nothing Ear (a)", "white"),
        "68": ("Nothing Ear (a)", "yellow"),
        "71": ("Nothing Ear (a)", "black"),
        "72": ("Nothing Ear (a)", "white"),
        "73": ("Nothing Ear (a)", "yellow"),
        
        # CMF Buds Pro
        "30": ("CMF Buds Pro", "black"),
        "31": ("CMF Buds Pro", "black"),
        "32": ("CMF Buds Pro", "white"),
        "33": ("CMF Buds Pro", "white"),
        "34": ("CMF Buds Pro", "orange"),
        "35": ("CMF Buds Pro", "orange"),
        
        # CMF Neckband Pro
        "48": ("CMF Neckband Pro", "orange"),
        "49": ("CMF Neckband Pro", "white"),
        "50": ("CMF Neckband Pro", "black"),
        "51": ("CMF Neckband Pro", "black"),
        "52": ("CMF Neckband Pro", "white"),
        "53": ("CMF Neckband Pro", "orange"),
        
        # CMF Buds
        "54": ("CMF Buds", "black"),
        "55": ("CMF Buds", "black"),
        "56": ("CMF Buds", "white"),
        "57": ("CMF Buds", "white"),
        "58": ("CMF Buds", "orange"),
        "59": ("CMF Buds", "orange"),
        
        # CMF Buds 2
        "99": ("CMF Buds 2", "dark_grey"),
        
        # CMF Buds Pro 2
        "76": ("CMF Buds Pro 2", "black"),
        "77": ("CMF Buds Pro 2", "white"),
        "78": ("CMF Buds Pro 2", "orange"),
        "79": ("CMF Buds Pro 2", "blue"),
        "80": ("CMF Buds Pro 2", "blue"),
        "81": ("CMF Buds Pro 2", "orange"),
        "82": ("CMF Buds Pro 2", "white"),
        "83": ("CMF Buds Pro 2", "black"),
        
        # Nothing Headphone 1
        "603": ("Nothing Headphone (1)", "black"),
        "606": ("Nothing Headphone (1)", "grey"),
        
        # CMF Headphone Pro
        "84": ("CMF Headphone Pro", "dark_grey"),
        "85": ("CMF Headphone Pro", "light_grey"),
        "86": ("CMF Headphone Pro", "light_green"),
        "87": ("CMF Headphone Pro", "dark_grey"),
        "88": ("CMF Headphone Pro", "light_grey"),
        "89": ("CMF Headphone Pro", "light_green"),
    }
    
    try:
        head_serial = serial[:2]
        sku = ""
        
        if head_serial == "MA":
            # MA prefix: check year, extract positions 6-8
            if len(serial) >= 8:
                year = serial[6:8]
                if year == "22" or year == "23":
                    sku = "14"  # Ear Stick
                elif year == "24":
                    sku = "11200005"  # Ear Open
        
        elif head_serial == "SH" or head_serial == "13":
            # SH or 13 prefix: extract SKU from positions 4-6 (not 2-4!)
            if len(serial) >= 6:
                sku = serial[4:6]
        
        elif head_serial == "M3":
            # M3 prefix: extract SKU from positions 3-6
            if len(serial) >= 6:
                sku = serial[3:6]
        
        # Look up model and color
        if sku in sku_to_model:
            model, color = sku_to_model[sku]
            log(f"Color from serial {serial}: {color}, Model: {model} (SKU: {sku})")
            return {"color": color, "sku": sku, "model": model}
        else:
            log(f"Unknown SKU {sku} from serial {serial}")
            return {"color": "unknown", "sku": sku, "model": "unknown"}
    
    except Exception as e:
        log(f"Error parsing color from serial: {e}")
        return {"color": "unknown", "sku": "", "model": "unknown"}
def read_info(mac_address: str, info_type: str):
    """Read information from the device"""
    try:
        log(f"Connecting to {mac_address} on RFCOMM channel 16...")
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        sock.settimeout(2)
        sock.connect((mac_address, 16))
        
        log(f"Connected! Requesting {info_type}...")
        
        # Command codes (read commands use 0xC0xx format)
        commands = {
            "battery": (0x07, parse_battery_response),
            "firmware": (0x42, parse_firmware_response),
            "device_info": (0x06, parse_device_info_response),
            "anc": (0x1E, parse_anc_response),
            "eq": (0x50, parse_eq_response),
            "in_ear": (0x0E, parse_in_ear_response),
            "latency": (0x41, parse_latency_response),
            "spatial_audio": (0x4F, parse_spatial_audio_response),
            "enhanced_bass": (0x4E, parse_enhanced_bass_response)
        }
        
        if info_type not in commands:
            log(f"Unknown info type: {info_type}")
            sock.close()
            sys.exit(1)
        
        command_code, parser = commands[info_type]
        request_packet = build_packet(command_code, False, [])
        
        log(f"Sending request: {request_packet.hex().upper()}")
        sock.send(request_packet)
        
        time.sleep(0.3)
        try:
            response = sock.recv(1024)
            log(f"Received ({len(response)} bytes): {response.hex().upper()}")
            
            if len(response) > 0:
                result = parser(response)
                
                # For device_info, also parse color if serial is available
                if info_type == "device_info" and result:
                    for device, info in result.items():
                        if "serial" in info:
                            color_info = parse_color_from_serial(info["serial"])
                            result[device]["color"] = color_info["color"]
                            result[device]["sku"] = color_info["sku"]
                
                print(json.dumps(result, indent=2))
        except socket.timeout:
            log(f"No response received for {info_type} (timeout)")
        
        sock.close()
        sys.exit(0)
        
    except Exception as e:
        log(f"CRASH: {e}")
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def send_packet(mac_address: str, packet: bytes):
    try:
        log(f"Connecting to {mac_address} on RFCOMM channel 16...")
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        sock.connect((mac_address, 16))
        
        log("Connected! Sending payload...")
        sock.send(packet)
        
        time.sleep(0.5)
        
        sock.close()
        log("Success: Payload transmitted and socket closed smoothly.")
        sys.exit(0)
    except Exception as e:
        log(f"CRASH: {e}")
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

# ==========================================
# COMMAND PARSING
# ==========================================
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mac")
    parser.add_argument("feature")
    parser.add_argument("value", nargs='?', default=None)
    args = parser.parse_args()

    log(f"--- QML CALLED SCRIPT: feature='{args.feature}', value='{args.value}' ---")

    # Handle read requests
    read_commands = {
        "battery": "battery",
        "firmware": "firmware",
        "device_info": "device_info",
        "serial": "device_info",
        "anc_mode": "anc",
        "eq_mode": "eq",
        "in_ear": "in_ear",
        "latency": "latency",
        "spatial_audio": "spatial_audio",
        "getultra_bass": "enhanced_bass"
    }
    
    if args.feature in read_commands:
        read_info(args.mac, read_commands[args.feature])
        sys.exit(0)

    packet = None

    # ANC Control - Fixed with proper modes
    if args.feature == "anc":
        anc_modes = {
            "off": (0x0F, [0x01, 0x05, 0x00]),          # 0x05 = off
            "transparency": (0x0F, [0x01, 0x07, 0x00]),  # 0x07 = transparency
            "high": (0x0F, [0x01, 0x01, 0x00]),          # 0x01 = high
            "mid": (0x0F, [0x01, 0x02, 0x00]),           # 0x02 = mid
            "low": (0x0F, [0x01, 0x03, 0x00]),           # 0x03 = low
            "adaptive": (0x0F, [0x01, 0x04, 0x00])       # 0x04 = adaptive
        }
        if args.value in anc_modes:
            cmd, payload = anc_modes[args.value]
            packet = build_packet(cmd, True, payload)
        
    elif args.feature == "spatial_toggle":
        toggle = 0x01 if args.value == "on" else 0x00
        packet = build_packet(0x52, True, [toggle, 0x00])

    elif args.feature == "gaming_toggle":
        payload = [0x01, 0x00] if args.value == "on" else [0x02, 0x00]
        packet = build_packet(0x40, True, payload)

    elif args.feature == "in_ear_toggle":
        toggle = 0x01 if args.value == "on" else 0x00
        packet = build_packet(0x04, True, [0x01, 0x01, toggle])

    elif args.feature == "ultra_bass_toggle":
        if args.value == "off":
            packet = build_packet(0x51, True, [0x00, 0x00])
        else:
            try:
                level = int(args.value)
                packet = build_packet(0x51, True, [0x01, level * 2])
            except:
                log(f"Invalid enhanced bass level: {args.value}")
                sys.exit(1)

    elif args.feature == "eq_set":
        eq_presets = {
            "dirac": 0x00,
            "pop": 0x03,
            "rock": 0x01,
            "electronic": 0x02,
            "enhanced_vocals": 0x04,
            "classical": 0x05,
            "custom": 0x06
        }
        if args.value in eq_presets:
            eq_byte = eq_presets[args.value]
            packet = build_packet(0x1D, True, [eq_byte, 0x00])

    if packet:
        send_packet(args.mac, packet)
    else:
        log(f"FAIL: Invalid payload generated for {args.feature}={args.value}")
        sys.exit(1)
