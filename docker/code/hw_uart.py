import serial
import serial.tools.list_ports

BAUD_RATE = 115200
TIMEOUT   = 1  # seconds


def list_ports():
    ports = serial.tools.list_ports.comports()
    if not ports:
        print("No serial ports found.")
    for p in ports:
        print(f"  {p.device}  —  {p.description}")
    return [p.device for p in ports]


def read_uart(port: str, baud: int = BAUD_RATE, timeout: float = TIMEOUT):
    with serial.Serial(port, baud, timeout=timeout) as ser:
        print(f"Opened {port} at {baud} baud. Press Ctrl+C to stop.\n")
        while True:
            line = ser.readline()
            if line:
                try:
                    print(line.decode("utf-8").rstrip())
                except UnicodeDecodeError:
                    print(line.hex())


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Read UART data over USB serial.")
    parser.add_argument("--port",  "-p", type=str, help="Serial port (e.g. /dev/ttyUSB0)")
    parser.add_argument("--baud",  "-b", type=int, default=BAUD_RATE, help=f"Baud rate (default: {BAUD_RATE})")
    parser.add_argument("--list",  "-l", action="store_true", help="List available serial ports and exit")
    args = parser.parse_args()

    if args.list or not args.port:
        print("Available ports:")
        ports = list_ports()
        if not args.port and ports:
            args.port = ports[0]
            print(f"\nUsing first available port: {args.port}")
        elif not args.port:
            raise SystemExit("No port specified and none found.")

    read_uart(args.port, args.baud)
