#!/usr/bin/env python3
"""
boot_host.py

Python host that mimics tb_boot.v: drives the RISC-V SoC bootloader
over a real UART port.

Boot protocol (matches boot_loader.v):
  1. Open serial port, wait to receive HANDSHAKE_BYTE (0xAA) from SoC.
  2. Send ACK_BYTE (0x55) back.
  3. Stream all words from <hex_file> MSB-first (4 bytes / word).
     After each word, wait for 'X' (0x58) acknowledgement from SoC.
  4. Bootloader times out internally and releases the CPU.
  5. Print any subsequent bytes that arrive (CPU UART output).

UART settings (match boot_loader.v defaults at 50 MHz):
  BRR = 27  →  baud = 50_000_000 / (27 × 16) ≈ 115 740 baud
  Frame: 8N1  (no parity, 1 stop bit)

Usage:
  python boot_host.py [OPTIONS] <hex_file>

Options:
  -p, --port   <port>   Serial device  (default: /dev/ttyUSB0)
  -b, --baud   <baud>   Baud rate      (default: 115200)
  -n, --words  <n>      Number of 32-bit words to send (default: auto)
  -t, --timeout <s>     Per-byte receive timeout in seconds (default: 5.0)
  -v, --verbose         Print every word as it is sent
"""

import argparse
import sys
import time
from typing import List, Optional
import serial


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_hex_words(path: str) -> List[int]:
    """
    Read a Verilog $readmemh hex file and return a list of 32-bit integers.
    Lines may be bare hex words or contain Verilog address tags (@ADDR).
    Empty lines and comment lines (//) are ignored.
    """
    words: list[int] = []
    with open(path, "r") as fh:
        for raw in fh:
            line = raw.split("//")[0].strip()   # strip inline comments
            if not line:
                continue
            if line.startswith("@"):
                continue                        # address tag – skip
            # A single line may contain multiple space-separated words
            for tok in line.split():
                words.append(int(tok, 16))
    return words


def recv_byte(port: serial.Serial, timeout: float, label: str = "") -> int:
    """
    Block until one byte arrives; raise on timeout.
    """
    port.timeout = timeout
    data = port.read(1)
    if not data:
        raise TimeoutError(f"Timed out waiting for byte ({label})")
    return data[0]


# ---------------------------------------------------------------------------
# Main boot sequence
def run_boot(port_name: str, baud: int, hex_file: str,
             num_words: Optional[int], timeout: float, verbose: bool) -> None:

    words = load_hex_words(hex_file)
    if num_words is not None:
        words = words[:num_words]
    total = len(words)
    print(f"[BOOT] Loaded {total} words from {hex_file}")

    with serial.Serial(port_name, baudrate=baud, bytesize=8,
                       parity=serial.PARITY_NONE, stopbits=1,
                       xonxoff=False, rtscts=False, dsrdtr=False) as ser:

        ser.reset_input_buffer()
        ser.reset_output_buffer()
        print(f"[BOOT] Opened {port_name} @ {baud} baud")

        # -------------------------------------------------------------------
        # Step 1 – receive HANDSHAKE_BYTE (0xAA)
        print("[BOOT] Waiting for handshake byte 0xAA from SoC ...")
        b = recv_byte(ser, timeout, "handshake")
        if b == 0xAA:
            print(f"[BOOT] Received handshake 0x{b:02X}  OK")
        else:
            print(f"[BOOT] ERROR: expected 0xAA, received 0x{b:02X}")
            sys.exit(1)

        # -------------------------------------------------------------------
        # Step 2 – send ACK_BYTE (0x55)
        print("[BOOT] Sending acknowledgement 0x55 to SoC ...")
        ser.write(bytes([0x55]))
        ser.flush()
        print("[BOOT] Ack sent.")

        # -------------------------------------------------------------------
        # Step 2b – send 4-byte word count (big-endian) so the bootloader
        #           knows exactly how many words to expect before starting the CPU
        wc_bytes = total.to_bytes(4, byteorder='big')
        ser.write(wc_bytes)
        ser.flush()
        print(f"[BOOT] Sent word count: {total} (0x{total:08X})")

        # -------------------------------------------------------------------
        # Step 3 – stream words, 4 bytes each (MSB first)
        #          Wait for 'X' (0x58) after each word
        print(f"[BOOT] Streaming {total} words ...")
        t0 = time.monotonic()

        for i, word in enumerate(words):
            payload = bytes([
                (word >> 24) & 0xFF,
                (word >> 16) & 0xFF,
                (word >>  8) & 0xFF,
                (word >>  0) & 0xFF,
            ])
            ser.write(payload)
            ser.flush()

            if verbose:
                print(f"  [{i:4d}/{total}]  0x{word:08X}  sent", end="", flush=True)

            # Wait for per-word 'X' ack
            ack = recv_byte(ser, timeout, f"word-ack[{i}]")
            if verbose and ack != 0x58:
                print(f"\n[BOOT] WARN: expected 'X' (0x58), got 0x{ack:02X} at word {i}")
            elif verbose:
                print(f"  ack=0x{ack:02X}  OK")
            else:
                # Print a simple progress dot every 16 words
                if (i + 1) % 16 == 0 or (i + 1) == total:
                    pct = (i + 1) * 100 // total
                    print(f"\r[BOOT] Progress: {i+1}/{total}  ({pct}%)    ", end="", flush=True)

        elapsed = time.monotonic() - t0
        print(f"\n[BOOT] All {total} words sent and acknowledged  ({elapsed:.2f}s)")

        # -------------------------------------------------------------------
        # Step 4 – bootloader idle-timeout fires internally;
        #          just wait for and print any CPU output
        print("[BOOT] Waiting for CPU output (Ctrl-C to quit) ...")
        ser.timeout = timeout
        try:
            buf = bytearray()
            while True:
                # Read whatever is already in the buffer; if empty, block for
                # up to `timeout` seconds waiting for the first byte.
                # This prevents early bytes from being held up until 64 arrive.
                waiting = ser.in_waiting
                chunk = ser.read(waiting if waiting > 0 else 1)
                if not chunk:
                    # No data for `timeout` seconds → assume CPU is done
                    if buf:
                        print()
                    print("[BOOT] No more data.  Done.")
                    break
                buf.extend(chunk)
                # Print printable ASCII; hex-dump non-printable bytes
                for byte in chunk:
                    if 0x20 <= byte < 0x7F or byte in (0x0A, 0x0D):
                        sys.stdout.write(chr(byte))
                    else:
                        sys.stdout.write(f"<0x{byte:02X}>")
                sys.stdout.flush()
        except KeyboardInterrupt:
            print("\n[BOOT] Interrupted by user.")


# ---------------------------------------------------------------------------
# CLI
def main() -> None:
    parser = argparse.ArgumentParser(
        description="RISC-V SoC UART bootloader host (mirrors tb_boot.v)"
    )
    parser.add_argument("hex_file",
                        help="Path to .hex image (Verilog $readmemh format)")
    parser.add_argument("-p", "--port",    default="/dev/ttyUSB0",
                        help="Serial device (default: /dev/ttyUSB0)")
    parser.add_argument("-b", "--baud",    type=int, default=115200,
                        help="Baud rate (default: 115200)")
    parser.add_argument("-n", "--words",   type=int, default=None,
                        help="Number of 32-bit words to send (default: all)")
    parser.add_argument("-t", "--timeout", type=float, default=5.0,
                        help="Per-byte receive timeout in seconds (default: 5.0)")
    parser.add_argument("-v", "--verbose", action="store_true",
                        help="Print every word as it is sent/acked")
    args = parser.parse_args()

    run_boot(
        port_name=args.port,
        baud=args.baud,
        hex_file=args.hex_file,
        num_words=args.words,
        timeout=args.timeout,
        verbose=args.verbose,
    )

if __name__ == "__main__":
    main()
