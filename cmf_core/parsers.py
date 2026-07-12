"""Parsers for decoding CMF earbud RFCOMM payload responses."""

import struct
import logging
from typing import Dict, Any, List

from .enums import GESTURE_DEVICES, GESTURE_TYPES, GESTURE_ACTIONS

logger = logging.getLogger(__name__)

def parse_battery_response(data: bytes) -> Dict[str, Any]:
    """Parses battery levels for case, left, right, and single buds."""
    if len(data) < 9:
        return {}
    try:
        payload = data[8:]
        if not payload:
            return {}
            
        num_devices = payload[0]
        battery_info = {"case": None, "left": None, "right": None}
        
        for i in range(num_devices):
            offset = 1 + (i * 2)
            if offset + 1 >= len(payload):
                break
                
            device_id = payload[offset]
            raw_byte = payload[offset + 1]
            
            level = int(raw_byte & 0x7F)
            is_charging = (raw_byte & 0x80) != 0
            
            device_info = {"level": level, "charging": is_charging}
            
            if device_id == 0x02:
                battery_info["left"] = device_info
            elif device_id == 0x03:
                battery_info["right"] = device_info
            elif device_id == 0x04:
                battery_info["case"] = device_info
            elif device_id == 0x06:
                battery_info["single"] = device_info
                
        return battery_info
    except Exception as e:
        logger.error(f"Error parsing battery: {e}")
        return {}

def parse_anc_response(data: bytes) -> Dict[str, str]:
    if len(data) < 9:
        return {}
    try:
        payload_length = data[5]
        payload = data[8:8 + payload_length]
        
        # We need at least 2 bytes (state + submode) for ANC
        # We need at least 2 bytes (state + submode) for ANC
        if len(payload) < 2:
            return {}
            
        mode_byte = None
        if len(payload) >= 3:
            # Parse as 3-byte chunks (Key, Value, Padding)
            # CMF Buds: 02 01 00 (Submode=High), 01 05 00 (Mode=Off)
            # Buds Pro 2: 01 07 00 (Mode=Trans), 02 04 00 (Submode=Adapt)
            for i in range(0, len(payload) - 1, 3):
                key = payload[i]
                val = payload[i+1]
                if key == 0x01:
                    mode_byte = val
                    break
                    
        # Fallback to payload[1] for legacy 2-byte payloads or if Key 01 missing
        if mode_byte is None:
            mode_byte = payload[1]
            
        anc_modes = {
            0x05: "off",
            0x07: "transparency",
            0x01: "high",
            0x02: "mid",
            0x03: "low",
            0x04: "adaptive"
        }
        return {"anc_mode": anc_modes.get(mode_byte, "unknown")}
    except Exception as e:
        logger.error(f"Error parsing ANC: {e}")
        return {}

def parse_eq_response(data: bytes) -> Dict[str, Any]:
    if len(data) < 9:
        return {}
    try:
        payload_length = data[5]
        payload = data[8:8 + payload_length]
        
        if len(payload) < 1:
            return {}
            
        # In Swift, if payload.count > 1, it reads payload[1], else payload[0]
        eq_byte = payload[1] if len(payload) > 1 else payload[0]
        eq_presets = {
            0x00: "dirac", 0x01: "rock", 0x02: "electronic",
            0x03: "pop", 0x04: "enhanced_vocals", 0x05: "classical",
            0x06: "custom"
        }
        return {"eq_preset": eq_presets.get(eq_byte, "unknown"), "eq_byte": eq_byte}
    except Exception as e:
        logger.error(f"Error parsing EQ: {e}")
        return {}

def parse_in_ear_response(data: bytes) -> Dict[str, bool]:
    if len(data) < 11:
        return {}
    try:
        enabled = data[10] != 0
        return {"in_ear_detection": enabled}
    except Exception:
        return {}

def parse_latency_response(data: bytes) -> Dict[str, bool]:
    if len(data) < 9:
        return {}
    try:
        enabled = data[8] == 0x01
        return {"low_latency": enabled}
    except Exception:
        return {}

def parse_spatial_audio_response(data: bytes) -> Dict[str, str]:
    if len(data) < 9:
        return {}
    try:
        payload_length = data[5]
        payload = data[8:8 + payload_length]
        
        if not payload:
            return {}
            
        if len(payload) >= 2:
            spatial_modes = {
                (0x00, 0x00): "off", (0x01, 0x00): "fixed",
                (0x01, 0x01): "headTracking", (0x02, 0x00): "concert",
                (0x03, 0x00): "cinema"
            }
            mode = spatial_modes.get((payload[0], payload[1]), "unknown")
        else:
            spatial_modes_single = {0x00: "off", 0x01: "fixed"}
            mode = spatial_modes_single.get(payload[0], "unknown")
            
        return {"spatial_audio": mode}
    except Exception as e:
        logger.error(f"Error parsing spatial audio: {e}")
        return {}

def parse_enhanced_bass_response(data: bytes) -> Dict[str, Any]:
    if len(data) < 9:
        return {}
    try:
        payload_length = data[5]
        payload = data[8:8 + payload_length]
        
        if len(payload) < 2:
            return {}
            
        enabled = payload[0] != 0
        level = int(payload[1]) / 2
        return {"enhanced_bass": {"enabled": enabled, "level": level}}
    except Exception:
        return {}

def parse_firmware_response(data: bytes) -> Dict[str, str]:
    if len(data) < 9:
        return {}
    try:
        firmware = data[8:].decode('utf-8', errors='ignore').strip()
        return {"firmware": firmware}
    except Exception:
        return {}

def parse_device_info_response(data: bytes) -> Dict[str, Any]:
    if len(data) < 9:
        return {}
    try:
        payload = data[8:]
        response_text = payload.decode('utf-8', errors='ignore').strip()
        
        device_map = {2: "right", 3: "left", 4: "case", 6: "single"}
        type_map = {2: "firmware", 4: "serial", 6: "bluetooth_address"}
        
        result = {}
        for line in response_text.split('\n'):
            line = line.strip()
            if not line: continue
            parts = line.split(',')
            if len(parts) < 3: continue
            
            try:
                device_id = int(parts[0])
                info_type = int(parts[1])
                value = parts[2].strip()
                
                device_name = device_map.get(device_id, f"device_{device_id}")
                type_name = type_map.get(info_type, f"type_{info_type}")
                
                if device_name not in result:
                    result[device_name] = {}
                result[device_name][type_name] = value
            except:
                pass
        return result
    except Exception as e:
        logger.error(f"Error parsing device info: {e}")
        return {}

def parse_ldac_response(data: bytes) -> Dict[str, bool]:
    if len(data) < 9: return {}
    try:
        return {"ldac": data[8] != 0}
    except Exception: return {}

def parse_dual_response(data: bytes) -> Dict[str, bool]:
    if len(data) < 9: return {}
    try:
        return {"dual_connection": data[8] != 0}
    except Exception: return {}

def parse_gestures_response(data: bytes) -> Dict[str, List[Dict[str, Any]]]:
    if len(data) < 9: return {}
    try:
        payload = data[8:]
        count = payload[0]
        gestures = []
        for i in range(count):
            off = 1 + (i * 4)
            if off + 4 > len(payload): break
            
            device_str = GESTURE_DEVICES.get(payload[off], f"unknown_{payload[off]:02x}")
            type_str = GESTURE_TYPES.get(payload[off+2], f"unknown_{payload[off+2]:02x}")
            action_str = GESTURE_ACTIONS.get(payload[off+3], f"unknown_{payload[off+3]:02x}")
            
            gestures.append({
                "device": device_str,
                "button_id": payload[off+1],
                "type": type_str,
                "action": action_str
            })
        return {"gestures": gestures}
    except Exception as e:
        logger.error(f"Error parsing gestures: {e}")
        return {}

def parse_custom_eq_response(data: bytes) -> Dict[str, Any]:
    if len(data) < 41: return {}
    try:
        payload = data[8:]
        def read_float(offset):
            return struct.unpack('<f', payload[offset:offset+4])[0]
            
        bass = round(read_float(6))
        mid = round(read_float(19))
        treble = round(read_float(32))
        
        def clamp(val): return max(-6, min(6, int(val)))
        return {"custom_eq": {"bass": clamp(bass), "mid": clamp(mid), "treble": clamp(treble)}}
    except Exception as e:
        logger.error(f"Error parsing custom EQ: {e}")
        return {}

def parse_devices_response(data: bytes) -> Dict[str, Any]:
    if len(data) < 9: return {}
    try:
        payload = data[8:]
        devices = []
        if payload[0] in (0x07, 0x04) and len(payload) >= 11:
            mac = ":".join([f"{b:02X}" for b in payload[4:10]])
            name_len = payload[10]
            name = payload[11:11+name_len].decode('utf-8', errors='ignore').strip()
            devices.append({"mac": mac, "name": name, "status": "Active" if payload[3] != 0 else "Saved", "index": payload[1]})
        elif len(payload) > 3 and payload[0:2] == b'\x01\x00':
            num_devices = payload[2]
            offset = 3
            for i in range(num_devices):
                if offset + 8 > len(payload): break
                status_byte = payload[offset]
                mac = ":".join([f"{b:02X}" for b in payload[offset+1:offset+7]])
                name_len = payload[offset+7]
                if offset + 8 + name_len > len(payload): break
                name = payload[offset+8:offset+8+name_len].decode('utf-8', errors='ignore').strip()
                devices.append({"mac": mac, "name": name, "status": "Active" if status_byte != 0 else "Saved", "index": i})
                offset += 8 + name_len
        return {"devices": devices}
    except Exception as e:
        logger.error(f"Error parsing devices: {e}")
        return {}
