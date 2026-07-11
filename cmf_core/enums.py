"""Constants and Enums for CMF / Nothing earbuds protocol."""

from enum import Enum, IntEnum
from typing import Dict

class CommandType(IntEnum):
    BATTERY = 0x07
    DEVICE_INFO = 0x06
    FIRMWARE = 0x42
    ANC = 0x1E
    EQ = 0x50
    IN_EAR = 0x0E
    LATENCY = 0x41
    SPATIAL_AUDIO = 0x4F
    ENHANCED_BASS = 0x4E
    LDAC = 0x29
    DUAL_CONNECTION = 0x27
    CUSTOM_EQ = 0x44
    DEVICES = 0x28
    GESTURES = 0x18

GESTURE_DEVICES: Dict[int, str] = {
    0x02: "left",
    0x03: "right",
    0x04: "dial"
}

GESTURE_TYPES: Dict[int, str] = {
    0x01: "single",
    0x02: "double",
    0x03: "triple",
    0x07: "action-hold",
    0x09: "double-action-hold",
    0x0A: "rotate",
    0x0B: "long-press"
}

GESTURE_ACTIONS: Dict[int, str] = {
    0x01: "no-action",
    0x02: "play-pause",
    0x03: "previous-track",
    0x04: "volume-up",
    0x05: "volume-down",
    0x06: "voice-assistant",
    0x07: "anc-toggle",
    0x08: "skip-back",
    0x09: "skip-forward",
    0x0A: "noise-control",
    0x0B: "voice-assistant",
    0x11: "case-game-mode",
    0x12: "volume-up",
    0x13: "volume-down",
    0x14: "noise-control",
    0x15: "noise-control",
    0x16: "noise-control",
    0x17: "volume-control",
    0x1A: "volume-control"
}

REV_GESTURE_DEVICES = {v: k for k, v in GESTURE_DEVICES.items()}
REV_GESTURE_TYPES = {v: k for k, v in GESTURE_TYPES.items()}
REV_GESTURE_ACTIONS = {
    "no-action": 0x01,
    "play-pause": 0x02,
    "previous-track": 0x03,
    "volume-up": 0x12,
    "volume-down": 0x13,
    "voice-assistant": 0x0B,
    "anc-toggle": 0x07,
    "skip-back": 0x08,
    "skip-forward": 0x09,
    "noise-control": 0x16,
    "case-game-mode": 0x11,
    "volume-control": 0x17
}

ANC_MODES: Dict[str, tuple] = {
    "off": (0x0F, [0x01, 0x05, 0x00]),
    "on": (0x0F, [0x01, 0x02, 0x00]),
    "transparency": (0x0F, [0x01, 0x07, 0x00]),
    "high": (0x0F, [0x01, 0x01, 0x00]),
    "mid": (0x0F, [0x01, 0x02, 0x00]),
    "low": (0x0F, [0x01, 0x03, 0x00]),
    "adaptive": (0x0F, [0x01, 0x04, 0x00])
}

EQ_PRESETS: Dict[str, int] = {
    "dirac": 0x00,
    "pop": 0x03,
    "rock": 0x01,
    "electronic": 0x02,
    "enhanced_vocals": 0x04,
    "classical": 0x05,
    "custom": 0x06
}

