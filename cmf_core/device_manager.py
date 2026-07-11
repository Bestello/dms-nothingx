"""Device Manager handling RFCOMM socket lifecycle and transmission."""

import socket
import logging
import time
import os
from typing import Optional, List

from .protocol import build_packet

logger = logging.getLogger(__name__)

CACHE_DIR = os.path.expanduser("~/.cache/dms_nothingx")

def get_rfcomm_port(mac_address: str, force_scan: bool = False) -> int:
    """Discover the RFCOMM port using SDP or cached values.
    
    Args:
        mac_address: The Bluetooth MAC address.
        force_scan: Whether to ignore the cache.
        
    Returns:
        The valid RFCOMM port number.
    """
    if not os.path.exists(CACHE_DIR):
        os.makedirs(CACHE_DIR, exist_ok=True)
        
    cache_file = os.path.join(CACHE_DIR, f"{mac_address.replace(':', '')}.port")
    
    if not force_scan and os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                port = int(f.read().strip())
                return port
        except:
            pass
            
    logger.info("Scanning for active RFCOMM ports...")
    
    try:
        import bluetooth
        services = bluetooth.find_service(address=mac_address)
        for svc in services:
            if svc["protocol"] == "RFCOMM":
                port = svc["port"]
                with open(cache_file, "w") as f:
                    f.write(str(port))
                return port
    except ImportError:
        pass
        
    for port in range(1, 31):
        try:
            sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            sock.settimeout(0.5)
            sock.connect((mac_address, port))
            sock.send(build_packet(0x06, False, []))
            data = sock.recv(1024)
            sock.close()
            
            if len(data) > 0 and data[0] == 0x55:
                logger.info(f"Found valid service on port {port}")
                with open(cache_file, "w") as f:
                    f.write(str(port))
                return port
        except:
            pass
            
    logger.warning("Failed to find open RFCOMM port. Defaulting to 15.")
    return 15

class DeviceManager:
    """Manages RFCOMM Bluetooth connections and command orchestration."""

    def __init__(self, mac_address: str):
        self.mac_address = mac_address
        self._socket: Optional[socket.socket] = None

    def connect(self) -> None:
        """Establishes an RFCOMM connection to the device."""
        port = get_rfcomm_port(self.mac_address)
        logger.info(f"Attempting connection to {self.mac_address} on port {port}...")
        
        try:
            self._socket = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            self._socket.settimeout(2.0)
            self._socket.connect((self.mac_address, port))
            logger.info("Connection established successfully.")
        except Exception as e:
            logger.warning(f"Connection failed on port {port} ({e}), forcing rescan...")
            port = get_rfcomm_port(self.mac_address, force_scan=True)
            self._socket = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            self._socket.settimeout(2.0)
            self._socket.connect((self.mac_address, port))
            logger.info(f"Connection established on new port {port}.")

    def disconnect(self) -> None:
        """Safely closes the Bluetooth socket."""
        if self._socket:
            try:
                self._socket.close()
            except Exception as e:
                logger.error(f"Error during disconnect: {e}")
            finally:
                self._socket = None

    def send_raw(self, data: bytes) -> None:
        """Sends raw bytes over the socket.
        
        Args:
            data: Raw bytes to send.
        """
        if not self._socket:
            raise ConnectionError("Device is not connected.")
        self._socket.send(data)

    def receive_raw(self, buffer_size: int = 1024) -> bytes:
        """Receives raw bytes from the socket.
        
        Args:
            buffer_size: Maximum bytes to read.
            
        Returns:
            The received byte string.
        """
        if not self._socket:
            raise ConnectionError("Device is not connected.")
        return self._socket.recv(buffer_size)

    def send_command(self, command_code: int, is_write: bool, payload: List[int]) -> bytes:
        """Builds and transmits a command packet, returning the raw response.
        
        Args:
            command_code: The hex code of the command (e.g., 0x18).
            is_write: True if setting data, False if getting data.
            payload: The data bytes to encode into the packet.
            
        Returns:
            The raw byte response from the device.
        """
        packet = build_packet(command_code, is_write, payload)
        self.send_raw(packet)
        time.sleep(0.2)  # Give device time to process
        
        # Read the immediate ACK or response payload
        return self.receive_raw()

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.disconnect()
