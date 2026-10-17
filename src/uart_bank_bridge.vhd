
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_bank_bridge is
    generic (
        nbreg              : positive              := 128;
        use_async_reset    : boolean               := TRUE;
        use_sync_reset     : boolean               := TRUE;
        async_reset_active : std_logic             := '1';
        sync_reset_active  : std_logic             := '1';
        uart_clock_divider : integer               := 108;
        frame_mode         : integer               := 0;
        timeout_pulses     : unsigned(23 downto 0) := to_unsigned(1_500_000, 24);
        allow_bad_crc      : integer               := 0
    );
    port (
        clock       : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;

        txd : out std_logic;
        rxd : in std_logic;

        write_reg    : out std_logic_vector(nbreg * 32 - 1 downto 0);
        write_reg_en : out std_logic_vector(nbreg - 1 downto 0);
        read_reg     : in std_logic_vector(nbreg * 32 - 1 downto 0);

        crc_error_flag     : out std_logic;
        crc_error_flag_en  : out std_logic;
        timeout_error_flag : out std_logic
    );
end entity uart_bank_bridge;

architecture rtl of uart_bank_bridge is

    -- AXI-Stream TX (Slave side)
    signal uart_s_axis_tdata  : std_logic_vector(7 downto 0);
    signal uart_s_axis_tvalid : std_logic;
    signal uart_s_axis_tready : std_logic;

    -- AXI-Stream RX (Master side)
    signal uart_m_axis_tdata  : std_logic_vector(7 downto 0);
    signal uart_m_axis_tvalid : std_logic;
    signal uart_m_axis_tready : std_logic;

    -- UART pins
    signal uart_tx_en : std_logic;
    signal uart_txd   : std_logic;
    signal uart_rxd   : std_logic;

    -- AXI-Stream TLAST
    signal bank_s_axis_tlast : std_logic;
    signal bank_m_axis_tlast : std_logic;

begin

    --------------------------------------------------------------
    -- UART (TX and RX)
    --------------------------------------------------------------
    uart_inst : entity work.uart
        generic map(
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            uart_clock_divider => uart_clock_divider
        )
        port map
        (
            clock       => clock,
            async_reset => async_reset,
            sync_reset  => sync_reset,

            s_axis_tdata  => uart_s_axis_tdata,
            s_axis_tvalid => uart_s_axis_tvalid,
            s_axis_tready => uart_s_axis_tready,

            m_axis_tdata  => uart_m_axis_tdata,
            m_axis_tvalid => uart_m_axis_tvalid,
            m_axis_tready => uart_m_axis_tready,

            tx_en => uart_tx_en,
            txd   => uart_txd,
            rxd   => uart_rxd
        );

    txd      <= uart_txd;
    uart_rxd <= rxd;

    --------------------------------------------------------------
    -- RX FIFO (placeholder)
    --------------------------------------------------------------

    --------------------------------------------------------------
    -- TX FIFO (placeholder)
    --------------------------------------------------------------

    --------------------------------------------------------------
    -- Register Bank End Bridge
    --------------------------------------------------------------
    bank_end_bridge_inst : entity work.bank_end_bridge
        generic map(
            nbreg              => nbreg,
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            frame_mode         => frame_mode,
            timeout_pulses     => timeout_pulses,
            allow_bad_crc      => allow_bad_crc
        )
        port map
        (
            clock       => clock,
            async_reset => async_reset,
            sync_reset  => sync_reset,

            write_reg    => write_reg,
            write_reg_en => write_reg_en,
            read_reg     => read_reg,

            s_axis_tdata  => uart_m_axis_tdata,
            s_axis_tvalid => uart_m_axis_tvalid,
            s_axis_tready => uart_m_axis_tready,
            s_axis_tlast  => bank_s_axis_tlast,

            m_axis_tdata  => uart_s_axis_tdata,
            m_axis_tvalid => uart_s_axis_tvalid,
            m_axis_tready => uart_s_axis_tready,
            m_axis_tlast  => bank_m_axis_tlast,

            crc_error_flag     => crc_error_flag,
            crc_error_flag_en  => crc_error_flag_en,
            timeout_error_flag => timeout_error_flag
        );

    --------------------------------------------------------------
    -- AXI-Stream TLAST handling
    --------------------------------------------------------------
    bank_s_axis_tlast <= '0';

end architecture rtl;
