"""Configuration manager for dynamic device capabilities."""

import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

class ConfigManager:
    """Handles dynamic loading of device configuration profiles."""

    def __init__(self, configs_dir: Path):
        """Initializes the ConfigManager and loads all profiles.
        
        Args:
            configs_dir: The Path object pointing to the directory containing JSON configs.
        """
        self.configs_dir = configs_dir
        self.profiles: Dict[str, dict] = {}
        self._load_all_profiles()

    def _load_all_profiles(self) -> None:
        """Loads all JSON device profiles from the configuration directory."""
        if not self.configs_dir.exists():
            logger.warning(f"Configuration directory {self.configs_dir} does not exist.")
            return

        for config_file in self.configs_dir.glob("*.json"):
            try:
                with open(config_file, "r") as f:
                    profile = json.load(f)
                    device_id = profile.get("device_id")
                    if device_id is not None:
                        # Store by string ID
                        self.profiles[str(device_id)] = profile
            except Exception as e:
                logger.error(f"Failed to load {config_file.name}: {e}")

    def get_device_config(self, device_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves capabilities and parameters for a specific device.
        
        Args:
            device_id: The identifier of the device.
            
        Returns:
            The loaded configuration dictionary, or None.
        """
        return self.profiles.get(str(device_id))

    def is_feature_supported(self, device_id: str, feature: str) -> bool:
        """Checks if a device supports a specific capability.
        
        Args:
            device_id: The identifier of the device.
            feature: The feature key to check.
            
        Returns:
            True if supported, False otherwise.
        """
        config = self.get_device_config(device_id)
        if not config:
            return False
        return config.get("capabilities", {}).get(feature, False)
