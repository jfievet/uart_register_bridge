library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_axi_lite_bridge is
    generic (
        use_async_reset    : boolean   := TRUE;
        use_sync_reset     : boolean   := TRUE;
        async_reset_active : std_logic := '1';
        sync_reset_active  : std_logic := '1';
        uart_clock_divider : integer   := 108; -- round(clock / uart_bitrate*8)  ie. for 100e6/115200/8=108
        frame_mode         : integer   := 0 -- 0: Extended uart (14 bytes) 1:Compact
    );
    port (
        clock       : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;

        txd : out std_logic;
        rxd : in std_logic;

        m_axi_awvalid : out std_logic;
        m_axi_awready : in std_logic;
        m_axi_awaddr  : out std_logic_vector(31 downto 0);
        m_axi_wvalid  : out std_logic;
        m_axi_wready  : in std_logic;
        m_axi_wdata   : out std_logic_vector(31 downto 0);
        m_axi_wstrb   : out std_logic_vector(3 downto 0);
        m_axi_bvalid  : in std_logic;
        m_axi_bready  : out std_logic;
        m_axi_bresp   : in std_logic_vector(1 downto 0);
        m_axi_arvalid : out std_logic;
        m_axi_arready : in std_logic;
        m_axi_araddr  : out std_logic_vector(31 downto 0);
        m_axi_rvalid  : in std_logic;
        m_axi_rready  : out std_logic;
        m_axi_rdata   : in std_logic_vector(31 downto 0);
        m_axi_rresp   : in std_logic_vector(1 downto 0);

        crc_error_flag     : out std_logic;
        crc_error_flag_en  : out std_logic;
        timeout_error_flag : out std_logic
    );
end entity uart_axi_lite_bridge;

architecture rtl of uart_axi_lite_bridge is

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

    -- AXI-Lite bridge internal signals
    signal axil_m_axi_awvalid : std_logic;
    signal axil_m_axi_awready : std_logic;
    signal axil_m_axi_awaddr  : std_logic_vector(31 downto 0);
    signal axil_m_axi_wvalid  : std_logic;
    signal axil_m_axi_wready  : std_logic;
    signal axil_m_axi_wdata   : std_logic_vector(31 downto 0);
    signal axil_m_axi_wstrb   : std_logic_vector(3 downto 0);
    signal axil_m_axi_bvalid  : std_logic;
    signal axil_m_axi_bready  : std_logic;
    signal axil_m_axi_bresp   : std_logic_vector(1 downto 0);
    signal axil_m_axi_arvalid : std_logic;
    signal axil_m_axi_arready : std_logic;
    signal axil_m_axi_araddr  : std_logic_vector(31 downto 0);
    signal axil_m_axi_rvalid  : std_logic;
    signal axil_m_axi_rready  : std_logic;
    signal axil_m_axi_rdata   : std_logic_vector(31 downto 0);
    signal axil_m_axi_rresp   : std_logic_vector(1 downto 0);
    signal axil_s_axis_tlast  : std_logic;
    signal axil_m_axis_tlast  : std_logic;

begin

    --------------------------------------------------------------
    -- UART (tx and rx)
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
    -- RX fifo (placeholder)
    --------------------------------------------------------------

    --------------------------------------------------------------
    -- TX fifo (placeholder)
    --------------------------------------------------------------

    --------------------------------------------------------------
    -- AXI-L end bridge
    --------------------------------------------------------------
    axil_end_bridge_inst : entity work.axil_end_bridge
        generic map(
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            frame_mode         => frame_mode
        )
        port map
        (
            clock       => clock,
            async_reset => async_reset,
            sync_reset  => sync_reset,

            m_axi_awvalid => axil_m_axi_awvalid,
            m_axi_awready => axil_m_axi_awready,
            m_axi_awaddr  => axil_m_axi_awaddr,

            m_axi_wvalid => axil_m_axi_wvalid,
            m_axi_wready => axil_m_axi_wready,
            m_axi_wdata  => axil_m_axi_wdata,
            m_axi_wstrb  => axil_m_axi_wstrb,

            m_axi_bvalid => axil_m_axi_bvalid,
            m_axi_bready => axil_m_axi_bready,
            m_axi_bresp  => axil_m_axi_bresp,

            m_axi_arvalid => axil_m_axi_arvalid,
            m_axi_arready => axil_m_axi_arready,
            m_axi_araddr  => axil_m_axi_araddr,

            m_axi_rvalid => axil_m_axi_rvalid,
            m_axi_rready => axil_m_axi_rready,
            m_axi_rdata  => axil_m_axi_rdata,
            m_axi_rresp  => axil_m_axi_rresp,

            s_axis_tdata  => uart_m_axis_tdata,
            s_axis_tvalid => uart_m_axis_tvalid,
            s_axis_tready => uart_m_axis_tready,
            s_axis_tlast  => axil_s_axis_tlast,

            m_axis_tdata  => uart_s_axis_tdata,
            m_axis_tvalid => uart_s_axis_tvalid,
            m_axis_tready => uart_s_axis_tready,
            m_axis_tlast  => axil_m_axis_tlast,

            crc_error_flag     => crc_error_flag,
            crc_error_flag_en  => crc_error_flag_en,
            timeout_error_flag => timeout_error_flag
        );

    --------------------------------------------------------------
    -- Connect internal AXI-Lite bridge signals to entity ports
    --------------------------------------------------------------

    m_axi_awvalid      <= axil_m_axi_awvalid;
    axil_m_axi_awready <= m_axi_awready;
    m_axi_awaddr       <= axil_m_axi_awaddr;

    m_axi_wvalid      <= axil_m_axi_wvalid;
    axil_m_axi_wready <= m_axi_wready;
    m_axi_wdata       <= axil_m_axi_wdata;
    m_axi_wstrb       <= axil_m_axi_wstrb;

    axil_m_axi_bvalid <= m_axi_bvalid;
    m_axi_bready      <= axil_m_axi_bready;
    axil_m_axi_bresp  <= m_axi_bresp;

    m_axi_arvalid      <= axil_m_axi_arvalid;
    axil_m_axi_arready <= m_axi_arready;
    m_axi_araddr       <= axil_m_axi_araddr;

    axil_m_axi_rvalid <= m_axi_rvalid;
    m_axi_rready      <= axil_m_axi_rready;
    axil_m_axi_rdata  <= m_axi_rdata;
    axil_m_axi_rresp  <= m_axi_rresp;

    --------------------------------------------------------------
    -- AXI-Stream tlast handling
    --------------------------------------------------------------
    axil_s_axis_tlast <= '0';

end architecture rtl;
