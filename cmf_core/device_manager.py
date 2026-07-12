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
        # Drain any stale packets left in the OS buffer from previous aborted connections
        if self._socket:
            self._socket.settimeout(0.0)
            try:
                while True:
                    self._socket.recv(1024)
            except (BlockingIOError, socket.error):
                pass
            finally:
                self._socket.settimeout(2.0)

        packet = build_packet(command_code, is_write, payload)
        self.send_raw(packet)
        time.sleep(0.2)  # Give device time to process
        # Read all available packets for 0.5s
        self._socket.settimeout(0.5)
        raw_data = b""
        try:
            while True:
                chunk = self._socket.recv(1024)
                if not chunk:
                    break
                raw_data += chunk
                
                # Fast exit: if we received a complete data packet (larger than an ACK),
                # we don't need to wait for the 0.5s timeout.
                if len(raw_data) > 9:
                    has_payload = False
                    temp_idx = 0
                    while temp_idx < len(raw_data):
                        if raw_data[temp_idx] == 0x55 and temp_idx + 5 < len(raw_data):
                            plen = raw_data[temp_idx + 5]
                            # ACKs typically have payload length 0 or 1. Data packets are larger.
                            if plen > 1 and temp_idx + 8 + plen <= len(raw_data):
                                has_payload = True
                                break
                        temp_idx += 1
                    
                    if has_payload:
                        break
        except socket.timeout:
            pass
        finally:
            self._socket.settimeout(None)
            
        if len(raw_data) > 0:
            packets = []
            idx = 0
            while idx < len(raw_data):
                if raw_data[idx] == 0x55:
                    if idx + 5 < len(raw_data):
                        length = raw_data[idx + 5]
                        total_len = 8 + length + 2 # Header(8) + Payload + CRC(2)
                        # Some packets might not have CRC? 
                        # Swift code says: "withCRC ? 2 : 0".
                        # To be safe, we extract the slice based on payload length
                        # and let the parser handle the trailing bytes.
                        if idx + 8 + length <= len(raw_data):
                            # The parse_xxx_response functions blindly do data[8:]
                            # So we MUST pass a byte string that starts exactly with this packet.
                            # We'll just slice the packet up to its payload length.
                            # The Python parsers don't check CRC anyway.
                            end_idx = idx + 8 + length
                            packets.append(raw_data[idx:end_idx])
                            
                            # Advance index by full packet length if CRC is present
                            # To be safe, we'll advance by 1 to find the next 0x55, 
                            # or advance by total_len.
                            idx = end_idx
                            continue
                idx += 1
                
            if packets:
                # Filter packets to ensure they actually match the command we requested.
                # Offset 3 is the command_code.
                # For ANC (0x1E), the device might send the true state in a push event (0x03).
                if command_code == 0x1E:
                    valid_packets = [p for p in packets if len(p) > 3 and p[3] in (0x1E, 0x03)]
                    # Prioritize 0x03 over 0x1E if both exist, as 0x03 contains the real state for CMF Buds
                    push_packets = [p for p in valid_packets if p[3] == 0x03]
                    if push_packets:
                        push_packets.sort(key=len)
                        return push_packets[-1]
                else:
                    valid_packets = [p for p in packets if len(p) > 3 and p[3] == command_code]
                
                if valid_packets:
                    # Return the largest valid packet (the data, not the ACK)
                    valid_packets.sort(key=len)
                    return valid_packets[-1]
                
                # If no valid packet matched, return nothing to avoid parsing a random broadcast packet.
                return b""
                
        return raw_data

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.disconnect()
