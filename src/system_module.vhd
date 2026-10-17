library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi_lite_slave_pkg.all;
use work.timestamp_pkg.all;
use work.version_pkg.all;

entity system_module is
    generic (
        clock_frequency    : natural   := 100_000_000;
        use_async_reset    : boolean   := TRUE;
        use_sync_reset     : boolean   := TRUE;
        async_reset_active : std_logic := '1';
        sync_reset_active  : std_logic := '1'
    );
    port (
        clock       : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;

        s_axi_awvalid : in std_logic;
        s_axi_awready : out std_logic;
        s_axi_awaddr  : in std_logic_vector(31 downto 0);
        s_axi_wvalid  : in std_logic;
        s_axi_wready  : out std_logic;
        s_axi_wdata   : in std_logic_vector(31 downto 0);
        s_axi_wstrb   : in std_logic_vector(3 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_arvalid : in std_logic;
        s_axi_arready : out std_logic;
        s_axi_araddr  : in std_logic_vector(31 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in std_logic;
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);

        soft_reset        : out std_logic;
        crc_error_flag    : in std_logic;
        crc_error_flag_en : in std_logic
    );
end entity system_module;

architecture rtl of system_module is

    -- Registers definition
    constant const_version_reg0             : integer := 0;
    constant const_time_build_reg1          : integer := 1;
    constant const_time_buil_reg2           : integer := 2;
    constant const_enlapsed_time_sec_reg3   : integer := 3;
    constant const_enlapsed_time_pulse_reg4 : integer := 4;
    constant const_soft_reset_reg5          : integer := 5;
    constant const_crc_ok_reg6              : integer := 6;
    constant const_crc_nok_reg7             : integer := 7;

    -- Registers signals
    signal register_write    : register_array_type;
    signal register_write_en : std_logic_vector(register_array - 1 downto 0);
    signal register_read     : register_array_type;

    -- Counter signals
    signal counter_clk     : unsigned(31 downto 0);
    signal counter_1sec    : unsigned(31 downto 0);
    signal counter_crc_ok  : unsigned(31 downto 0);
    signal counter_crc_nok : unsigned(31 downto 0);

begin

    ----------------------------------------------------------------------------------------------------------
    -- Main process
    ----------------------------------------------------------------------------------------------------------

    main_pr : process (clock, async_reset) is
    begin

        if ((async_reset = async_reset_active) and (use_async_reset = true)) then
            counter_clk     <= to_unsigned(clock_frequency, 32);
            counter_1sec    <= (others => '0');
            counter_crc_ok  <= (others => '0');
            counter_crc_nok <= (others => '0');
        elsif rising_edge(clock) then
            if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
                counter_clk     <= to_unsigned(clock_frequency, 32);
                counter_1sec    <= (others => '0');
                counter_crc_ok  <= (others => '0');
                counter_crc_nok <= (others => '0');
            else
                -- Counter going from CLOCK_FREQUENCY to 0
                if (counter_clk = to_unsigned(0, 32)) then
                    counter_clk <= to_unsigned(clock_frequency, 32);
                else
                    counter_clk <= counter_clk - 1;
                end if;

                -- One sec counter
                if (counter_clk = to_unsigned(0, 32)) then
                    counter_1sec <= counter_1sec + 1;
                end if;

                -- CRC counters
                if (crc_error_flag_en = '1' and crc_error_flag = '1') then
                    counter_crc_nok <= counter_crc_nok + 1;
                end if;
                if (crc_error_flag_en = '1' and crc_error_flag = '0') then
                    counter_crc_ok <= counter_crc_ok + 1;
                end if;
            end if;
        end if;

    end process main_pr;

    ----------------------------------------------------------------------------------------------------------
    -- Registers
    ----------------------------------------------------------------------------------------------------------

    axi_lite_slave_inst : entity work.axi_lite_slave
        generic map(
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            nb_registers       => register_array
        )
        port map
        (
            clock             => clock,
            async_reset       => async_reset,
            sync_reset        => sync_reset,
            s_axi_awvalid     => s_axi_awvalid,
            s_axi_awready     => s_axi_awready,
            s_axi_awaddr      => s_axi_awaddr,
            s_axi_wvalid      => s_axi_wvalid,
            s_axi_wready      => s_axi_wready,
            s_axi_wdata       => s_axi_wdata,
            s_axi_wstrb       => s_axi_wstrb,
            s_axi_bvalid      => s_axi_bvalid,
            s_axi_bready      => s_axi_bready,
            s_axi_bresp       => s_axi_bresp,
            s_axi_arvalid     => s_axi_arvalid,
            s_axi_arready     => s_axi_arready,
            s_axi_araddr      => s_axi_araddr,
            s_axi_rvalid      => s_axi_rvalid,
            s_axi_rready      => s_axi_rready,
            s_axi_rdata       => s_axi_rdata,
            s_axi_rresp       => s_axi_rresp,
            register_write    => register_write,
            register_write_en => register_write_en,
            register_read     => register_read
        );

    --------------------------------------
    -- READ Registers
    --------------------------------------

    -- Version
    register_read(const_Version_reg0) <= MAJOR & MINOR & PATCH & BUILD;

    -- Time build 1
    register_read(const_Time_build_reg1) <= C_DATE_REGISTER_HEX;

    -- Time build 2
    register_read(const_Time_buil_reg2) <= C_TIME_REGISTER_HEX;

    -- Enlapsed time sec
    register_read(const_Enlapsed_time_sec_reg3) <= std_logic_vector(counter_1sec);

    -- Enlapsed time sec
    register_read(const_Enlapsed_time_pulse_reg4) <= std_logic_vector(counter_clk);

    -- CRC ok counter
    register_read(const_crc_ok_reg6) <= std_logic_vector(counter_crc_ok);

    -- CRC not ok counter
    register_read(const_crc_nok_reg7) <= std_logic_vector(counter_crc_nok);

    --------------------------------------
    -- Write Registers
    --------------------------------------
    soft_reset <= register_write_en(const_soft_reset_reg5);

end architecture rtl;
