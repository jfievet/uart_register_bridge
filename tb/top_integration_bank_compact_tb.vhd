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
    signal tx_frame           : std_logic_vector(47 downto 0);
    signal rx_frame           : std_logic_vector(47 downto 0);
    signal rx_data            : std_logic_vector(31 downto 0);
    signal frame_ref          : std_logic_vector(31 downto 0);

    function build_wr_frame (
        addr : std_logic_vector(31 downto 0);
        data : std_logic_vector(31 downto 0)
    ) return std_logic_vector is

        variable frame : std_logic_vector(47 downto 0);

    begin

        -- Build complete frame
        frame(7 downto 0)  := x"AA";
        frame(14 downto 8) := addr(6 downto 0);
        frame(15)          := '0';

        frame(23 downto 16) := data(7 downto 0);
        frame(31 downto 24) := data(15 downto 8);
        frame(39 downto 32) := data(23 downto 16);
        frame(47 downto 40) := data(31 downto 24);

        return frame;

    end function build_wr_frame;

    function build_rd_frame (
        addr : std_logic_vector(31 downto 0)
    ) return std_logic_vector is

        variable frame : std_logic_vector(47 downto 0);
        variable data  : std_logic_vector(31 downto 0) := (others => '0');

    begin

        -- Build complete frame
        frame(7 downto 0)  := x"AA";
        frame(14 downto 8) := addr(6 downto 0);
        frame(15)          := '1';

        frame(23 downto 16) := data(7 downto 0);
        frame(31 downto 24) := data(15 downto 8);
        frame(39 downto 32) := data(23 downto 16);
        frame(47 downto 40) := data(31 downto 24);

        return frame;

    end function build_rd_frame;

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
            frame_addr <= x"00000002";
            frame_data <= x"12345678";
            wait for 0 ns;
            tx_frame <= build_wr_frame(frame_addr, frame_data);
            wait for 0 ns;

            info("Send the tx wr frame on uart");

            for i in 0 to 5 loop

                push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

            end loop;

            info("Receive ack of the tx wr frame on uart");

            for i in 0 to 5 loop

                pop_stream(net, slave_stream, v_rx_byte);
                info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                wait for 0 ns;

            end loop;

            info("--------------------------------------");
            info("------ Read Frame                     ");
            info("--------------------------------------");

            info("Build the tx rd frame");
            frame_addr <= x"00000002";
            wait for 0 ns;
            tx_frame <= build_rd_frame(frame_addr);
            wait for 0 ns;

            info("Send the tx rd frame on uart");

            for i in 0 to 5 loop

                push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));

            end loop;

            info("Receive ack of the tx rd frame on uart");

            for i in 0 to 5 loop

                pop_stream(net, slave_stream, v_rx_byte);
                info("RX[" & integer'image(i) & "] = 0x" & to_hstring(v_rx_byte));
                rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                wait for 0 ns;

            end loop;

            rx_data <= rx_frame(47 downto 16);
            wait for 0 ns;

            check_equal(rx_data, std_logic_vector'(x"12345678"), "Returned data mismatch");

            info("Simulation finished");
        end if; -- end test 002

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
        -- test_005_write_read_126
        ------------------------------------------------------------------------
        if run("test_005_write_read_126") then
            info("Wait for reset release");
            wait until falling_edge(async_reset);
            wait for 1 us;

            ------------------------------------------------------------------------
            -- Write 126 registers
            ------------------------------------------------------------------------
            info("--------------------------------------");
            info("------ Write 126 Registers           ");
            info("--------------------------------------");

            for reg_index in 2 to 127 loop

                frame_addr <= std_logic_vector(to_unsigned(reg_index, 32));
                frame_data <= std_logic_vector(
                    unsigned'(x"12345678") + to_unsigned(reg_index, 32)
                    );
                wait for 0 ns;

                tx_frame <= build_wr_frame(frame_addr, frame_data);
                wait for 0 ns;

                info("Write register " & integer'image(reg_index) &
                " ADDR=0x" & to_hstring(frame_addr) &
                " DATA=0x" & to_hstring(frame_data));

                for i in 0 to 5 loop
                    push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));
                end loop;

                -- Receive write acknowledgement
                for i in 0 to 5 loop
                    pop_stream(net, slave_stream, v_rx_byte);
                    rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                end loop;

            end loop;

            ------------------------------------------------------------------------
            -- Read and verify 126 registers
            ------------------------------------------------------------------------
            info("--------------------------------------");
            info("------ Read 126 Registers            ");
            info("--------------------------------------");

            for reg_index in 2 to 127 loop

                frame_addr <= std_logic_vector(to_unsigned(reg_index, 32));
                wait for 0 ns;

                tx_frame <= build_rd_frame(frame_addr);
                wait for 0 ns;

                info("Read register " & integer'image(reg_index) &
                " ADDR=0x" & to_hstring(frame_addr));

                for i in 0 to 5 loop
                    push_stream(net, master_stream, tx_frame(i * 8 + 7 downto i * 8));
                end loop;

                -- Receive read response
                for i in 0 to 5 loop
                    pop_stream(net, slave_stream, v_rx_byte);
                    rx_frame(i * 8 + 7 downto i * 8) <= v_rx_byte;
                end loop;

                wait for 0 ns;

                rx_data <= rx_frame(47 downto 16);
                wait for 0 ns;

                check_equal(
                rx_data,
                std_logic_vector(unsigned'(x"12345678") + to_unsigned(reg_index, 32)),
                "Readback mismatch at register " & integer'image(reg_index)
                );

            end loop;

            info("Simulation finished");
        end if;
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
