library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.data_types_context;
use vunit_lib.uart_pkg.all;
use vunit_lib.sync_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.stream_slave_pkg.all;

library work;
use work.utilities_pkg.all;
use work.axi_lite_interconnect_pkg.all;

entity top_integration_tb is
    generic (
        runner_cfg : string := runner_cfg_default
    );
end entity top_integration_tb;

architecture rtl of top_integration_tb is

    constant master_uart   : uart_master_t   := new_uart_master;
    constant master_stream : stream_master_t := as_stream(master_uart);
    constant slave_uart    : uart_slave_t    := new_uart_slave(data_length => 8);
    constant slave_stream  : stream_slave_t  := as_stream(slave_uart);

    constant uart_clock_divider : integer   := 8; -- round(clock / uart_bitrate*8)  ie. for 300e6/4.6875e6*8=8
    constant use_async_reset    : boolean   := TRUE;
    constant use_sync_reset     : boolean   := TRUE;
    constant async_reset_active : std_logic := '1';
    constant sync_reset_active  : std_logic := '1';

    constant nb_reg_slots : integer := 3;
    constant nb_cells     : integer := 32;

    constant clock_const       : time    := 1.66 ns; -- halft period
    constant clock_frequency   : natural := 300_000_000;
    constant async_reset_const : time    := 123 ns;

    signal clock       : std_logic;
    signal async_reset : std_logic;
    signal sync_reset  : std_logic;

    signal top_axi_awvalid    : std_logic;
    signal top_axi_awready    : std_logic;
    signal top_axi_awaddr     : std_logic_vector(31 downto 0);
    signal top_axi_wvalid     : std_logic;
    signal top_axi_wready     : std_logic;
    signal top_axi_wdata      : std_logic_vector(31 downto 0);
    signal top_axi_wstrb      : std_logic_vector(3 downto 0);
    signal top_axi_bvalid     : std_logic;
    signal top_axi_bready     : std_logic;
    signal top_axi_bresp      : std_logic_vector(1 downto 0);
    signal top_axi_arvalid    : std_logic;
    signal top_axi_arready    : std_logic;
    signal top_axi_araddr     : std_logic_vector(31 downto 0);
    signal top_axi_rvalid     : std_logic;
    signal top_axi_rready     : std_logic;
    signal top_axi_rdata      : std_logic_vector(31 downto 0);
    signal top_axi_rresp      : std_logic_vector(1 downto 0);
    signal uart_txd           : std_logic;
    signal uart_rxd           : std_logic;
    signal timeout_error_flag : std_logic;
    signal soft_reset         : std_logic;
    signal frame_addr         : std_logic_vector(31 downto 0);
    signal frame_data         : std_logic_vector(31 downto 0);
    signal tx_frame           : std_logic_vector(111 downto 0);
    signal rx_frame           : std_logic_vector(111 downto 0);
    signal rx_data            : std_logic_vector(31 downto 0);
    signal frame_ref          : std_logic_vector(31 downto 0);

    function calc_crc32 (
        data : std_logic_vector(79 downto 0) -- 10 bytes
    ) return std_logic_vector is

        variable crc      : std_logic_vector(31 downto 0) := (others => '1');
        variable next_crc : std_logic_vector(31 downto 0);
        variable bit_in   : std_logic;

    begin

        for byte_idx in 0 to 9 loop

            for bit_idx in 7 downto 0 loop

                bit_in := data(byte_idx * 8 + bit_idx) xor
                    crc(31);

                next_crc := crc(30 downto 0) & '0';

                if (bit_in = '1') then
                    next_crc := next_crc xor x"04C11DB7";
                end if;

                crc := next_crc;

            end loop;

        end loop;

        return crc;

    end function calc_crc32;

    function build_wr_frame (
        addr : std_logic_vector(31 downto 0);
        data : std_logic_vector(31 downto 0)
    ) return std_logic_vector is

        variable frame    : std_logic_vector(111 downto 0);
        variable crc_data : std_logic_vector(79 downto 0); -- 10 bytes
        variable crc32    : std_logic_vector(31 downto 0);

    begin

        -- Bytes used for CRC calculation:
        -- START | CMD | ADDR[0]..ADDR[3] | DATA[0]..DATA[3]

        crc_data(7 downto 0)  := x"AA";
        crc_data(15 downto 8) := x"01";

        crc_data(23 downto 16) := addr(7 downto 0);
        crc_data(31 downto 24) := addr(15 downto 8);
        crc_data(39 downto 32) := addr(23 downto 16);
        crc_data(47 downto 40) := addr(31 downto 24);

        crc_data(55 downto 48) := data(7 downto 0);
        crc_data(63 downto 56) := data(15 downto 8);
        crc_data(71 downto 64) := data(23 downto 16);
        crc_data(79 downto 72) := data(31 downto 24);

        crc32 := calc_crc32(crc_data); -- your CRC function

        -- Build complete frame
        frame(7 downto 0)  := x"AA";
        frame(15 downto 8) := x"01";

        frame(23 downto 16) := addr(7 downto 0);
        frame(31 downto 24) := addr(15 downto 8);
        frame(39 downto 32) := addr(23 downto 16);
        frame(47 downto 40) := addr(31 downto 24);

        frame(55 downto 48) := data(7 downto 0);
        frame(63 downto 56) := data(15 downto 8);
        frame(71 downto 64) := data(23 downto 16);
        frame(79 downto 72) := data(31 downto 24);

        -- CRC32 LSB first
        frame(87 downto 80)   := crc32(7 downto 0);
        frame(95 downto 88)   := crc32(15 downto 8);
        frame(103 downto 96)  := crc32(23 downto 16);
        frame(111 downto 104) := crc32(31 downto 24);

        return frame;

    end function build_wr_frame;

    function build_rd_frame (
        addr : std_logic_vector(31 downto 0)
    ) return std_logic_vector is

        variable frame    : std_logic_vector(111 downto 0);
        variable crc_data : std_logic_vector(79 downto 0); -- 10 bytes
        variable crc32    : std_logic_vector(31 downto 0);
        variable data     : std_logic_vector(31 downto 0) := (others => '0');

    begin

        -- Bytes used for CRC calculation:
        -- START | CMD | ADDR[0]..ADDR[3] | DATA[0]..DATA[3]

        crc_data(7 downto 0)  := x"AA";
        crc_data(15 downto 8) := x"02";

        crc_data(23 downto 16) := addr(7 downto 0);
        crc_data(31 downto 24) := addr(15 downto 8);
        crc_data(39 downto 32) := addr(23 downto 16);
        crc_data(47 downto 40) := addr(31 downto 24);

        crc_data(55 downto 48) := data(7 downto 0);
        crc_data(63 downto 56) := data(15 downto 8);
        crc_data(71 downto 64) := data(23 downto 16);
        crc_data(79 downto 72) := data(31 downto 24);

        crc32 := calc_crc32(crc_data);

        -- Build complete frame
        frame(7 downto 0)  := x"AA";
        frame(15 downto 8) := x"02";

        frame(23 downto 16) := addr(7 downto 0);
        frame(31 downto 24) := addr(15 downto 8);
        frame(39 downto 32) := addr(23 downto 16);
        frame(47 downto 40) := addr(31 downto 24);

        -- DATA field = 0 for read requests
        frame(55 downto 48) := x"00";
        frame(63 downto 56) := x"00";
        frame(71 downto 64) := x"00";
        frame(79 downto 72) := x"00";

        -- CRC32 LSB first
        frame(87 downto 80)   := crc32(7 downto 0);
        frame(95 downto 88)   := crc32(15 downto 8);
        frame(103 downto 96)  := crc32(23 downto 16);
        frame(111 downto 104) := crc32(31 downto 24);

        return frame;

    end function build_rd_frame;

    function check_frame_crc (
        frame : std_logic_vector(111 downto 0)
    ) return boolean is

        variable crc_data     : std_logic_vector(79 downto 0);
        variable crc_expected : std_logic_vector(31 downto 0);
        variable crc_received : std_logic_vector(31 downto 0);

    begin

        -- First 10 bytes of frame
        crc_data := frame(79 downto 0);

        crc_expected := calc_crc32(crc_data);

        -- CRC field (LSB first)
        crc_received(7 downto 0)   := frame(87 downto 80);
        crc_received(15 downto 8)  := frame(95 downto 88);
        crc_received(23 downto 16) := frame(103 downto 96);
        crc_received(31 downto 24) := frame(111 downto 104);

        return crc_expected = crc_received;

    end function check_frame_crc;

begin

    -----------------------------------------
    -- clock generation
    -----------------------------------------
    clock_gen_pr : process is
    begin

        clock <= '1';
        wait for clock_const;

        clock <= '0';
        wait for clock_const;

    end process clock_gen_pr;

    -----------------------------------------
    -- async_reset generation
    -----------------------------------------
    async_reset_gen_pr : process is
    begin

        async_reset <= not(async_reset_active);
        wait for 1 us;

        async_reset <= async_reset_active;
        wait for async_reset_const;

        async_reset <= not(async_reset_active);
        wait;

    end process async_reset_gen_pr;

    sync_reset <= not(sync_reset_active);

    top_integration_inst : entity work.top_integration
        generic map(
            clock_frequency    => CLOCK_FREQUENCY,
            use_async_reset    => USE_ASYNC_RESET,
            use_sync_reset     => USE_SYNC_RESET,
            async_reset_active => ASYNC_RESET_ACTIVE,
            sync_reset_active  => SYNC_RESET_ACTIVE,
            uart_clock_divider => UART_CLOCK_DIVIDER
        )
        port map
        (
            clock              => clock,
            async_reset        => async_reset,
            sync_reset         => sync_reset,
            s_axi_awvalid      => top_axi_awvalid,
            s_axi_awready      => top_axi_awready,
            s_axi_awaddr       => top_axi_awaddr,
            s_axi_wvalid       => top_axi_wvalid,
            s_axi_wready       => top_axi_wready,
            s_axi_wdata        => top_axi_wdata,
            s_axi_wstrb        => top_axi_wstrb,
            s_axi_bvalid       => top_axi_bvalid,
            s_axi_bready       => top_axi_bready,
            s_axi_bresp        => top_axi_bresp,
            s_axi_arvalid      => top_axi_arvalid,
            s_axi_arready      => top_axi_arready,
            s_axi_araddr       => top_axi_araddr,
            s_axi_rvalid       => top_axi_rvalid,
            s_axi_rready       => top_axi_rready,
            s_axi_rdata        => top_axi_rdata,
            s_axi_rresp        => top_axi_rresp,
            soft_reset         => soft_reset,
            uart_txd           => uart_txd,
            uart_rxd           => uart_rxd,
            timeout_error_flag => timeout_error_flag
        );

    test_runner : process is

        variable v_rx_byte : std_logic_vector(7 downto 0);

    begin

        test_runner_setup(runner, runner_cfg);

        set_baud_rate(net, master_uart, 4687500);
        set_baud_rate(net, slave_uart, 4687500);

        ------------------------------------------------------------------------
        -- test_001_reset_only
        ------------------------------------------------------------------------
        if run("test_001_reset_only") then
            info("Wait for reset release");
            wait until falling_edge(async_reset);
            wait for 1 us;
        end if;

        ------------------------------------------------------------------------
        -- test_002_write_read_one
        ------------------------------------------------------------------------
        if run("test_002_write_read_one") then
            info("Wait for reset release");
            wait until falling_edge(async_reset);
            wait for 1 us;

            info("--------------------------------------");
            info("------ Write Frame                    ");
            info("--------------------------------------");

            info("Build the tx wr frame");
            frame_addr <= x"00001000";
            frame_data <= x"12345678";
            wait for 0 ns;
            tx_frame <= build_wr_frame(frame_addr, frame_data);
            wait for 0 ns;

            info("Send the tx wr frame on uart");

            for i in 0 to 13 loop

                push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

            end loop;

            info("Receive ack of the tx wr frame on uart");

            for i in 0 to 13 loop

                pop_stream(net, slave_stream, v_rx_byte);
                info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                wait for 0 ns;

            end loop;

            check_true(
            check_frame_crc(rx_frame),
            "RX frame CRC check failed"
            );

            info("--------------------------------------");
            info("------ Read Frame                     ");
            info("--------------------------------------");

            info("Build the tx rd frame");
            frame_addr <= x"00001000";
            wait for 0 ns;
            tx_frame <= build_rd_frame(frame_addr);
            wait for 0 ns;

            info("Send the tx rd frame on uart");

            for i in 0 to 13 loop

                push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

            end loop;

            info("Receive ack of the tx rd frame on uart");

            for i in 0 to 13 loop

                pop_stream(net, slave_stream, v_rx_byte);
                info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                wait for 0 ns;

            end loop;

            check_true(
            check_frame_crc(rx_frame),
            "RX frame CRC check failed"
            );
            rx_data <= rx_frame(79 downto 48);
            wait for 0 ns;

            check_equal(rx_data, std_logic_vector'(x"12345678"), "Returned data mismatch");

            info("Simulation finished");
        end if; -- end test 002

        ------------------------------------------------------------------------
        -- test_003_write_read_4s_32c
        ------------------------------------------------------------------------
        if run("test_003_write_read_4s_1c") then
            info("Wait for reset release");
            wait until falling_edge(async_reset);
            wait for 1 us;

            for slot_idx in 0 to nb_reg_slots - 1 loop

                for cell_idx in 0 to 0 loop

                    info("--------------------------------------");
                    info("------ Write Frame                    ");
                    info("--------------------------------------");

                    info("Build the tx wr frame");
                    frame_addr <= std_logic_vector(to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32));
                    frame_data <= std_logic_vector(to_unsigned(12345678, 32) + to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32)); -- std_logic_vector(to_unsigned(123456789,32) + to_unsigned(4096,32)+ to_unsigned(slot_idx*4096,32) + to_unsigned(cell_idx*4,32));
                    wait for 0 ns;
                    info("frame_addr = 0x" & to_hstring(frame_addr));
                    info("frame_data = 0x" & to_hstring(frame_data));
                    wait for 0 ns;
                    tx_frame <= build_wr_frame(frame_addr, frame_data);
                    wait for 0 ns;

                    info("Send the tx wr frame on uart");

                    for i in 0 to 13 loop

                        push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

                    end loop;

                    info("Receive ack of the tx wr frame on uart");

                    for i in 0 to 13 loop

                        pop_stream(net, slave_stream, v_rx_byte);
                        info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                        rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                        wait for 0 ns;

                    end loop;

                    check_true(
                    check_frame_crc(rx_frame),
                    "RX frame CRC check failed"
                    );

                end loop; -- cell loop

            end loop; -- slot loop

            for slot_idx in 0 to nb_reg_slots - 1 loop

                for cell_idx in 0 to 0 loop

                    info("--------------------------------------");
                    info("------ Read Frame                     ");
                    info("--------------------------------------");

                    info("Build the tx rd frame");
                    frame_addr <= std_logic_vector(to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32));
                    wait for 0 ns;
                    info("frame_addr = 0x" & to_hstring(frame_addr));
                    tx_frame <= build_rd_frame(frame_addr);
                    wait for 0 ns;

                    info("Send the tx rd frame on uart");

                    for i in 0 to 13 loop

                        push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

                    end loop;

                    info("Receive ack of the tx rd frame on uart");

                    for i in 0 to 13 loop

                        pop_stream(net, slave_stream, v_rx_byte);
                        info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                        rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                        wait for 0 ns;

                    end loop;

                    check_true(
                    check_frame_crc(rx_frame),
                    "RX frame CRC check failed"
                    );
                    rx_data <= rx_frame(79 downto 48);
                    wait for 0 ns;
                    frame_ref <= std_logic_vector(to_unsigned(12345678, 32) + to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32)); -- std_logic_vector(to_unsigned(123456789,32) + to_unsigned(4096,32)+ to_unsigned(slot_idx*4096,32) + to_unsigned(cell_idx*4,32));
                    wait for 0 ns;

                    check_equal(rx_data, frame_ref, "Returned data mismatch");

                end loop; -- end cell loop

            end loop; -- end slot loop

            info("Simulation finished");
        end if; -- end test 003

        ------------------------------------------------------------------------
        -- test_004_write_fail_glitch
        ------------------------------------------------------------------------
        if run("test_004_write_fail_glitch") then
            info("Wait for reset release");
            wait until falling_edge(async_reset);
            wait for 1 us;

            info("Send a glitch packet 0xFF");
            push_stream(net, master_stream, x"FF");
            wait for 1 ms;

            info("Send a sync word 0xAA");
            push_stream(net, master_stream, x"AA");
            info("Wait for 6 ms so the timeout occurs");
            wait for 6 ms;

            check_equal(timeout_error_flag, '1', "Check timout failed");

            info("Simulation finished");
        end if; -- end 004

        ------------------------------------------------------------------------
        -- test_005_write_bad_crc
        ------------------------------------------------------------------------
        if run("test_005_write_bad_crc") then
            info("Wait for reset release");
            wait until falling_edge(async_reset);
            wait for 1 us;

            info("--------------------------------------");
            info("------ Write Frame with a bad crc     ");
            info("--------------------------------------");

            info("Build the tx wr frame");
            frame_addr <= x"00001000";
            frame_data <= x"12345678";
            wait for 0 ns;
            tx_frame <= build_wr_frame(frame_addr, frame_data);
            wait for 0 ns;
            tx_frame(111) <= not (tx_frame(111));
            wait for 0 ns;

            info("Send the tx wr frame on uart");

            for i in 0 to 13 loop

                push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

            end loop;

            wait for 2 ms;

            info("Receive ack of the tx wr frame on uart");

            for i in 0 to 13 loop

                pop_stream(net, slave_stream, v_rx_byte);
                info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                wait for 0 ns;

            end loop;

            check_true(
            check_frame_crc(rx_frame),
            "RX frame CRC check failed"
            );

            info("--------------------------------------");
            info("------ Read Frame (CRC OK counter)    ");
            info("--------------------------------------");

            info("Build the tx rd frame");
            frame_addr <= x"00000018";
            wait for 0 ns;
            tx_frame <= build_rd_frame(frame_addr);
            wait for 0 ns;

            info("Send the tx rd frame on uart");

            for i in 0 to 13 loop

                push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

            end loop;

            info("Receive ack of the tx rd frame on uart");

            for i in 0 to 13 loop

                pop_stream(net, slave_stream, v_rx_byte);
                info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                wait for 0 ns;

            end loop;

            check_true(
            check_frame_crc(rx_frame),
            "RX frame CRC check failed"
            );
            rx_data <= rx_frame(79 downto 48);
            wait for 0 ns;

            -- check_equal( rx_data, std_logic_vector'(x"12345678"), "Returned data mismatch");

            info("--------------------------------------");
            info("------ Read Frame (CRC NOK counter)   ");
            info("--------------------------------------");

            info("Build the tx rd frame");
            frame_addr <= x"0000001C";
            wait for 0 ns;
            tx_frame <= build_rd_frame(frame_addr);
            wait for 0 ns;

            info("Send the tx rd frame on uart");

            for i in 0 to 13 loop

                push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

            end loop;

            info("Receive ack of the tx rd frame on uart");

            for i in 0 to 13 loop

                pop_stream(net, slave_stream, v_rx_byte);
                info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                wait for 0 ns;

            end loop;

            check_true(
            check_frame_crc(rx_frame),
            "RX frame CRC check failed"
            );
            rx_data <= rx_frame(79 downto 48);
            wait for 0 ns;

            -- check_equal( rx_data, std_logic_vector'(x"12345678"), "Returned data mismatch");

            info("Simulation finished");
        end if;

        ------------------------------------------------------------------------
        -- test_099_write_read_4s_32c
        ------------------------------------------------------------------------
        if run("test_099_write_read_4s_32c") then
            info("Wait for reset release");
            wait until falling_edge(async_reset);
            wait for 1 us;

            for slot_idx in 0 to nb_reg_slots - 1 loop

                for cell_idx in 0 to nb_cells - 1 loop

                    info("--------------------------------------");
                    info("------ Write Frame                    ");
                    info("--------------------------------------");

                    info("Build the tx wr frame");
                    frame_addr <= std_logic_vector(to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32));
                    frame_data <= std_logic_vector(to_unsigned(12345678, 32) + to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32)); -- std_logic_vector(to_unsigned(123456789,32) + to_unsigned(4096,32)+ to_unsigned(slot_idx*4096,32) + to_unsigned(cell_idx*4,32));
                    wait for 0 ns;
                    info("frame_addr = 0x" & to_hstring(frame_addr));
                    info("frame_data = 0x" & to_hstring(frame_data));
                    wait for 0 ns;
                    tx_frame <= build_wr_frame(frame_addr, frame_data);
                    wait for 0 ns;

                    info("Send the tx wr frame on uart");

                    for i in 0 to 13 loop

                        push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

                    end loop;

                    -- wait for 2.5 ms; -- Time on a 115200 bases

                    info("Receive ack of the tx wr frame on uart");

                    for i in 0 to 13 loop

                        pop_stream(net, slave_stream, v_rx_byte);
                        info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                        rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                        wait for 0 ns;

                    end loop;

                    check_true(
                    check_frame_crc(rx_frame),
                    "RX frame CRC check failed"
                    );

                end loop; -- cell loop

            end loop; -- slot loop

            for slot_idx in 0 to nb_reg_slots - 1 loop

                for cell_idx in 0 to nb_cells - 1 loop

                    info("--------------------------------------");
                    info("------ Read Frame                     ");
                    info("--------------------------------------");

                    info("Build the tx rd frame");
                    frame_addr <= std_logic_vector(to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32));
                    wait for 0 ns;
                    info("frame_addr = 0x" & to_hstring(frame_addr));
                    tx_frame <= build_rd_frame(frame_addr);
                    wait for 0 ns;

                    info("Send the tx rd frame on uart");

                    for i in 0 to 13 loop

                        push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

                    end loop;

                    info("Receive ack of the tx rd frame on uart");

                    for i in 0 to 13 loop

                        pop_stream(net, slave_stream, v_rx_byte);
                        info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                        rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                        wait for 0 ns;

                    end loop;

                    check_true(
                    check_frame_crc(rx_frame),
                    "RX frame CRC check failed"
                    );
                    rx_data <= rx_frame(79 downto 48);
                    wait for 0 ns;
                    frame_ref <= std_logic_vector(to_unsigned(12345678, 32) + to_unsigned(4096, 32) + to_unsigned(slot_idx * 4096, 32) + to_unsigned(cell_idx * 4, 32)); -- std_logic_vector(to_unsigned(123456789,32) + to_unsigned(4096,32)+ to_unsigned(slot_idx*4096,32) + to_unsigned(cell_idx*4,32));
                    wait for 0 ns;

                    check_equal(rx_data, frame_ref, "Returned data mismatch");

                end loop; -- end cell loop

            end loop; -- end slot loop

            info("Simulation finished");
        end if; -- end test 099

        test_runner_cleanup(runner);

    end process test_runner;

    ------------------------------------------------------------------------
    -- VUNIT uart master
    ------------------------------------------------------------------------
    uart_master_inst : entity vunit_lib.uart_master
        generic map(
            uart => master_uart
        )
        port map
        (
            tx => uart_rxd
        );

    ------------------------------------------------------------------------
    -- VUNIT uart slave
    ------------------------------------------------------------------------
    uart_slave_inst : entity vunit_lib.uart_slave
        generic map(
            uart => slave_uart
        )
        port map
        (
            rx => uart_txd
        );

end architecture rtl;
