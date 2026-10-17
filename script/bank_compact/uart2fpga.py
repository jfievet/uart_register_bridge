
import serial
import msvcrt
import random

# ---------------------------------------------------------
# UART Configuration
# ---------------------------------------------------------

COM_PORT = "COM7"
BAUDRATE = 500000
TIMEOUT = 2

FRAME_START = 0xAA
FRAME_SIZE = 6

CMD_WRITE = 0
CMD_READ = 1

# ---------------------------------------------------------
# Register Bank Map
# ---------------------------------------------------------

REG_COUNT = 128
FIRST_RW_REG = 2
LAST_RW_REG = REG_COUNT - 1
MAX_REG_ADDR = REG_COUNT - 1


# ---------------------------------------------------------
# Frame Utilities
# ---------------------------------------------------------

def frame_to_hex(frame: bytes) -> str:
    return " ".join(f"{b:02X}" for b in frame)


def build_frame(addr: int, data: int, is_read: bool) -> bytes:
    """
    Compact UART frame (6 bytes):

    Byte 0 : 0xAA
    Byte 1 : R/W + ADDR[6:0]
    Byte 2 : DATA[7:0]
    Byte 3 : DATA[15:8]
    Byte 4 : DATA[23:16]
    Byte 5 : DATA[31:24]

    Register address is encoded directly in ADDR[6:0].
    """

    if addr < 0 or addr > MAX_REG_ADDR:
        raise ValueError(f"Register index {addr} outside 0..{MAX_REG_ADDR}")

    if data < 0 or data > 0xFFFFFFFF:
        raise ValueError("Data must be a 32-bit unsigned value")

    frame_addr = addr

    command = (
        (CMD_READ if is_read else CMD_WRITE) << 7
    ) | frame_addr

    return bytes([
        FRAME_START,
        command,
        (data >> 0) & 0xFF,
        (data >> 8) & 0xFF,
        (data >> 16) & 0xFF,
        (data >> 24) & 0xFF,
    ])


def build_wr_frame(addr: int, data: int) -> bytes:
    return build_frame(addr, data, False)


def build_rd_frame(addr: int) -> bytes:
    return build_frame(addr, 0, True)


def decode_frame(frame: bytes):
    """
    Returns:
        (is_read, register_index, data)
    """

    if len(frame) != FRAME_SIZE:
        raise ValueError("Invalid frame size")

    if frame[0] != FRAME_START:
        raise ValueError("Invalid START byte")

    is_read = bool(frame[1] & 0x80)

    frame_addr = frame[1] & 0x7F
    reg_addr = frame_addr

    data = int.from_bytes(frame[2:6], "little")

    return is_read, reg_addr, data


# ---------------------------------------------------------
# UART Communication
# ---------------------------------------------------------

def uart_receive_frame(expected_addr, expected_read):
    """
    Receive and validate one 6-byte response.

    Checks:
      - Frame length
      - START byte
      - R/W bit
      - Address

    Returns:
        32-bit data or None on error.
    """

    frame = ser.read(FRAME_SIZE)

    if len(frame) != FRAME_SIZE:
        print(
            f"RX ERROR: Timeout "
            f"({len(frame)}/{FRAME_SIZE} bytes)"
        )
        if frame:
            print("Partial RX:", frame_to_hex(frame))
        return None

    try:
        is_read, addr, data = decode_frame(frame)

    except ValueError as e:
        print(f"RX ERROR: {e}")
        print("RX:", frame_to_hex(frame))
        return None

    if is_read != expected_read:
        print("RX ERROR: R/W mismatch")
        print("RX:", frame_to_hex(frame))
        return None

    if addr != expected_addr:
        print("RX ERROR: Address mismatch")
        print(f"Expected: 0x{expected_addr:08X}")
        print(f"Received: 0x{addr:08X}")
        print("RX:", frame_to_hex(frame))
        return None

    return data


def read_register(addr, debug=False):
    """
    Read a 32-bit bank register.

    Returns:
        Register value or None on error.
    """

    tx_frame = build_rd_frame(addr)

    if debug:
        print("RD TX:", frame_to_hex(tx_frame))

    ser.reset_input_buffer()
    ser.write(tx_frame)
    ser.flush()

    value = uart_receive_frame(
        expected_addr=addr,
        expected_read=True
    )

    if debug:
        if value is not None:
            print(f"RD VALUE: 0x{value:08X}")

    return value


def write_register(addr, data, debug=False):
    """
    Write a 32-bit bank register.

    Wait for a valid write response.

    Returns:
        True on valid response.
        False on error.
    """

    tx_frame = build_wr_frame(addr, data)

    if debug:
        print("WR TX:", frame_to_hex(tx_frame))

    ser.reset_input_buffer()
    ser.write(tx_frame)
    ser.flush()

    ack_data = uart_receive_frame(
        expected_addr=addr,
        expected_read=False
    )

    if ack_data is None:
        print(f"WRITE ERROR at 0x{addr:08X}")
        return False

    if debug:
        print(f"WR RESPONSE DATA: 0x{ack_data:08X}")
        print("WRITE RESPONSE OK")

    return True


# ---------------------------------------------------------
# Continuous Tests
# ---------------------------------------------------------

def run_continuous_test(test_name, data_provider):
    print(f"\n{test_name}")
    print("Registers 2..127; press any key to stop between transactions.")
    total_verified = 0

    while True:
        # First write the entire writable/readback region.
        expected = {}
        for addr in range(FIRST_RW_REG, LAST_RW_REG + 1):
            if msvcrt.kbhit():
                msvcrt.getch()
                print(f"\nStopped. Total verified: {total_verified}")
                return
            data = data_provider(addr)
            if not write_register(addr, data):
                print(f"WRITE ERROR at register {addr}")
                return
            expected[addr] = data

        # Then read and verify the entire region.
        for addr in range(FIRST_RW_REG, LAST_RW_REG + 1):
            if msvcrt.kbhit():
                msvcrt.getch()
                print(f"\nStopped. Total verified: {total_verified}")
                return
            value = read_register(addr)
            if value is None:
                print(f"READ ERROR at register {addr}")
                return
            if value != expected[addr]:
                print(f"VERIFY ERROR at register {addr}")
                print(f"Expected: 0x{expected[addr]:08X}")
                print(f"Received: 0x{value:08X}")
                print(f"Registers verified: {total_verified}")
                return
            total_verified += 1

        print(f"No error after {total_verified} registers verified.")


def test3():
    run_continuous_test(
        "Test 3: Continuous fixed data test",
        lambda addr: 0x12345678
    )


def test4():
    run_continuous_test(
        "Test 4: Continuous random data test",
        lambda addr: random.getrandbits(32)
    )


# ---------------------------------------------------------
# Menu
# ---------------------------------------------------------

def display_menu():

    print("\n========== Main Menu ==========")
    print("1. Read registers 0 and 1")
    print("2. Write/read register 2")
    print("3. Continuous fixed data test")
    print("4. Continuous random data test")
    print("5. Display register map")
    print("0. Exit")
    print("================================")


def display_memory_map():
    print("\nCompact UART Register Bank Map")
    print("-----------------------------------------------")
    print("Register 0..1   : read-only values")
    print("Register 2..127 : write/readback")
    print("Frame address   : register index (no x4 scaling)")
    print("-----------------------------------------------")


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------

def main():

    global ser

    ser = serial.Serial(
        COM_PORT,
        baudrate=BAUDRATE,
        timeout=TIMEOUT
    )

    try:

        while True:

            display_menu()

            choice = input("Enter your choice: ").strip()

            # ---------------------------------------------
            # Option 1: System Registers
            # ---------------------------------------------

            if choice == "1":

                print("\nRegisters 0 and 1")
                print("----------------------------------")
                print(" Register      Value")
                print("----------------------------------")

                for addr in (0, 1):

                    value = read_register(
                        addr, debug=True
                    )

                    if value is None:
                        print(
                            f"0x{addr:08X}    READ ERROR"
                        )
                    else:
                        print(f"0x{addr:08X}    0x{value:08X}")


                print("----------------------------------")

            # ---------------------------------------------
            # Option 2: Write / Read
            # ---------------------------------------------

            elif choice == "2":

                addr = 2
                wr_value = 0x12345678

                print(
                    f"\nWriting 0x{wr_value:08X} "
                    f"to 0x{addr:08X}"
                )

                write_ok = write_register(
                    addr, wr_value, debug=True
                )

                if not write_ok:
                    print(
                        "Write response failed, "
                        "continuing with read..."
                    )

                rd_value = read_register(
                    addr, debug=True
                )

                if rd_value is None:
                    print("Read failed")

                else:

                    print(
                        f"Read back: 0x{rd_value:08X}"
                    )

                    if rd_value == wr_value:
                        print("PASS")
                    else:
                        print("FAIL")
                        print(
                            f"Expected: 0x{wr_value:08X}"
                        )
                        print(
                            f"Received: 0x{rd_value:08X}"
                        )

            elif choice == "3":
                test3()

            elif choice == "4":
                test4()

            elif choice == "5":
                display_memory_map()

            elif choice == "0":
                print("Exiting program...")
                break

            else:
                print("Invalid choice.")

    finally:
        ser.close()


if __name__ == "__main__":
    main()
