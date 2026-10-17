import serial
import time
import msvcrt
import random

CRC32_POLY = 0x04C11DB7


def calc_crc32(data: bytes) -> int:
    """
    VHDL-compatible CRC32.

    data: exactly 10 bytes

    Returns:
        CRC32 as integer
    """

    if len(data) != 10:
        raise ValueError("CRC input must be exactly 10 bytes")

    crc = 0xFFFFFFFF

    for byte in data:

        for bit_idx in range(7, -1, -1):

            data_bit = (byte >> bit_idx) & 1
            crc_msb = (crc >> 31) & 1

            bit_in = data_bit ^ crc_msb

            crc = ((crc << 1) & 0xFFFFFFFF)

            if bit_in:
                crc ^= CRC32_POLY

    return crc


def build_wr_frame(addr: int, data: int) -> bytes:
    """
    Build WRITE frame.

    Frame format:
        AA 01
        ADDR[0] ADDR[1] ADDR[2] ADDR[3]
        DATA[0] DATA[1] DATA[2] DATA[3]
        CRC[0] CRC[1] CRC[2] CRC[3]

    LSB first for address/data/crc fields.
    """

    crc_data = bytes([
        0xAA,
        0x01,

        (addr >> 0) & 0xFF,
        (addr >> 8) & 0xFF,
        (addr >> 16) & 0xFF,
        (addr >> 24) & 0xFF,

        (data >> 0) & 0xFF,
        (data >> 8) & 0xFF,
        (data >> 16) & 0xFF,
        (data >> 24) & 0xFF,
    ])

    crc = calc_crc32(crc_data)

    frame = crc_data + bytes([
        (crc >> 0) & 0xFF,
        (crc >> 8) & 0xFF,
        (crc >> 16) & 0xFF,
        (crc >> 24) & 0xFF,
    ])

    return frame


def build_rd_frame(addr: int) -> bytes:
    """
    Build READ frame.

    DATA field is 0x00000000.
    """

    crc_data = bytes([
        0xAA,
        0x02,

        (addr >> 0) & 0xFF,
        (addr >> 8) & 0xFF,
        (addr >> 16) & 0xFF,
        (addr >> 24) & 0xFF,

        0x00,
        0x00,
        0x00,
        0x00,
    ])

    crc = calc_crc32(crc_data)

    frame = crc_data + bytes([
        (crc >> 0) & 0xFF,
        (crc >> 8) & 0xFF,
        (crc >> 16) & 0xFF,
        (crc >> 24) & 0xFF,
    ])

    return frame


def check_frame_crc(frame: bytes) -> bool:
    """
    Verify CRC of a 14-byte frame.
    """

    if len(frame) != 14:
        return False

    crc_data = frame[:10]

    crc_expected = calc_crc32(crc_data)

    crc_received = (
        frame[10]
        | (frame[11] << 8)
        | (frame[12] << 16)
        | (frame[13] << 24)
    )

    return crc_expected == crc_received


def frame_to_hex(frame: bytes) -> str:
    return " ".join(f"{b:02X}" for b in frame)

def uart_receive_frame():
    """
    Receive one 14-byte frame.
    Returns frame bytes or None on timeout/error.
    """

    frame = ser.read(14)

    if len(frame) != 14:
        print("ERROR: Timeout waiting for frame")
        return None

    if not check_frame_crc(frame):
        print("ERROR: CRC mismatch")
        print("RX:", frame_to_hex(frame))
        return None

    return frame

def read_register(addr, debug=False):
    """
    Read a 32-bit register.

    Returns:
        integer register value

    Returns None on error.
    """

    tx_frame = build_rd_frame(addr)

    if debug:
        print("TX:", frame_to_hex(tx_frame))

    ser.reset_input_buffer()
    ser.write(tx_frame)
    ser.flush()

    rx_frame = uart_receive_frame()

    if rx_frame is None:
        return None

    if debug:
        print("RX:", frame_to_hex(rx_frame))

    value = (
        rx_frame[6]
        | (rx_frame[7] << 8)
        | (rx_frame[8] << 16)
        | (rx_frame[9] << 24)
    )

    return value

def write_register(addr, data, debug=False):
    """
    Write a 32-bit register and wait for ACK frame.

    Returns True if:
      - ACK frame is received
      - ACK CRC is valid
      - ACK address matches requested address
    """

    tx_frame = build_wr_frame(addr, data)

    if debug:
        print("WR TX:", frame_to_hex(tx_frame))

    ser.reset_input_buffer()
    ser.write(tx_frame)
    ser.flush()

    ack_frame = uart_receive_frame()

    if ack_frame is None:
        print("WRITE ERROR: No ACK received")
        return False

    if debug:
        print("ACK RX:", frame_to_hex(ack_frame))

    # Optional protocol checks
    if ack_frame[0] != 0xAA:
        print("WRITE ERROR: Invalid ACK start byte")
        return False

    # Change this if your FPGA uses another ACK command code
    if ack_frame[1] != 0x81:
        print(f"WRITE ERROR: Invalid ACK command: 0x{ack_frame[1]:02X}")
        return False

    ack_addr = (
        ack_frame[2]
        | (ack_frame[3] << 8)
        | (ack_frame[4] << 16)
        | (ack_frame[5] << 24)
    )

    if ack_addr != addr:
        print(f"WRITE ERROR: ACK address mismatch")
        print(f"Expected: 0x{addr:08X}")
        print(f"Received: 0x{ack_addr:08X}")
        return False

    if debug:
        print("WRITE OK")
    return True

def run_continuous_test(test_name, data_provider):
    print(f"\n{test_name}")
    print("Press any key to stop the test.")

    total_written = 0
    base_addrs = [0x1000, 0x2000, 0x3000]
    last_offset = 0x7C

    while True:
        for base_addr in base_addrs:
            for offset in range(0, last_offset + 1, 4):
                addr = base_addr + offset
                data = data_provider(addr)

                if msvcrt.kbhit():
                    msvcrt.getch()
                    print(f"\n{test_name} stopped by key press.")
                    print(f"Total registers written: {total_written}")
                    return

                write_ok = write_register(addr, data, debug=False)
                if not write_ok:
                    print(f"WRITE ERROR at 0x{addr:08X}")
                    print(f"Total registers written: {total_written}")
                    return

                rd_value = read_register(addr, debug=False)
                if rd_value is None:
                    print(f"READ ERROR at 0x{addr:08X}")
                    print(f"Total registers written: {total_written + 1}")
                    return

                if rd_value != data:
                    print(f"VERIFY ERROR at 0x{addr:08X}")
                    print(f"Expected : 0x{data:08X}")
                    print(f"Received : 0x{rd_value:08X}")
                    print(f"Total registers written: {total_written + 1}")
                    return

                total_written += 1

                if total_written % 128 == 0:
                    print(f"No error after {total_written} registers written.")


def test3():
    run_continuous_test(
        "Test 3: continuous write/read with fixed data from 0x1000/0x2000/0x3000 blocks",
        lambda addr: 0x12345678,
    )


def test4():
    run_continuous_test(
        "Test 4: continuous write/read with random data from 0x1000/0x2000/0x3000 blocks",
        lambda addr: random.getrandbits(32),
    )

def display_menu():
    print("\n===== Main Menu =====")
    print("1. Read System module registers from 0 to 6")
    print("2. Write read to register 0x1000 value 0x12345678")
    print("3. Continuous write/read test with fixed data (slot 1, 2 and 3)")
    print("4. Continuous write/read test with random data (slot 1, 2 and 3)")
    print("5. Option 5")
    print("0. Exit")
    print("=====================")

def main():

    # Define globals
    global ser


    #Start
    ser = serial.Serial('COM7', baudrate=500000, timeout=2)

    while True:
        display_menu()

        choice = input("Enter your choice: ").strip()

        if choice == "1":
            print("\nSystem Registers")
            print("----------------------------------------")
            print(" Address     Value")
            print("----------------------------------------")
            for addr in range(0, 29, 4):
                value = read_register(addr, debug=True)
                if value is None:
                    print(f" 0x{addr:08X}  READ ERROR")
                else:
                    print(f" 0x{addr:08X}  0x{value:08X}")
            print("----------------------------------------")

        elif choice == "2":

            addr = 0x1000
            wr_value = 0x12345678

            print(f"\nWriting 0x{wr_value:08X} to register 0x{addr:08X}")

            write_ok = write_register(addr, wr_value, debug=False)

            if not write_ok:
                print("Write failed, but continuing with read...")

            print(f"\nReading register 0x{addr:08X}")

            rd_value = read_register(addr, debug=False)

            if rd_value is None:
                print("Read failed")
            else:
                print(f"Read back: 0x{rd_value:08X}")

                if rd_value == wr_value:
                    print("PASS")
                else:
                    print("FAIL")
                    print(f"Expected : 0x{wr_value:08X}")
                    print(f"Received : 0x{rd_value:08X}")

        elif choice == "3":
            test3()
        elif choice == "4":
            test4()
        elif choice == "5":
            print("You selected Option 5")
        elif choice == "0":
            print("Exiting program...")
            break
        else:
            print("Invalid choice. Please enter a number between 0 and 5.")

    #Close
    ser.close()

if __name__ == "__main__":
    main()
