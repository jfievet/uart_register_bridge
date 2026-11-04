library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
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

    signal crc_error_flag    : std_logic;
    signal crc_error_flag_en : std_logic;

    -- signal test_register_write                  : register_array_type;
    -- signal test_register_write_en               : std_logic_vector(32 - 1 downto 0 );
    -- signal test_register_read                   : register_array_type;

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


    -- Register 0: Date
    bank_read_reg(31 downto 0) <= C_DATE_REGISTER_HEX;

    -- Register 1: Time
    bank_read_reg(63 downto 32) <= C_TIME_REGISTER_HEX;

    -- Registers 2 to const_nb_bank_registers-1: Write-data readback
    bank_readback_gen : for i in 2 to const_nb_bank_registers-1 generate
        bank_read_reg(i*32+31 downto i*32) <=
            bank_write_reg(i*32+31 downto i*32);
    end generate bank_readback_gen;

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
 
end architecture rtl;
