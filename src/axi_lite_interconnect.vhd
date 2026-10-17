library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi_lite_interconnect_pkg.all;

entity axi_lite_interconnect is
    generic (
        use_async_reset    : boolean   := TRUE;
        use_sync_reset     : boolean   := TRUE;
        async_reset_active : std_logic := '1';
        sync_reset_active  : std_logic := '1';
        nb_slave_ports     : integer   := 32;
        nb_master_ports    : integer   := 32;
        addr_start         : axi_32b_bus_type;
        addr_end           : axi_32b_bus_type;
        addr_offset        : axi_32b_bus_type
    );
    port (
        clock       : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;

        s_axi_awvalid : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_awready : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_awaddr  : in axi_32b_bus_type;
        s_axi_wvalid  : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_wready  : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_wdata   : in axi_32b_bus_type;
        s_axi_wstrb   : in axi_4b_bus_type;
        s_axi_bvalid  : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_bready  : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_bresp   : out axi_2b_bus_type;
        s_axi_arvalid : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_arready : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_araddr  : in axi_32b_bus_type;
        s_axi_rvalid  : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_rready  : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        s_axi_rdata   : out axi_32b_bus_type;
        s_axi_rresp   : out axi_2b_bus_type;

        m_axi_awvalid : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_awready : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_awaddr  : out axi_32b_bus_type;
        m_axi_wvalid  : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_wready  : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_wdata   : out axi_32b_bus_type;
        m_axi_wstrb   : out axi_4b_bus_type;
        m_axi_bvalid  : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_bready  : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_bresp   : in axi_2b_bus_type;
        m_axi_arvalid : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_arready : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_araddr  : out axi_32b_bus_type;
        m_axi_rvalid  : in std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_rready  : out std_logic_vector(nb_axi_lite_array - 1 downto 0);
        m_axi_rdata   : in axi_32b_bus_type;
        m_axi_rresp   : in axi_2b_bus_type
    );
end entity axi_lite_interconnect;

architecture rtl of axi_lite_interconnect is

    -- intermediate signals
    signal s_axi_awvalid_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_awready_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_awaddr_i  : axi_32b_bus_type;
    signal s_axi_wvalid_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_wready_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_wdata_i   : axi_32b_bus_type;
    signal s_axi_wstrb_i   : axi_4b_bus_type;
    signal s_axi_bvalid_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_bready_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_bresp_i   : axi_2b_bus_type;
    signal s_axi_arvalid_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_arready_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_araddr_i  : axi_32b_bus_type;
    signal s_axi_rvalid_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_rready_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal s_axi_rdata_i   : axi_32b_bus_type;
    signal s_axi_rresp_i   : axi_2b_bus_type;
    signal m_axi_awvalid_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_awready_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_awaddr_i  : axi_32b_bus_type;
    signal m_axi_wvalid_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_wready_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_wdata_i   : axi_32b_bus_type;
    signal m_axi_wstrb_i   : axi_4b_bus_type;
    signal m_axi_bvalid_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_bready_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_bresp_i   : axi_2b_bus_type;
    signal m_axi_arvalid_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_arready_i : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_araddr_i  : axi_32b_bus_type;
    signal m_axi_rvalid_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_rready_i  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal m_axi_rdata_i   : axi_32b_bus_type;
    signal m_axi_rresp_i   : axi_2b_bus_type;

    type schedule_sm_type is (idle, processing);

    signal schedule_sm    : schedule_sm_type                                 := idle;
    signal schedule_srl   : std_logic_vector(nb_axi_lite_array - 1 downto 0) := std_logic_vector(to_unsigned(1, nb_axi_lite_array));
    signal schedule_index : unsigned(15 downto 0);

    signal s_axi_awaddr_stored : std_logic_vector(31 downto 0);
    signal s_axi_wdata_stored  : std_logic_vector(31 downto 0);
    signal s_axi_araddr_stored : std_logic_vector(31 downto 0);

    signal front_axi_awvalid : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_awready : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_awaddr  : std_logic_vector(31 downto 0); -- axi_32b_bus_type;
    signal front_axi_wvalid  : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_wready  : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_wdata   : std_logic_vector(31 downto 0); -- axi_32b_bus_type;
    signal front_axi_wstrb   : std_logic_vector(3 downto 0); -- axi_4b_bus_type;
    signal front_axi_bvalid  : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_bready  : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_bresp   : std_logic_vector(1 downto 0); -- axi_2b_bus_type;
    signal front_axi_arvalid : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_arready : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_araddr  : std_logic_vector(31 downto 0); -- axi_32b_bus_type;
    signal front_axi_rvalid  : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_rready  : std_logic; -- std_logic_vector(nb_axi_lite_array-1 downto 0);
    signal front_axi_rdata   : std_logic_vector(31 downto 0); -- axi_32b_bus_type;
    signal front_axi_rresp   : std_logic_vector(1 downto 0); -- axi_2b_bus_type;

    signal intermediate_axi_awvalid : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_awready : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_awaddr  : axi_32b_bus_type;
    signal intermediate_axi_wvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_wready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_wdata   : axi_32b_bus_type;
    signal intermediate_axi_wstrb   : axi_4b_bus_type;
    signal intermediate_axi_bvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_bready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_bresp   : axi_2b_bus_type;
    signal intermediate_axi_arvalid : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_arready : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_araddr  : axi_32b_bus_type;
    signal intermediate_axi_rvalid  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_rready  : std_logic_vector(nb_axi_lite_array - 1 downto 0);
    signal intermediate_axi_rdata   : axi_32b_bus_type;
    signal intermediate_axi_rresp   : axi_2b_bus_type;

begin

    -- assign intermediate signals
    m_axi_awready_i <= m_axi_awready;
    m_axi_wready_i  <= m_axi_wready;
    m_axi_bvalid_i  <= m_axi_bvalid;
    m_axi_bresp_i   <= m_axi_bresp;
    m_axi_arready_i <= m_axi_arready;
    m_axi_rvalid_i  <= m_axi_rvalid;
    m_axi_rdata_i   <= m_axi_rdata;
    m_axi_rresp_i   <= m_axi_rresp;
    s_axi_awvalid_i <= s_axi_awvalid;
    s_axi_awaddr_i  <= s_axi_awaddr;
    s_axi_wvalid_i  <= s_axi_wvalid;
    s_axi_wdata_i   <= s_axi_wdata;
    s_axi_wstrb_i   <= s_axi_wstrb;
    s_axi_bready_i  <= s_axi_bready;
    s_axi_arvalid_i <= s_axi_arvalid;
    s_axi_araddr_i  <= s_axi_araddr;
    s_axi_rready_i  <= s_axi_rready;

    -- m_axi_awvalid <= m_axi_awvalid_i;
    -- m_axi_awaddr  <= m_axi_awaddr_i;
    -- m_axi_wvalid  <= m_axi_wvalid_i;
    -- m_axi_wdata   <= m_axi_wdata_i;
    -- m_axi_wstrb   <= m_axi_wstrb_i;
    -- m_axi_bready  <= m_axi_bready_i;
    -- m_axi_arvalid <= m_axi_arvalid_i;
    -- m_axi_araddr  <= m_axi_araddr_i;
    -- m_axi_rready  <= m_axi_rready_i;
    s_axi_awready <= s_axi_awready_i;
    s_axi_wready  <= s_axi_wready_i;
    s_axi_bvalid  <= s_axi_bvalid_i;
    s_axi_bresp   <= s_axi_bresp_i;
    s_axi_arready <= s_axi_arready_i;
    s_axi_rvalid  <= s_axi_rvalid_i;
    s_axi_rdata   <= s_axi_rdata_i;
    s_axi_rresp   <= s_axi_rresp_i;

    -- Process to handle scheduling of input slaves
    scheduling_pr : process (clock, async_reset) is
    begin

        if ((async_reset = async_reset_active) and (use_async_reset = true)) then
            s_axi_bvalid_i      <= (others => '0');
            s_axi_bresp_i       <= (others => (others => '0'));
            s_axi_rvalid_i      <= (others => '0');
            s_axi_rdata_i       <= (others => (others => '0'));
            s_axi_rresp_i       <= (others => (others => '0'));
            schedule_srl        <= std_logic_vector(to_unsigned(1, nb_axi_lite_array));
            s_axi_awaddr_stored <= (others => '0');
            s_axi_wdata_stored  <= (others => '0');
            s_axi_araddr_stored <= (others => '0');
            schedule_index      <= (others => '0');
            front_axi_awvalid   <= '0';
            front_axi_awaddr    <= (others => '0');
            front_axi_wvalid    <= '0';
            front_axi_wdata     <= (others => '0');
            front_axi_wstrb     <= (others => '0');
            front_axi_bready    <= '0';
            front_axi_arvalid   <= '0';
            front_axi_araddr    <= (others => '0');
            front_axi_rready    <= '0';
        elsif rising_edge(clock) then
            if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
                s_axi_bvalid_i      <= (others => '0');
                s_axi_bresp_i       <= (others => (others => '0'));
                s_axi_rvalid_i      <= (others => '0');
                s_axi_rdata_i       <= (others => (others => '0'));
                s_axi_rresp_i       <= (others => (others => '0'));
                schedule_srl        <= std_logic_vector(to_unsigned(1, nb_axi_lite_array));
                s_axi_awaddr_stored <= (others => '0');
                s_axi_wdata_stored  <= (others => '0');
                s_axi_araddr_stored <= (others => '0');
                schedule_index      <= (others => '0');
                front_axi_awvalid   <= '0';
                front_axi_awaddr    <= (others => '0');
                front_axi_wvalid    <= '0';
                front_axi_wdata     <= (others => '0');
                front_axi_wstrb     <= (others => '0');
                front_axi_bready    <= '0';
                front_axi_arvalid   <= '0';
                front_axi_araddr    <= (others => '0');
                front_axi_rready    <= '0';
            else

                for k in 0 to nb_slave_ports - 1 loop

                    s_axi_rdata_i(k) <= front_axi_rdata;

                end loop;

                case schedule_sm is

                    when idle =>

                        schedule_srl(nb_slave_ports - 1 downto 1) <= schedule_srl(nb_slave_ports - 2 downto 0);
                        schedule_srl(0)                           <= schedule_srl(nb_slave_ports - 1);

                        -- Write request
                        for k in 0 to nb_slave_ports - 1 loop

                            -- Both at the same time
                            if (s_axi_awvalid_i(k) = '1' and s_axi_awready_i(k) = '1' and s_axi_wvalid_i(k) = '1' and s_axi_wready_i(k) = '1') then
                                s_axi_awaddr_stored <= s_axi_awaddr_i(k);
                                s_axi_wdata_stored  <= s_axi_wdata_i(k);
                                schedule_sm         <= processing;
                                schedule_index      <= to_unsigned(k, 16);
                                front_axi_awvalid   <= '1';
                                front_axi_awaddr    <= s_axi_awaddr_i(k);
                                front_axi_wvalid    <= '1';
                                front_axi_wdata     <= s_axi_wdata_i(k);
                                front_axi_wstrb     <= s_axi_wstrb_i(k);
                                -- Write only detect
                            elsif (s_axi_wvalid_i(k) = '1' and s_axi_wready_i(k) = '1') then
                                s_axi_wdata_stored <= s_axi_wdata_i(k);
                                schedule_sm        <= processing;
                                schedule_index     <= to_unsigned(k, 16);
                                front_axi_awvalid  <= '1';
                                front_axi_awaddr   <= s_axi_awaddr_stored;
                                front_axi_wvalid   <= '1';
                                front_axi_wdata    <= s_axi_wdata_i(k);
                                front_axi_wstrb    <= s_axi_wstrb_i(k);
                                -- Store address only detect
                            elsif (s_axi_awvalid_i(k) = '1' and s_axi_awready_i(k) = '1') then
                                s_axi_awaddr_stored <= s_axi_awaddr_i(k);
                                -- schedule_sm <= PROCESSING;
                            end if;

                        end loop;

                        -- Read request
                        for k in 0 to nb_slave_ports - 1 loop

                            if (s_axi_arvalid_i(k) = '1' and s_axi_arready_i(k) = '1') then
                                s_axi_araddr_stored <= s_axi_araddr_i(k);
                                front_axi_arvalid   <= '1';
                                front_axi_araddr    <= s_axi_araddr_i(k);
                                front_axi_rready    <= '1';
                                schedule_index      <= to_unsigned(k, 16);
                                schedule_sm         <= processing;
                            end if;

                        end loop;

                    when processing =>

                        -- write ack
                        if (front_axi_awvalid = '1' and front_axi_awready = '1') then
                            front_axi_awvalid <= '0';
                        end if;
                        if (front_axi_wvalid = '1' and front_axi_wready = '1') then
                            front_axi_wvalid <= '0';
                        end if;
                        if (front_axi_bvalid = '1' and front_axi_bready = '1') then
                            front_axi_bready                           <= '0';
                            s_axi_bvalid_i(to_integer(schedule_index)) <= '1';
                        else
                            front_axi_bready <= '1';
                        end if;

                        for k in 0 to nb_slave_ports - 1 loop

                            if (s_axi_bvalid_i(k) = '1' and s_axi_bready_i(k) = '1') then
                                s_axi_bvalid_i(k) <= '0';
                                schedule_sm       <= idle;
                            end if;

                        end loop;

                        -- read ack
                        if (front_axi_arvalid = '1' and front_axi_arready = '1') then
                            front_axi_arvalid <= '0';
                        end if;
                        if (front_axi_rvalid = '1' and front_axi_rready = '1') then
                            front_axi_rready <= '0';

                            for k in 0 to nb_slave_ports - 1 loop

                                s_axi_rvalid_i(to_integer(schedule_index)) <= '1';

                            end loop;

                        end if;

                        for k in 0 to nb_slave_ports - 1 loop

                            if (s_axi_rvalid_i(k) = '1' and s_axi_rready_i(k) = '1') then
                                s_axi_rvalid_i(k) <= '0';
                                schedule_sm       <= idle;
                            end if;

                        end loop;

                    when others =>

                end case;

            end if;
        end if;

    end process scheduling_pr;

    s_axi_awready_i <= schedule_srl when schedule_sm = idle else
        (others => '0');
    s_axi_wready_i <= schedule_srl when schedule_sm = idle else
        (others => '0');
    s_axi_arready_i <= schedule_srl when schedule_sm = idle else
        (others => '0');

    axi_interconnect_single_first_inst : entity work.axi_interconnect_single
        generic map(
            use_async_reset    => use_async_reset,
            use_sync_reset     => use_sync_reset,
            async_reset_active => async_reset_active,
            sync_reset_active  => sync_reset_active,
            addr_start         => addr_start(0),
            addr_end           => addr_end(0),
            addr_offset        => addr_start(0)
        )
        port map
        (
            clock           => clock,
            async_reset     => async_reset,
            sync_reset      => sync_reset,
            s_axi_awvalid   => front_axi_awvalid,
            s_axi_awready   => front_axi_awready,
            s_axi_awaddr    => front_axi_awaddr,
            s_axi_wvalid    => front_axi_wvalid,
            s_axi_wready    => front_axi_wready,
            s_axi_wdata     => front_axi_wdata,
            s_axi_wstrb     => front_axi_wstrb,
            s_axi_bvalid    => front_axi_bvalid,
            s_axi_bready    => front_axi_bready,
            s_axi_bresp     => front_axi_bresp,
            s_axi_arvalid   => front_axi_arvalid,
            s_axi_arready   => front_axi_arready,
            s_axi_araddr    => front_axi_araddr,
            s_axi_rvalid    => front_axi_rvalid,
            s_axi_rready    => front_axi_rready,
            s_axi_rdata     => front_axi_rdata,
            s_axi_rresp     => front_axi_rresp,
            m_a_axi_awvalid => m_axi_awvalid(0),
            m_a_axi_awready => m_axi_awready(0),
            m_a_axi_awaddr  => m_axi_awaddr(0),
            m_a_axi_wvalid  => m_axi_wvalid(0),
            m_a_axi_wready  => m_axi_wready(0),
            m_a_axi_wdata   => m_axi_wdata(0),
            m_a_axi_wstrb   => m_axi_wstrb(0),
            m_a_axi_bvalid  => m_axi_bvalid(0),
            m_a_axi_bready  => m_axi_bready(0),
            m_a_axi_bresp   => m_axi_bresp(0),
            m_a_axi_arvalid => m_axi_arvalid(0),
            m_a_axi_arready => m_axi_arready(0),
            m_a_axi_araddr  => m_axi_araddr(0),
            m_a_axi_rvalid  => m_axi_rvalid(0),
            m_a_axi_rready  => m_axi_rready(0),
            m_a_axi_rdata   => m_axi_rdata(0),
            m_a_axi_rresp   => m_axi_rresp(0),
            m_b_axi_awvalid => intermediate_axi_awvalid(0),
            m_b_axi_awready => intermediate_axi_awready(0),
            m_b_axi_awaddr  => intermediate_axi_awaddr(0),
            m_b_axi_wvalid  => intermediate_axi_wvalid(0),
            m_b_axi_wready  => intermediate_axi_wready(0),
            m_b_axi_wdata   => intermediate_axi_wdata(0),
            m_b_axi_wstrb   => intermediate_axi_wstrb(0),
            m_b_axi_bvalid  => intermediate_axi_bvalid(0),
            m_b_axi_bready  => intermediate_axi_bready(0),
            m_b_axi_bresp   => intermediate_axi_bresp(0),
            m_b_axi_arvalid => intermediate_axi_arvalid(0),
            m_b_axi_arready => intermediate_axi_arready(0),
            m_b_axi_araddr  => intermediate_axi_araddr(0),
            m_b_axi_rvalid  => intermediate_axi_rvalid(0),
            m_b_axi_rready  => intermediate_axi_rready(0),
            m_b_axi_rdata   => intermediate_axi_rdata(0),
            m_b_axi_rresp   => intermediate_axi_rresp(0)
        );

    interconnect_loop_1_to_end_gen : for k in 1 to NB_MASTER_PORTS - 1 generate

        axi_interconnect_single_1_to_end_inst : entity work.axi_interconnect_single
            generic map(
                use_async_reset    => use_async_reset,
                use_sync_reset     => use_sync_reset,
                async_reset_active => async_reset_active,
                sync_reset_active  => sync_reset_active,
                addr_start         => addr_start(k),
                addr_end           => addr_end(k),
                addr_offset        => addr_start(k)
            )
            port map
            (
                clock           => clock,
                async_reset     => async_reset,
                sync_reset      => sync_reset,
                s_axi_awvalid   => intermediate_axi_awvalid(k - 1),
                s_axi_awready   => intermediate_axi_awready(k - 1),
                s_axi_awaddr    => intermediate_axi_awaddr(k - 1),
                s_axi_wvalid    => intermediate_axi_wvalid(k - 1),
                s_axi_wready    => intermediate_axi_wready(k - 1),
                s_axi_wdata     => intermediate_axi_wdata(k - 1),
                s_axi_wstrb     => intermediate_axi_wstrb(k - 1),
                s_axi_bvalid    => intermediate_axi_bvalid(k - 1),
                s_axi_bready    => intermediate_axi_bready(k - 1),
                s_axi_bresp     => intermediate_axi_bresp(k - 1),
                s_axi_arvalid   => intermediate_axi_arvalid(k - 1),
                s_axi_arready   => intermediate_axi_arready(k - 1),
                s_axi_araddr    => intermediate_axi_araddr(k - 1),
                s_axi_rvalid    => intermediate_axi_rvalid(k - 1),
                s_axi_rready    => intermediate_axi_rready(k - 1),
                s_axi_rdata     => intermediate_axi_rdata(k - 1),
                s_axi_rresp     => intermediate_axi_rresp(k - 1),
                m_a_axi_awvalid => m_axi_awvalid(k),
                m_a_axi_awready => m_axi_awready(k),
                m_a_axi_awaddr  => m_axi_awaddr(k),
                m_a_axi_wvalid  => m_axi_wvalid(k),
                m_a_axi_wready  => m_axi_wready(k),
                m_a_axi_wdata   => m_axi_wdata(k),
                m_a_axi_wstrb   => m_axi_wstrb(k),
                m_a_axi_bvalid  => m_axi_bvalid(k),
                m_a_axi_bready  => m_axi_bready(k),
                m_a_axi_bresp   => m_axi_bresp(k),
                m_a_axi_arvalid => m_axi_arvalid(k),
                m_a_axi_arready => m_axi_arready(k),
                m_a_axi_araddr  => m_axi_araddr(k),
                m_a_axi_rvalid  => m_axi_rvalid(k),
                m_a_axi_rready  => m_axi_rready(k),
                m_a_axi_rdata   => m_axi_rdata(k),
                m_a_axi_rresp   => m_axi_rresp(k),
                m_b_axi_awvalid => intermediate_axi_awvalid(k),
                m_b_axi_awready => intermediate_axi_awready(k),
                m_b_axi_awaddr  => intermediate_axi_awaddr(k),
                m_b_axi_wvalid  => intermediate_axi_wvalid(k),
                m_b_axi_wready  => intermediate_axi_wready(k),
                m_b_axi_wdata   => intermediate_axi_wdata(k),
                m_b_axi_wstrb   => intermediate_axi_wstrb(k),
                m_b_axi_bvalid  => intermediate_axi_bvalid(k),
                m_b_axi_bready  => intermediate_axi_bready(k),
                m_b_axi_bresp   => intermediate_axi_bresp(k),
                m_b_axi_arvalid => intermediate_axi_arvalid(k),
                m_b_axi_arready => intermediate_axi_arready(k),
                m_b_axi_araddr  => intermediate_axi_araddr(k),
                m_b_axi_rvalid  => intermediate_axi_rvalid(k),
                m_b_axi_rready  => intermediate_axi_rready(k),
                m_b_axi_rdata   => intermediate_axi_rdata(k),
                m_b_axi_rresp   => intermediate_axi_rresp(k)
            );

    end generate interconnect_loop_1_to_end_gen;

    -- template_pr: process(__CLOCK__, __ASYNC_RESET__)
    -- begin
    --    if (__ASYNC_RESET__=__ASYNC_RESET_ACTIVE__) and (__ASYNC_RESET_USED__=true) then
    --    elsif rising_edge(__CLOCK__) then
    --        if (__SYNC_RESET__=__SYNC_RESET_ACTIVE__) and (__SYNC_RESET_USED__=true) then
    --        end if;
    --    end if;
    -- end process;

end architecture rtl;
