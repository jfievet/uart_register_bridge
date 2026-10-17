library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi_lite_interconnect_pkg.all;
use work.axi_lite_slave_pkg.all;
use work.top_integration_pkg.all;
use work.timestamp_pkg.all;

entity top_integration is
    generic (
        clock_frequency    : natural   := 100_000_000;
        use_async_reset    : boolean   := TRUE;
        use_sync_reset     : boolean   := TRUE;
        async_reset_active : std_logic := '1';
        sync_reset_active  : std_logic := '1';
        uart_clock_divider : integer   := 108
    );
    port (
        clock              : in std_logic;
        async_reset        : in std_logic;
        sync_reset         : in std_logic;
        s_axi_awvalid      : in std_logic;
        s_axi_awready      : out std_logic;
        s_axi_awaddr       : in std_logic_vector(31 downto 0);
        s_axi_wvalid       : in std_logic;
        s_axi_wready       : out std_logic;
        s_axi_wdata        : in std_logic_vector(31 downto 0);
        s_axi_wstrb        : in std_logic_vector(3 downto 0);
        s_axi_bvalid       : out std_logic;
        s_axi_bready       : in std_logic;
        s_axi_bresp        : out std_logic_vector(1 downto 0);
        s_axi_arvalid      : in std_logic;
        s_axi_arready      : out std_logic;
        s_axi_araddr       : in std_logic_vector(31 downto 0);
        s_axi_rvalid       : out std_logic;
        s_axi_rready       : in std_logic;
        s_axi_rdata        : out std_logic_vector(31 downto 0);
        s_axi_rresp        : out std_logic_vector(1 downto 0);
        soft_reset         : out std_logic;
        uart_txd           : out std_logic;
        uart_rxd           : in std_logic;
        timeout_error_flag : out std_logic
    );
end entity top_integration;

architecture rtl of top_integration is

    signal bank_write_reg    : std_logic_vector(const_nb_bank_registers * 32 - 1 downto 0);
    signal bank_write_reg_en : std_logic_vector(const_nb_bank_registers - 1 downto 0);
    signal bank_read_reg     : std_logic_vector(const_nb_bank_registers * 32 - 1 downto 0);

    signal uart_axi_txd, uart_axi_rxd                                : std_logic;
    signal uart_bank_txd, uart_bank_rxd                              : std_logic;
    signal uart_axi_timeout_error_flag, uart_bank_timeout_error_flag : std_logic;
    signal uart_axi_crc_error_flag, uart_bank_crc_error_flag         : std_logic;
    signal uart_axi_crc_error_flag_en, uart_bank_crc_error_flag_en   : std_logic;

    signal s_axi_interconnect_awvalid : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_awready : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_awaddr  : axi_32b_bus_type;
    signal s_axi_interconnect_wvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_wready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_wdata   : axi_32b_bus_type;
    signal s_axi_interconnect_wstrb   : axi_4b_bus_type;
    signal s_axi_interconnect_bvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_bready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_bresp   : axi_2b_bus_type;
    signal s_axi_interconnect_arvalid : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_arready : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_araddr  : axi_32b_bus_type;
    signal s_axi_interconnect_rvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_rready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_interconnect_rdata   : axi_32b_bus_type;
    signal s_axi_interconnect_rresp   : axi_2b_bus_type;

    signal m_axi_interconnect_awvalid : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_awready : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_awaddr  : axi_32b_bus_type;
    signal m_axi_interconnect_wvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_wready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_wdata   : axi_32b_bus_type;
    signal m_axi_interconnect_wstrb   : axi_4b_bus_type;
    signal m_axi_interconnect_bvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_bready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_bresp   : axi_2b_bus_type;
    signal m_axi_interconnect_arvalid : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_arready : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_araddr  : axi_32b_bus_type;
    signal m_axi_interconnect_rvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_rready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_interconnect_rdata   : axi_32b_bus_type;
    signal m_axi_interconnect_rresp   : axi_2b_bus_type;

    signal s_axi_uart_awvalid : std_logic;
    signal s_axi_uart_awready : std_logic;
    signal s_axi_uart_awaddr  : std_logic_vector(31 downto 0);
    signal s_axi_uart_wvalid  : std_logic;
    signal s_axi_uart_wready  : std_logic;
    signal s_axi_uart_wdata   : std_logic_vector(31 downto 0);
    signal s_axi_uart_wstrb   : std_logic_vector(3 downto 0);
    signal s_axi_uart_bvalid  : std_logic;
    signal s_axi_uart_bready  : std_logic;
    signal s_axi_uart_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_uart_arvalid : std_logic;
    signal s_axi_uart_arready : std_logic;
    signal s_axi_uart_araddr  : std_logic_vector(31 downto 0);
    signal s_axi_uart_rvalid  : std_logic;
    signal s_axi_uart_rready  : std_logic;
    signal s_axi_uart_rdata   : std_logic_vector(31 downto 0);
    signal s_axi_uart_rresp   : std_logic_vector(1 downto 0);

    signal crc_error_flag    : std_logic;
    signal crc_error_flag_en : std_logic;

    -- signal test_register_write                  : register_array_type;
    -- signal test_register_write_en               : std_logic_vector(32 - 1 downto 0 );
    -- signal test_register_read                   : register_array_type;

    type test_register_array_type is array(0 to 31) of register_array_type;

    type test_register_array_en_type is array(0 to 31) of std_logic_vector(32 - 1 downto 0);

    signal test_register_write    : test_register_array_type;
    signal test_register_write_en : test_register_array_en_type;
    signal test_register_read     : test_register_array_type;

begin

    template_pr : process (clock, async_reset) is
    begin

        if ((async_reset = async_reset_active) and (use_async_reset = true)) then
        elsif rising_edge(clock) then
            if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
            end if;
        end if;

    end process template_pr;

    ----------------------------------------------------------------------------------------------------------
    -- AXI-L Interconnect
    ----------------------------------------------------------------------------------------------------------
    axi_lite_interconnect_inst : entity work.axi_lite_interconnect
        generic map(
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            nb_slave_ports     => const_nb_interc_slave_ports,
            nb_master_ports    => const_nb_interc_master_ports,
            addr_start         => ADDR_START,
            addr_end           => ADDR_END,
            addr_offset        => ADDR_START
        )
        port map
        (
            clock         => clock,
            async_reset   => async_reset,
            sync_reset    => sync_reset,
            m_axi_awvalid => m_axi_interconnect_awvalid,
            m_axi_awready => m_axi_interconnect_awready,
            m_axi_awaddr  => m_axi_interconnect_awaddr,
            m_axi_wvalid  => m_axi_interconnect_wvalid,
            m_axi_wready  => m_axi_interconnect_wready,
            m_axi_wdata   => m_axi_interconnect_wdata,
            m_axi_wstrb   => m_axi_interconnect_wstrb,
            m_axi_bvalid  => m_axi_interconnect_bvalid,
            m_axi_bready  => m_axi_interconnect_bready,
            m_axi_bresp   => m_axi_interconnect_bresp,
            m_axi_arvalid => m_axi_interconnect_arvalid,
            m_axi_arready => m_axi_interconnect_arready,
            m_axi_araddr  => m_axi_interconnect_araddr,
            m_axi_rvalid  => m_axi_interconnect_rvalid,
            m_axi_rready  => m_axi_interconnect_rready,
            m_axi_rdata   => m_axi_interconnect_rdata,
            m_axi_rresp   => m_axi_interconnect_rresp,
            s_axi_awvalid => s_axi_interconnect_awvalid,
            s_axi_awready => s_axi_interconnect_awready,
            s_axi_awaddr  => s_axi_interconnect_awaddr,
            s_axi_wvalid  => s_axi_interconnect_wvalid,
            s_axi_wready  => s_axi_interconnect_wready,
            s_axi_wdata   => s_axi_interconnect_wdata,
            s_axi_wstrb   => s_axi_interconnect_wstrb,
            s_axi_bvalid  => s_axi_interconnect_bvalid,
            s_axi_bready  => s_axi_interconnect_bready,
            s_axi_bresp   => s_axi_interconnect_bresp,
            s_axi_arvalid => s_axi_interconnect_arvalid,
            s_axi_arready => s_axi_interconnect_arready,
            s_axi_araddr  => s_axi_interconnect_araddr,
            s_axi_rvalid  => s_axi_interconnect_rvalid,
            s_axi_rready  => s_axi_interconnect_rready,
            s_axi_rdata   => s_axi_interconnect_rdata,
            s_axi_rresp   => s_axi_interconnect_rresp
        );

    -- AXI interconnect Slave 0
    s_axi_interconnect_awvalid(0) <= s_axi_awvalid;
    s_axi_interconnect_awaddr(0)  <= s_axi_awaddr;
    s_axi_interconnect_wvalid(0)  <= s_axi_wvalid;
    s_axi_interconnect_wdata(0)   <= s_axi_wdata;
    s_axi_interconnect_wstrb(0)   <= s_axi_wstrb;
    s_axi_interconnect_bready(0)  <= s_axi_bready;
    s_axi_interconnect_arvalid(0) <= s_axi_arvalid;
    s_axi_interconnect_araddr(0)  <= s_axi_araddr;
    s_axi_interconnect_rready(0)  <= s_axi_rready;

    s_axi_awready <= s_axi_interconnect_awready(0);
    s_axi_wready  <= s_axi_interconnect_wready(0);
    s_axi_bvalid  <= s_axi_interconnect_bvalid(0);
    s_axi_bresp   <= s_axi_interconnect_bresp(0);
    s_axi_arready <= s_axi_interconnect_arready(0);
    s_axi_rvalid  <= s_axi_interconnect_rvalid(0);
    s_axi_rdata   <= s_axi_interconnect_rdata(0);
    s_axi_rresp   <= s_axi_interconnect_rresp(0);

    ----------------------------------------------------------------------------------------------------------
    -- UART interface selection
    ----------------------------------------------------------------------------------------------------------
    -- Static mode selection: both bridge instances are present in RTL.
    -- Inactive UART receiver held at idle high.
    uart_axi_rxd <= uart_rxd when register_interface_mode = 0 else
        '1';
    uart_bank_rxd <= uart_rxd when register_interface_mode = 1 else
        '1';

    uart_txd <= uart_axi_txd when register_interface_mode = 0 else
        uart_bank_txd;
    timeout_error_flag <= uart_axi_timeout_error_flag when register_interface_mode = 0 else
        uart_bank_timeout_error_flag;
    crc_error_flag <= uart_axi_crc_error_flag when register_interface_mode = 0 else
        uart_bank_crc_error_flag;
    crc_error_flag_en <= uart_axi_crc_error_flag_en when register_interface_mode = 0 else
        uart_bank_crc_error_flag_en;

    -- AXI interconnect slave 1: disconnected in register-bank mode.
    s_axi_interconnect_awvalid(1) <= s_axi_uart_awvalid when register_interface_mode = 0 else
    '0';
    s_axi_interconnect_awaddr(1) <= s_axi_uart_awaddr when register_interface_mode = 0 else
    (others => '0');
    s_axi_interconnect_wvalid(1) <= s_axi_uart_wvalid when register_interface_mode = 0 else
    '0';
    s_axi_interconnect_wdata(1) <= s_axi_uart_wdata when register_interface_mode = 0 else
    (others => '0');
    s_axi_interconnect_wstrb(1) <= s_axi_uart_wstrb when register_interface_mode = 0 else
    (others => '0');
    s_axi_interconnect_bready(1) <= s_axi_uart_bready when register_interface_mode = 0 else
    '0';
    s_axi_interconnect_arvalid(1) <= s_axi_uart_arvalid when register_interface_mode = 0 else
    '0';
    s_axi_interconnect_araddr(1) <= s_axi_uart_araddr when register_interface_mode = 0 else
    (others => '0');
    s_axi_interconnect_rready(1) <= s_axi_uart_rready when register_interface_mode = 0 else
    '0';

    s_axi_uart_awready <= s_axi_interconnect_awready(1) when register_interface_mode = 0 else
        '0';
    s_axi_uart_wready <= s_axi_interconnect_wready(1) when register_interface_mode = 0 else
        '0';
    s_axi_uart_bvalid <= s_axi_interconnect_bvalid(1) when register_interface_mode = 0 else
        '0';
    s_axi_uart_bresp <= s_axi_interconnect_bresp(1) when register_interface_mode = 0 else
        (others => '0');
    s_axi_uart_arready <= s_axi_interconnect_arready(1) when register_interface_mode = 0 else
        '0';
    s_axi_uart_rvalid <= s_axi_interconnect_rvalid(1) when register_interface_mode = 0 else
        '0';
    s_axi_uart_rdata <= s_axi_interconnect_rdata(1) when register_interface_mode = 0 else
        (others => '0');
    s_axi_uart_rresp <= s_axi_interconnect_rresp(1) when register_interface_mode = 0 else
        (others => '0');

    -- Register 0: Date
    bank_read_reg(31 downto 0) <= C_DATE_REGISTER_HEX;

    -- Register 1: Time
    bank_read_reg(63 downto 32) <= C_TIME_REGISTER_HEX;

    -- Registers 2 to 127: Write-data readback
    bank_readback_gen : for i in 2 to 127 generate
        bank_read_reg(i*32+31 downto i*32) <=
            bank_write_reg(i*32+31 downto i*32);
    end generate bank_readback_gen;

    uart_axi_lite_bridge_inst : entity work.uart_axi_lite_bridge
        generic map(
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            uart_clock_divider => uart_clock_divider,
            frame_mode         => frame_mode
        )
        port map
        (
            clock              => clock,
            async_reset        => async_reset,
            sync_reset         => sync_reset,
            txd                => uart_axi_txd,
            rxd                => uart_axi_rxd,
            m_axi_awvalid      => s_axi_uart_awvalid,
            m_axi_awready      => s_axi_uart_awready,
            m_axi_awaddr       => s_axi_uart_awaddr,
            m_axi_wvalid       => s_axi_uart_wvalid,
            m_axi_wready       => s_axi_uart_wready,
            m_axi_wdata        => s_axi_uart_wdata,
            m_axi_wstrb        => s_axi_uart_wstrb,
            m_axi_bvalid       => s_axi_uart_bvalid,
            m_axi_bready       => s_axi_uart_bready,
            m_axi_bresp        => s_axi_uart_bresp,
            m_axi_arvalid      => s_axi_uart_arvalid,
            m_axi_arready      => s_axi_uart_arready,
            m_axi_araddr       => s_axi_uart_araddr,
            m_axi_rvalid       => s_axi_uart_rvalid,
            m_axi_rready       => s_axi_uart_rready,
            m_axi_rdata        => s_axi_uart_rdata,
            m_axi_rresp        => s_axi_uart_rresp,
            timeout_error_flag => uart_axi_timeout_error_flag,
            crc_error_flag     => uart_axi_crc_error_flag,
            crc_error_flag_en  => uart_axi_crc_error_flag_en

        );

    uart_bank_bridge_inst : entity work.uart_bank_bridge
        generic map(
            nbreg              => const_nb_bank_registers,
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            uart_clock_divider => uart_clock_divider,
            frame_mode         => frame_mode
        )
        port map
        (
            clock              => clock,
            async_reset        => async_reset,
            sync_reset         => sync_reset,
            txd                => uart_bank_txd,
            rxd                => uart_bank_rxd,
            write_reg          => bank_write_reg,
            write_reg_en       => bank_write_reg_en,
            read_reg           => bank_read_reg,
            timeout_error_flag => uart_bank_timeout_error_flag,
            crc_error_flag     => uart_bank_crc_error_flag,
            crc_error_flag_en  => uart_bank_crc_error_flag_en
        );
    ----------------------------------------------------------------------------------------------------------
    -- System Module
    ----------------------------------------------------------------------------------------------------------
    system_module_inst : entity work.system_module
        generic map(
            clock_frequency    => clock_frequency,
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active
        )
        port map
        (
            clock             => clock,
            async_reset       => async_reset,
            sync_reset        => sync_reset,
            s_axi_awvalid     => m_axi_interconnect_awvalid (const_system_module_slot),
            s_axi_awready     => m_axi_interconnect_awready (const_system_module_slot),
            s_axi_awaddr      => m_axi_interconnect_awaddr (const_system_module_slot),
            s_axi_wvalid      => m_axi_interconnect_wvalid (const_system_module_slot),
            s_axi_wready      => m_axi_interconnect_wready (const_system_module_slot),
            s_axi_wdata       => m_axi_interconnect_wdata (const_system_module_slot),
            s_axi_wstrb       => m_axi_interconnect_wstrb (const_system_module_slot),
            s_axi_bvalid      => m_axi_interconnect_bvalid (const_system_module_slot),
            s_axi_bready      => m_axi_interconnect_bready (const_system_module_slot),
            s_axi_bresp       => m_axi_interconnect_bresp (const_system_module_slot),
            s_axi_arvalid     => m_axi_interconnect_arvalid (const_system_module_slot),
            s_axi_arready     => m_axi_interconnect_arready (const_system_module_slot),
            s_axi_araddr      => m_axi_interconnect_araddr (const_system_module_slot),
            s_axi_rvalid      => m_axi_interconnect_rvalid (const_system_module_slot),
            s_axi_rready      => m_axi_interconnect_rready (const_system_module_slot),
            s_axi_rdata       => m_axi_interconnect_rdata (const_system_module_slot),
            s_axi_rresp       => m_axi_interconnect_rresp (const_system_module_slot),
            soft_reset        => soft_reset,
            crc_error_flag    => crc_error_flag,
            crc_error_flag_en => crc_error_flag_en
        );

    ----------------------------------------------------------------------------------------------------------
    --  Test modules
    ----------------------------------------------------------------------------------------------------------

    loop_testslots_gen : for slot_index in 1 to const_nb_slots - 1 generate

        axi_lite_slave_inst : entity work.axi_lite_slave
            generic map(
                use_async_reset    => use_async_reset,
                use_sync_reset     => use_sync_reset,
                async_reset_active => async_reset_active,
                sync_reset_active  => sync_reset_active,
                nb_registers       => 32
            )
            port map
            (
                clock             => clock,
                async_reset       => async_reset,
                sync_reset        => sync_reset,
                s_axi_awvalid     => m_axi_interconnect_awvalid (SLOT_INDEX),
                s_axi_awready     => m_axi_interconnect_awready (SLOT_INDEX),
                s_axi_awaddr      => m_axi_interconnect_awaddr (SLOT_INDEX),
                s_axi_wvalid      => m_axi_interconnect_wvalid (SLOT_INDEX),
                s_axi_wready      => m_axi_interconnect_wready (SLOT_INDEX),
                s_axi_wdata       => m_axi_interconnect_wdata (SLOT_INDEX),
                s_axi_wstrb       => m_axi_interconnect_wstrb (SLOT_INDEX),
                s_axi_bvalid      => m_axi_interconnect_bvalid (SLOT_INDEX),
                s_axi_bready      => m_axi_interconnect_bready (SLOT_INDEX),
                s_axi_bresp       => m_axi_interconnect_bresp (SLOT_INDEX),
                s_axi_arvalid     => m_axi_interconnect_arvalid (SLOT_INDEX),
                s_axi_arready     => m_axi_interconnect_arready (SLOT_INDEX),
                s_axi_araddr      => m_axi_interconnect_araddr (SLOT_INDEX),
                s_axi_rvalid      => m_axi_interconnect_rvalid (SLOT_INDEX),
                s_axi_rready      => m_axi_interconnect_rready (SLOT_INDEX),
                s_axi_rdata       => m_axi_interconnect_rdata (SLOT_INDEX),
                s_axi_rresp       => m_axi_interconnect_rresp (SLOT_INDEX),
                register_write    => test_register_write(SLOT_INDEX),
                register_write_en => test_register_write_en(SLOT_INDEX),
                register_read     => test_register_read(SLOT_INDEX)

            );

    end generate loop_testslots_gen;

    loop_testreg_gen : for i in 1 to const_nb_reg_per_slot - 1 generate
        test_register_read(I) <= test_register_write(I);
    end generate loop_testreg_gen;

end architecture rtl;
