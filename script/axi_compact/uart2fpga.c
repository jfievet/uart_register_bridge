#include <windows.h>
#include <conio.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define UART_PORT "COM7"
#define UART_BAUDRATE 500000
#define FRAME_LEN 6
#define FRAME_START 0xAAu
#define MAX_AXI_ADDR 0x1FCu
#define SLOT_SIZE 0x80u
#define REG_PER_SLOT 32u

static HANDLE g_serial = INVALID_HANDLE_VALUE;

static void frame_to_hex(const uint8_t *frame, size_t len, char *out, size_t out_len)
{
    size_t pos = 0;
    if (!out_len) return;
    out[0] = '\0';
    for (size_t i = 0; i < len; ++i) {
        int n = snprintf(out + pos, out_len - pos, "%s%02X", i ? " " : "", frame[i]);
        if (n < 0 || (size_t)n >= out_len - pos) { out[out_len - 1] = '\0'; return; }
        pos += (size_t)n;
    }
}

static int build_frame(uint32_t addr, uint32_t data, int is_read, uint8_t frame[FRAME_LEN])
{
    if (addr > MAX_AXI_ADDR || (addr & 3u)) {
        printf("ERROR: Invalid compact AXI address 0x%08lX\n", (unsigned long)addr);
        return 0;
    }
    frame[0] = FRAME_START;
    frame[1] = (uint8_t)((is_read ? 0x80u : 0u) | (addr >> 2));
    for (int i = 0; i < 4; ++i) frame[i + 2] = (uint8_t)(data >> (8 * i));
    return 1;
}

static int uart_write_exact(const uint8_t *buf, DWORD len)
{
    DWORD total = 0;
    while (total < len) {
        DWORD written = 0;
        if (!WriteFile(g_serial, buf + total, len - total, &written, NULL) || !written)
            return 0;
        total += written;
    }
    return FlushFileBuffers(g_serial) != 0;
}

static int uart_read_exact(uint8_t *buf, DWORD len)
{
    DWORD total = 0;
    while (total < len) {
        DWORD got = 0;
        if (!ReadFile(g_serial, buf + total, len - total, &got, NULL) || !got) {
            printf("RX ERROR: Timeout or read failure (%lu/%lu bytes)\n",
                   (unsigned long)total, (unsigned long)len);
            return 0;
        }
        total += got;
    }
    return 1;
}

static int uart_receive_frame(uint32_t expected_addr, int expected_read,
                              uint32_t *data_out, int debug)
{
    uint8_t frame[FRAME_LEN];
    char hex[FRAME_LEN * 3 + 1];
    if (!uart_read_exact(frame, FRAME_LEN)) return 0;
    if (debug) {
        frame_to_hex(frame, FRAME_LEN, hex, sizeof(hex));
        printf("RX: %s\n", hex);
    }
    if (frame[0] != FRAME_START) {
        printf("RX ERROR: Invalid START 0x%02X\n", frame[0]);
        return 0;
    }
    int is_read = (frame[1] & 0x80u) != 0;
    uint32_t addr = ((uint32_t)(frame[1] & 0x7Fu)) << 2;
    if (is_read != expected_read) {
        printf("RX ERROR: R/W mismatch (expected %d, received %d)\n", expected_read, is_read);
        return 0;
    }
    if (addr != expected_addr) {
        printf("RX ERROR: Address mismatch (expected 0x%08lX, received 0x%08lX)\n",
               (unsigned long)expected_addr, (unsigned long)addr);
        return 0;
    }
    *data_out = (uint32_t)frame[2] | ((uint32_t)frame[3] << 8) |
                ((uint32_t)frame[4] << 16) | ((uint32_t)frame[5] << 24);
    return 1;
}

static int transfer_frame(uint32_t addr, uint32_t data, int is_read,
                          uint32_t *response, int debug)
{
    uint8_t tx[FRAME_LEN];
    char hex[FRAME_LEN * 3 + 1];
    if (!build_frame(addr, data, is_read, tx)) return 0;
    if (debug) {
        frame_to_hex(tx, FRAME_LEN, hex, sizeof(hex));
        printf("TX: %s\n", hex);
    }
    if (!PurgeComm(g_serial, PURGE_RXCLEAR)) {
        printf("ERROR: Failed to clear UART RX buffer\n");
        return 0;
    }
    if (!uart_write_exact(tx, FRAME_LEN)) {
        printf("ERROR: UART transmit failed\n");
        return 0;
    }
    return uart_receive_frame(addr, is_read, response, debug);
}

static int read_register(uint32_t addr, uint32_t *value_out, int debug)
{
    return transfer_frame(addr, 0, 1, value_out, debug);
}

static int write_register(uint32_t addr, uint32_t data, int debug)
{
    uint32_t response_data = 0;
    if (!transfer_frame(addr, data, 0, &response_data, debug)) return 0;
    if (debug) printf("WRITE RESPONSE OK, DATA=0x%08lX\n", (unsigned long)response_data);
    return 1;
}

static uint32_t random_u32(void)
{
    /* Portable across implementations where RAND_MAX is only 32767. */
    uint32_t v = 0;
    for (int i = 0; i < 4; ++i)
        v = (v << 8) | (uint32_t)(rand() & 0xFF);
    return v;
}

static void run_continuous_test(int random_data)
{
    unsigned long long verified = 0;
    printf("\nTest %d: continuous %s write/read, slots 1-3\n",
           random_data ? 4 : 3, random_data ? "random" : "fixed");
    printf("Press any key to stop.\n");
    for (;;) {
        for (uint32_t slot = 1; slot <= 3; ++slot) {
            for (uint32_t reg = 0; reg < REG_PER_SLOT; ++reg) {
                uint32_t addr = slot * SLOT_SIZE + reg * 4u;
                uint32_t data = random_data ? random_u32() : 0x12345678u;
                uint32_t readback = 0;
                if (_kbhit()) {
                    (void)_getch();
                    printf("\nStopped. Verified: %llu registers\n", verified);
                    return;
                }
                if (!write_register(addr, data, 0)) {
                    printf("WRITE ERROR at 0x%08lX, verified: %llu\n", (unsigned long)addr, verified);
                    return;
                }
                if (!read_register(addr, &readback, 0)) {
                    printf("READ ERROR at 0x%08lX, verified: %llu\n", (unsigned long)addr, verified);
                    return;
                }
                if (readback != data) {
                    printf("VERIFY ERROR: slot %lu, reg %lu, AXI 0x%08lX\n",
                           (unsigned long)slot, (unsigned long)reg, (unsigned long)addr);
                    printf("Expected: 0x%08lX, received: 0x%08lX\n",
                           (unsigned long)data, (unsigned long)readback);
                    printf("Verified: %llu\n", verified);
                    return;
                }
                ++verified;
                if (verified % 128u == 0)
                    printf("No error after %llu registers verified.\n", verified);
            }
        }
    }
}

static void display_memory_map(void)
{
    printf("\nSlot    AXI start    AXI end    Frame addresses\n");
    for (uint32_t slot = 0; slot < 4; ++slot) {
        uint32_t start = slot * SLOT_SIZE;
        uint32_t end = start + 0x7Cu;
        printf(" %lu      0x%04lX       0x%04lX      0x%02lX-0x%02lX\n",
               (unsigned long)slot, (unsigned long)start, (unsigned long)end,
               (unsigned long)(start >> 2), (unsigned long)(end >> 2));
    }
}

static void display_menu(void)
{
    printf("\n===== Main Menu =====\n");
    printf("1. Read System registers 0x00 to 0x1C\n");
    printf("2. Write/read 0x12345678 at AXI 0x80\n");
    printf("3. Continuous fixed-data test (slots 1-3)\n");
    printf("4. Continuous random-data test (slots 1-3)\n");
    printf("5. Display memory map\n");
    printf("0. Exit\n=====================\n");
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
    g_serial = CreateFileA(port_path, GENERIC_READ | GENERIC_WRITE, 0, NULL,
                           OPEN_EXISTING, 0, NULL);
    if (g_serial == INVALID_HANDLE_VALUE) {
        printf("ERROR: Unable to open %s (Win32 error %lu)\n",
               UART_PORT, (unsigned long)GetLastError());
        return 0;
    }
    memset(&dcb, 0, sizeof(dcb));
    dcb.DCBlength = sizeof(dcb);
    if (!GetCommState(g_serial, &dcb)) goto error;
    dcb.BaudRate = UART_BAUDRATE;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fBinary = TRUE;
    dcb.fParity = FALSE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fOutX = FALSE;
    dcb.fInX = FALSE;
    dcb.fDtrControl = DTR_CONTROL_DISABLE;
    dcb.fRtsControl = RTS_CONTROL_DISABLE;
    if (!SetCommState(g_serial, &dcb)) goto error;
    if (!SetupComm(g_serial, 4096, 4096)) goto error;
    memset(&timeouts, 0, sizeof(timeouts));
    timeouts.ReadIntervalTimeout = 50;
    timeouts.ReadTotalTimeoutConstant = 2000;
    timeouts.WriteTotalTimeoutConstant = 2000;
    if (!SetCommTimeouts(g_serial, &timeouts)) goto error;
    PurgeComm(g_serial, PURGE_RXCLEAR | PURGE_TXCLEAR);
    return 1;
error:
    printf("ERROR: UART configuration failed (Win32 error %lu)\n",
           (unsigned long)GetLastError());
    close_serial();
    return 0;
}

int main(void)
{
    char input[32];
    srand((unsigned)time(NULL));
    if (!open_serial()) return EXIT_FAILURE;
    for (;;) {
        display_menu();
        printf("Enter your choice: ");
        if (!fgets(input, sizeof(input), stdin)) break;
        int choice = atoi(input);
        if (choice == 0) break;
        if (choice == 1) {
            printf("\nSystem registers:\n Address       Value\n");
            for (uint32_t addr = 0; addr < 0x20u; addr += 4u) {
                uint32_t value = 0;
                if (read_register(addr, &value, 1))
                    printf("0x%08lX    0x%08lX\n", (unsigned long)addr, (unsigned long)value);
                else
                    printf("0x%08lX    READ ERROR\n", (unsigned long)addr);
            }
        } else if (choice == 2) {
            const uint32_t addr = 0x80u, expected = 0x12345678u;
            uint32_t value = 0;
            int wr_ok = write_register(addr, expected, 1);
            if (!wr_ok) printf("Write response failed, continuing with read...\n");
            if (!read_register(addr, &value, 1)) printf("Read failed\n");
            else {
                printf("Read back: 0x%08lX\n", (unsigned long)value);
                if (value == expected) printf("PASS (readback matches; write response %s)\n", wr_ok ? "OK" : "FAILED");
                else printf("FAIL: expected 0x%08lX, received 0x%08lX\n",
                            (unsigned long)expected, (unsigned long)value);
            }
        } else if (choice == 3 || choice == 4) {
            run_continuous_test(choice == 4);
        } else if (choice == 5) {
            display_memory_map();
        } else {
            printf("Invalid choice.\n");
        }
    }
    close_serial();
    return EXIT_SUCCESS;
}
