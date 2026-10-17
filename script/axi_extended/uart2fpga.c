#include <windows.h>
#include <conio.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CRC32_POLY 0x04C11DB7u
#define FRAME_LEN 14
#define FRAME_CRC_DATA_LEN 10
#define UART_PORT "COM6"
#define UART_BAUDRATE 115200

static HANDLE g_serial = INVALID_HANDLE_VALUE;

static uint32_t calc_crc32(const uint8_t *data, size_t len)
{
    uint32_t crc = 0xFFFFFFFFu;

    if (len != FRAME_CRC_DATA_LEN) {
        fprintf(stderr, "CRC input must be exactly %d bytes\n", FRAME_CRC_DATA_LEN);
        exit(EXIT_FAILURE);
    }

    for (size_t i = 0; i < len; ++i) {
        uint8_t byte = data[i];
        for (int bit_idx = 7; bit_idx >= 0; --bit_idx) {
            uint32_t data_bit = (byte >> bit_idx) & 1u;
            uint32_t crc_msb = (crc >> 31) & 1u;
            uint32_t bit_in = data_bit ^ crc_msb;
            crc = (crc << 1) & 0xFFFFFFFFu;
            if (bit_in) {
                crc ^= CRC32_POLY;
            }
        }
    }

    return crc;
}

static void frame_to_hex(const uint8_t *frame, size_t len, char *out, size_t out_len)
{
    size_t pos = 0;

    if (out_len == 0) {
        return;
    }

    out[0] = '\0';

    for (size_t i = 0; i < len; ++i) {
        int written = snprintf(out + pos, out_len - pos, "%s%02X", (i == 0) ? "" : " ", frame[i]);
        if (written < 0 || (size_t)written >= out_len - pos) {
            out[out_len - 1] = '\0';
            return;
        }
        pos += (size_t)written;
    }
}

static void build_wr_frame(uint32_t addr, uint32_t data, uint8_t frame[FRAME_LEN])
{
    frame[0] = 0xAA;
    frame[1] = 0x01;
    frame[2] = (uint8_t)((addr >> 0) & 0xFF);
    frame[3] = (uint8_t)((addr >> 8) & 0xFF);
    frame[4] = (uint8_t)((addr >> 16) & 0xFF);
    frame[5] = (uint8_t)((addr >> 24) & 0xFF);
    frame[6] = (uint8_t)((data >> 0) & 0xFF);
    frame[7] = (uint8_t)((data >> 8) & 0xFF);
    frame[8] = (uint8_t)((data >> 16) & 0xFF);
    frame[9] = (uint8_t)((data >> 24) & 0xFF);

    uint32_t crc = calc_crc32(frame, FRAME_CRC_DATA_LEN);
    frame[10] = (uint8_t)((crc >> 0) & 0xFF);
    frame[11] = (uint8_t)((crc >> 8) & 0xFF);
    frame[12] = (uint8_t)((crc >> 16) & 0xFF);
    frame[13] = (uint8_t)((crc >> 24) & 0xFF);
}

static void build_rd_frame(uint32_t addr, uint8_t frame[FRAME_LEN])
{
    frame[0] = 0xAA;
    frame[1] = 0x02;
    frame[2] = (uint8_t)((addr >> 0) & 0xFF);
    frame[3] = (uint8_t)((addr >> 8) & 0xFF);
    frame[4] = (uint8_t)((addr >> 16) & 0xFF);
    frame[5] = (uint8_t)((addr >> 24) & 0xFF);
    frame[6] = 0x00;
    frame[7] = 0x00;
    frame[8] = 0x00;
    frame[9] = 0x00;

    uint32_t crc = calc_crc32(frame, FRAME_CRC_DATA_LEN);
    frame[10] = (uint8_t)((crc >> 0) & 0xFF);
    frame[11] = (uint8_t)((crc >> 8) & 0xFF);
    frame[12] = (uint8_t)((crc >> 16) & 0xFF);
    frame[13] = (uint8_t)((crc >> 24) & 0xFF);
}

static int check_frame_crc(const uint8_t frame[FRAME_LEN])
{
    uint32_t crc_expected = calc_crc32(frame, FRAME_CRC_DATA_LEN);
    uint32_t crc_received =
        (uint32_t)frame[10] |
        ((uint32_t)frame[11] << 8) |
        ((uint32_t)frame[12] << 16) |
        ((uint32_t)frame[13] << 24);

    return crc_expected == crc_received;
}

static int uart_read_exact(uint8_t *buffer, size_t len)
{
    size_t total = 0;

    while (total < len) {
        DWORD got = 0;
        BOOL ok = ReadFile(g_serial, buffer + total, (DWORD)(len - total), &got, NULL);
        if (!ok) {
            return 0;
        }
        if (got == 0) {
            return 0;
        }
        total += (size_t)got;
    }

    return 1;
}

static int uart_receive_frame(uint8_t frame[FRAME_LEN])
{
    if (!uart_read_exact(frame, FRAME_LEN)) {
        printf("ERROR: Timeout waiting for frame\n");
        return 0;
    }

    if (!check_frame_crc(frame)) {
        char rx_hex[FRAME_LEN * 3];
        printf("ERROR: CRC mismatch\n");
        frame_to_hex(frame, FRAME_LEN, rx_hex, sizeof(rx_hex));
        printf("RX: %s\n", rx_hex);
        return 0;
    }

    return 1;
}

static int read_register(uint32_t addr, uint32_t *value_out, int debug)
{
    uint8_t tx_frame[FRAME_LEN];
    uint8_t rx_frame[FRAME_LEN];
    char hex_buf[FRAME_LEN * 3];

    build_rd_frame(addr, tx_frame);

    if (debug) {
        frame_to_hex(tx_frame, FRAME_LEN, hex_buf, sizeof(hex_buf));
        printf("TX: %s\n", hex_buf);
    }

    PurgeComm(g_serial, PURGE_RXCLEAR | PURGE_TXCLEAR);
    if (!WriteFile(g_serial, tx_frame, FRAME_LEN, &(DWORD){0}, NULL)) {
        printf("ERROR: Failed to write read frame\n");
        return 0;
    }
    FlushFileBuffers(g_serial);

    if (!uart_receive_frame(rx_frame)) {
        return 0;
    }

    if (debug) {
        frame_to_hex(rx_frame, FRAME_LEN, hex_buf, sizeof(hex_buf));
        printf("RX: %s\n", hex_buf);
    }

    *value_out =
        (uint32_t)rx_frame[6] |
        ((uint32_t)rx_frame[7] << 8) |
        ((uint32_t)rx_frame[8] << 16) |
        ((uint32_t)rx_frame[9] << 24);

    return 1;
}

static int write_register(uint32_t addr, uint32_t data, int debug)
{
    uint8_t tx_frame[FRAME_LEN];
    uint8_t ack_frame[FRAME_LEN];
    char hex_buf[FRAME_LEN * 3];

    build_wr_frame(addr, data, tx_frame);

    if (debug) {
        frame_to_hex(tx_frame, FRAME_LEN, hex_buf, sizeof(hex_buf));
        printf("WR TX: %s\n", hex_buf);
    }

    PurgeComm(g_serial, PURGE_RXCLEAR | PURGE_TXCLEAR);
    if (!WriteFile(g_serial, tx_frame, FRAME_LEN, &(DWORD){0}, NULL)) {
        printf("WRITE ERROR: Failed to write frame\n");
        return 0;
    }
    FlushFileBuffers(g_serial);

    if (!uart_receive_frame(ack_frame)) {
        printf("WRITE ERROR: No ACK received\n");
        return 0;
    }

    if (debug) {
        frame_to_hex(ack_frame, FRAME_LEN, hex_buf, sizeof(hex_buf));
        printf("ACK RX: %s\n", hex_buf);
    }

    if (ack_frame[0] != 0xAA) {
        printf("WRITE ERROR: Invalid ACK start byte\n");
        return 0;
    }

    if (ack_frame[1] != 0x81) {
        printf("WRITE ERROR: Invalid ACK command: 0x%02X\n", ack_frame[1]);
        return 0;
    }

    uint32_t ack_addr =
        (uint32_t)ack_frame[2] |
        ((uint32_t)ack_frame[3] << 8) |
        ((uint32_t)ack_frame[4] << 16) |
        ((uint32_t)ack_frame[5] << 24);

    if (ack_addr != addr) {
        printf("WRITE ERROR: ACK address mismatch\n");
        printf("Expected: 0x%08X\n", addr);
        printf("Received: 0x%08X\n", ack_addr);
        return 0;
    }

    if (debug) {
        printf("WRITE OK\n");
    }

    return 1;
}

static void display_menu(void)
{
    printf("\n===== Main Menu =====\n");
    printf("1. Read System module registers from 0 to 6\n");
    printf("2. Write read to register 0x1000 value 0x12345678\n");
    printf("3. Continuous write/read test with fixed data\n");
    printf("4. Continuous write/read test with random data\n");
    printf("5. Option 5\n");
    printf("0. Exit\n");
    printf("=====================\n");
}

static void test3(void)
{
    const uint32_t base_addrs[] = {0x1000u, 0x2000u, 0x3000u};
    const uint32_t last_offset = 0xFCu;
    const uint32_t pattern = 0x12345678u;
    uint32_t total_written = 0;

    printf("\nTest 3: continuous write/read with fixed data from 0x1000/0x2000/0x3000 blocks\n");
    printf("Press any key to stop the test.\n");

    for (;;) {
        for (size_t b = 0; b < sizeof(base_addrs) / sizeof(base_addrs[0]); ++b) {
            for (uint32_t offset = 0; offset <= last_offset; offset += 4) {
                uint32_t addr = base_addrs[b] + offset;
                uint32_t rd_value = 0;

                if (_kbhit()) {
                    (void)_getch();
                    printf("\nTest 3 stopped by key press.\n");
                    printf("Total registers written: %u\n", total_written);
                    return;
                }

                if (!write_register(addr, pattern, 0)) {
                    printf("WRITE ERROR at 0x%08X\n", addr);
                    printf("Total registers written: %u\n", total_written);
                    return;
                }

                if (!read_register(addr, &rd_value, 0)) {
                    printf("READ ERROR at 0x%08X\n", addr);
                    printf("Total registers written: %u\n", total_written + 1);
                    return;
                }

                if (rd_value != pattern) {
                    printf("VERIFY ERROR at 0x%08X\n", addr);
                    printf("Expected : 0x%08X\n", pattern);
                    printf("Received : 0x%08X\n", rd_value);
                    printf("Total registers written: %u\n", total_written + 1);
                    return;
                }

                total_written++;
                if ((total_written % 256u) == 0u) {
                    printf("No error after %u registers written.\n", total_written);
                }
            }
        }
    }
}

static uint32_t random_u32(void)
{
    uint32_t a = (uint32_t)(rand() & 0xFFFF);
    uint32_t b = (uint32_t)(rand() & 0xFFFF);
    return (a << 16) | b;
}

static void test4(void)
{
    const uint32_t base_addrs[] = {0x1000u, 0x2000u, 0x3000u};
    const uint32_t last_offset = 0xFCu;
    uint32_t total_written = 0;

    printf("\nTest 4: continuous write/read with random data from 0x1000/0x2000/0x3000 blocks\n");
    printf("Press any key to stop the test.\n");

    for (;;) {
        for (size_t b = 0; b < sizeof(base_addrs) / sizeof(base_addrs[0]); ++b) {
            for (uint32_t offset = 0; offset <= last_offset; offset += 4) {
                uint32_t addr = base_addrs[b] + offset;
                uint32_t data = random_u32();
                uint32_t rd_value = 0;

                if (_kbhit()) {
                    (void)_getch();
                    printf("\nTest 4 stopped by key press.\n");
                    printf("Total registers written: %u\n", total_written);
                    return;
                }

                if (!write_register(addr, data, 0)) {
                    printf("WRITE ERROR at 0x%08X\n", addr);
                    printf("Total registers written: %u\n", total_written);
                    return;
                }

                if (!read_register(addr, &rd_value, 0)) {
                    printf("READ ERROR at 0x%08X\n", addr);
                    printf("Total registers written: %u\n", total_written + 1);
                    return;
                }

                if (rd_value != data) {
                    printf("VERIFY ERROR at 0x%08X\n", addr);
                    printf("Expected : 0x%08X\n", data);
                    printf("Received : 0x%08X\n", rd_value);
                    printf("Total registers written: %u\n", total_written + 1);
                    return;
                }

                total_written++;
                if ((total_written % 256u) == 0u) {
                    printf("No error after %u registers written.\n", total_written);
                }
            }
        }
    }
}

static void close_serial(void)
{
    if (g_serial != INVALID_HANDLE_VALUE) {
        CloseHandle(g_serial);
        g_serial = INVALID_HANDLE_VALUE;
    }
}

static int open_serial(void)
{
    char port_path[32];
    DCB dcb;
    COMMTIMEOUTS timeouts;

    snprintf(port_path, sizeof(port_path), "\\\\.\\%s", UART_PORT);

    g_serial = CreateFileA(
        port_path,
        GENERIC_READ | GENERIC_WRITE,
        0,
        NULL,
        OPEN_EXISTING,
        0,
        NULL
    );

    if (g_serial == INVALID_HANDLE_VALUE) {
        printf("ERROR: Unable to open %s\n", UART_PORT);
        return 0;
    }

    memset(&dcb, 0, sizeof(dcb));
    dcb.DCBlength = sizeof(dcb);

    if (!GetCommState(g_serial, &dcb)) {
        printf("ERROR: GetCommState failed\n");
        close_serial();
        return 0;
    }

    dcb.BaudRate = UART_BAUDRATE;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fBinary = TRUE;
    dcb.fParity = FALSE;

    if (!SetCommState(g_serial, &dcb)) {
        printf("ERROR: SetCommState failed\n");
        close_serial();
        return 0;
    }

    if (!SetupComm(g_serial, 4096, 4096)) {
        printf("ERROR: SetupComm failed\n");
        close_serial();
        return 0;
    }

    memset(&timeouts, 0, sizeof(timeouts));
    timeouts.ReadIntervalTimeout = 50;
    timeouts.ReadTotalTimeoutConstant = 2000;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 2000;
    timeouts.WriteTotalTimeoutMultiplier = 0;

    if (!SetCommTimeouts(g_serial, &timeouts)) {
        printf("ERROR: SetCommTimeouts failed\n");
        close_serial();
        return 0;
    }

    return 1;
}

int main(void)
{
    srand((unsigned)time(NULL));

    if (!open_serial()) {
        return EXIT_FAILURE;
    }

    for (;;) {
        display_menu();

        char choice_buf[32];
        printf("Enter your choice: ");
        if (fgets(choice_buf, sizeof(choice_buf), stdin) == NULL) {
            break;
        }

        int choice = atoi(choice_buf);

        if (choice == 1) {
            printf("\nSystem Registers\n");
            printf("----------------------------------------\n");
            printf(" Address     Value\n");
            printf("----------------------------------------\n");

            for (uint32_t addr = 0; addr < 29; addr += 4) {
                uint32_t value = 0;
                if (!read_register(addr, &value, 1)) {
                    printf(" 0x%08X  READ ERROR\n", addr);
                } else {
                    printf(" 0x%08X  0x%08X\n", addr, value);
                }
            }

            printf("----------------------------------------\n");
        } else if (choice == 2) {
            uint32_t addr = 0x1000u;
            uint32_t wr_value = 0x12345678u;
            uint32_t rd_value = 0;

            printf("\nWriting 0x%08X to register 0x%08X\n", wr_value, addr);

            if (!write_register(addr, wr_value, 0)) {
                printf("Write failed, but continuing with read...\n");
            }

            printf("\nReading register 0x%08X\n", addr);

            if (!read_register(addr, &rd_value, 0)) {
                printf("Read failed\n");
            } else {
                printf("Read back: 0x%08X\n", rd_value);

                if (rd_value == wr_value) {
                    printf("PASS\n");
                } else {
                    printf("FAIL\n");
                    printf("Expected : 0x%08X\n", wr_value);
                    printf("Received : 0x%08X\n", rd_value);
                }
            }
        } else if (choice == 3) {
            test3();
        } else if (choice == 4) {
            test4();
        } else if (choice == 5) {
            printf("You selected Option 5\n");
        } else if (choice == 0) {
            printf("Exiting program...\n");
            break;
        } else {
            printf("Invalid choice. Please enter a number between 0 and 5.\n");
        }
    }

    close_serial();
    return EXIT_SUCCESS;
}
