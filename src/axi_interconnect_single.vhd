library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_interconnect_single is
    generic (
        use_async_reset    : boolean   := TRUE;
        use_sync_reset     : boolean   := TRUE;
        async_reset_active : std_logic := '1';
        sync_reset_active  : std_logic := '1';
        addr_start         : std_logic_vector(31 downto 0);
        addr_end           : std_logic_vector(31 downto 0);
        addr_offset        : std_logic_vector(31 downto 0)
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

        m_a_axi_awvalid : out std_logic;
        m_a_axi_awready : in std_logic;
        m_a_axi_awaddr  : out std_logic_vector(31 downto 0);
        m_a_axi_wvalid  : out std_logic;
        m_a_axi_wready  : in std_logic;
        m_a_axi_wdata   : out std_logic_vector(31 downto 0);
        m_a_axi_wstrb   : out std_logic_vector(3 downto 0);
        m_a_axi_bvalid  : in std_logic;
        m_a_axi_bready  : out std_logic;
        m_a_axi_bresp   : in std_logic_vector(1 downto 0);
        m_a_axi_arvalid : out std_logic;
        m_a_axi_arready : in std_logic;
        m_a_axi_araddr  : out std_logic_vector(31 downto 0);
        m_a_axi_rvalid  : in std_logic;
        m_a_axi_rready  : out std_logic;
        m_a_axi_rdata   : in std_logic_vector(31 downto 0);
        m_a_axi_rresp   : in std_logic_vector(1 downto 0);

        m_b_axi_awvalid : out std_logic;
        m_b_axi_awready : in std_logic;
        m_b_axi_awaddr  : out std_logic_vector(31 downto 0);
        m_b_axi_wvalid  : out std_logic;
        m_b_axi_wready  : in std_logic;
        m_b_axi_wdata   : out std_logic_vector(31 downto 0);
        m_b_axi_wstrb   : out std_logic_vector(3 downto 0);
        m_b_axi_bvalid  : in std_logic;
        m_b_axi_bready  : out std_logic;
        m_b_axi_bresp   : in std_logic_vector(1 downto 0);
        m_b_axi_arvalid : out std_logic;
        m_b_axi_arready : in std_logic;
        m_b_axi_araddr  : out std_logic_vector(31 downto 0);
        m_b_axi_rvalid  : in std_logic;
        m_b_axi_rready  : out std_logic;
        m_b_axi_rdata   : in std_logic_vector(31 downto 0);
        m_b_axi_rresp   : in std_logic_vector(1 downto 0)
    );
end entity axi_interconnect_single;

architecture rtl of axi_interconnect_single is

    type handle_sm_type is (idle, send_valid);

    signal aw_sm   : handle_sm_type := idle;
    signal w_sm    : handle_sm_type := idle;
    signal wrsp_sm : handle_sm_type := idle;
    signal ar_sm   : handle_sm_type := idle;
    signal rrsp_sm : handle_sm_type := idle;

    signal s_axi_awaddr_stored  : std_logic_vector(31 downto 0);
    signal s_axi_wdata_stored   : std_logic_vector(31 downto 0);
    signal s_axi_araddr_stored  : std_logic_vector(31 downto 0);
    signal m_a_axi_rdata_stored : std_logic_vector(31 downto 0);
    signal m_b_axi_rdata_stored : std_logic_vector(31 downto 0);

    signal s_axi_awready_t   : std_logic;
    signal s_axi_wready_t    : std_logic;
    signal s_axi_bvalid_t    : std_logic;
    signal s_axi_arready_t   : std_logic;
    signal s_axi_rvalid_t    : std_logic;
    signal m_a_axi_awvalid_t : std_logic;
    signal m_b_axi_awvalid_t : std_logic;
    signal m_a_axi_bready_t  : std_logic;
    signal m_b_axi_bready_t  : std_logic;
    signal m_a_axi_arvalid_t : std_logic;
    signal m_b_axi_arvalid_t : std_logic;
    signal m_a_axi_rready_t  : std_logic;
    signal m_b_axi_rready_t  : std_logic;

begin

    s_axi_awready   <= s_axi_awready_t;
    s_axi_wready    <= s_axi_wready_t;
    s_axi_bvalid    <= s_axi_bvalid_t;
    m_a_axi_awvalid <= m_a_axi_awvalid_t;
    m_b_axi_awvalid <= m_b_axi_awvalid_t;
    m_a_axi_bready  <= m_a_axi_bready_t;
    m_b_axi_bready  <= m_b_axi_bready_t;
    s_axi_arready   <= s_axi_arready_t;
    m_a_axi_arvalid <= m_a_axi_arvalid_t;
    m_b_axi_arvalid <= m_b_axi_arvalid_t;
    m_a_axi_rready  <= m_a_axi_rready_t;
    m_b_axi_rready  <= m_b_axi_rready_t;
    s_axi_rvalid    <= s_axi_rvalid_t;

    process (clock, async_reset) is
    begin

        if ((async_reset = async_reset_active) and (use_async_reset = true)) then
            s_axi_awready_t      <= '0';
            s_axi_wready_t       <= '0';
            s_axi_bvalid_t       <= '0';
            s_axi_bresp          <= (others => '0');
            s_axi_arready_t      <= '0';
            s_axi_rvalid_t       <= '0';
            s_axi_rdata          <= (others => '0');
            s_axi_rresp          <= (others => '0');
            m_a_axi_awvalid_t    <= '0';
            m_a_axi_awaddr       <= (others => '0');
            m_a_axi_wvalid       <= '0';
            m_a_axi_wdata        <= (others => '0');
            m_a_axi_wstrb        <= (others => '0');
            m_a_axi_bready_t     <= '0';
            m_a_axi_arvalid_t    <= '0';
            m_a_axi_araddr       <= (others => '0');
            m_a_axi_rready_t     <= '0';
            m_b_axi_awvalid_t    <= '0';
            m_b_axi_awaddr       <= (others => '0');
            m_b_axi_wvalid       <= '0';
            m_b_axi_wdata        <= (others => '0');
            m_b_axi_wstrb        <= (others => '0');
            m_b_axi_bready_t     <= '0';
            m_b_axi_arvalid_t    <= '0';
            m_b_axi_araddr       <= (others => '0');
            m_b_axi_rready_t     <= '0';
            aw_sm                <= idle;
            w_sm                 <= idle;
            wrsp_sm              <= idle;
            ar_sm                <= idle;
            rrsp_sm              <= idle;
            s_axi_awaddr_stored  <= (others => '0');
            s_axi_wdata_stored   <= (others => '0');
            s_axi_araddr_stored  <= (others => '0');
            m_a_axi_rdata_stored <= (others => '0');
            m_b_axi_rdata_stored <= (others => '0');
        elsif rising_edge(clock) then
            if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
                s_axi_awready_t      <= '0';
                s_axi_wready_t       <= '0';
                s_axi_bvalid_t       <= '0';
                s_axi_bresp          <= (others => '0');
                s_axi_arready_t      <= '0';
                s_axi_rvalid_t       <= '0';
                s_axi_rdata          <= (others => '0');
                s_axi_rresp          <= (others => '0');
                m_a_axi_awvalid_t    <= '0';
                m_a_axi_awaddr       <= (others => '0');
                m_a_axi_wvalid       <= '0';
                m_a_axi_wdata        <= (others => '0');
                m_a_axi_wstrb        <= (others => '0');
                m_a_axi_bready_t     <= '0';
                m_a_axi_arvalid_t    <= '0';
                m_a_axi_araddr       <= (others => '0');
                m_a_axi_rready_t     <= '0';
                m_b_axi_awvalid_t    <= '0';
                m_b_axi_awaddr       <= (others => '0');
                m_b_axi_wvalid       <= '0';
                m_b_axi_wdata        <= (others => '0');
                m_b_axi_wstrb        <= (others => '0');
                m_b_axi_bready_t     <= '0';
                m_b_axi_arvalid_t    <= '0';
                m_b_axi_araddr       <= (others => '0');
                m_b_axi_rready_t     <= '0';
                aw_sm                <= idle;
                w_sm                 <= idle;
                wrsp_sm              <= idle;
                ar_sm                <= idle;
                rrsp_sm              <= idle;
                s_axi_awaddr_stored  <= (others => '0');
                s_axi_wdata_stored   <= (others => '0');
                s_axi_araddr_stored  <= (others => '0');
                m_a_axi_rdata_stored <= (others => '0');
                m_b_axi_rdata_stored <= (others => '0');
            else

                case aw_sm is

                    when idle =>

                        if (s_axi_awvalid = '1' and s_axi_awready_t = '1') then
                            s_axi_awready_t                                 <= '0';
                            m_a_axi_wstrb                                   <= s_axi_wstrb;
                            m_b_axi_wstrb                                   <= s_axi_wstrb;
                            aw_sm                                           <= send_valid;
                            if (s_axi_awaddr >= addr_start and s_axi_awaddr <= addr_end) then
                                m_a_axi_awaddr                                  <= std_logic_vector(unsigned(s_axi_awaddr) - unsigned(addr_offset));
                                m_a_axi_awvalid_t                               <= '1';
                            else
                                m_b_axi_awaddr    <= s_axi_awaddr;
                                m_b_axi_awvalid_t <= '1';
                            end if;
                        else
                            s_axi_awready_t <= '1';
                        end if;
                        s_axi_awaddr_stored <= s_axi_awaddr;
                        s_axi_wdata_stored  <= s_axi_wdata;

                    when send_valid =>

                        if (s_axi_awaddr_stored >= addr_start and s_axi_awaddr_stored <= addr_end) then
                            if (m_a_axi_awvalid_t = '1' and m_a_axi_awready = '1') then
                                s_axi_awready_t   <= '1';
                                m_a_axi_awvalid_t <= '0';
                                aw_sm             <= idle;
                            end if;
                        else
                            if (m_b_axi_awvalid_t = '1' and m_b_axi_awready = '1') then
                                s_axi_awready_t   <= '1';
                                m_b_axi_awvalid_t <= '0';
                                aw_sm             <= idle;
                            end if;
                        end if;

                    when others =>

                        aw_sm <= idle;

                end case;

                m_a_axi_wdata <= s_axi_wdata;
                m_b_axi_wdata <= s_axi_wdata;

                case w_sm is

                    when idle =>

                        if (s_axi_wvalid = '1' and s_axi_wready_t = '1') then
                            s_axi_wready_t                                  <= '0';
                            m_a_axi_wstrb                                   <= s_axi_wstrb;
                            m_b_axi_wstrb                                   <= s_axi_wstrb;
                            if (s_axi_awaddr >= addr_start and s_axi_awaddr <= addr_end) then
                                m_a_axi_wvalid                                  <= '1';
                            else
                                m_b_axi_wvalid <= '1';
                            end if;
                            w_sm <= send_valid;
                        else
                            s_axi_wready_t <= '1';
                        end if;

                    when send_valid =>

                        -- Attention, this part might be buggy, there is no handshaking on the wvalid
                        if (s_axi_awaddr_stored >= addr_start and s_axi_awaddr_stored <= addr_end) then
                            s_axi_wready_t                                                <= '1';
                            m_a_axi_wvalid                                                <= '0';
                            w_sm                                                          <= idle;
                        else
                            s_axi_wready_t <= '1';
                            m_b_axi_wvalid <= '0';
                            w_sm           <= idle;
                        end if;

                    when others =>

                end case;

                case wrsp_sm is

                    when idle =>

                        if (s_axi_awaddr_stored >= addr_start and s_axi_awaddr_stored <= addr_end) then
                            if (m_a_axi_bvalid = '1' and m_a_axi_bready_t = '1') then
                                s_axi_bvalid_t   <= '1';
                                s_axi_bresp      <= m_a_axi_bresp;
                                m_a_axi_bready_t <= '0';
                                wrsp_sm          <= send_valid;
                            else
                                m_a_axi_bready_t <= '1';
                                m_b_axi_bready_t <= '1';
                            end if;
                        else
                            if (m_b_axi_bvalid = '1' and m_b_axi_bready_t = '1') then
                                s_axi_bvalid_t   <= '1';
                                s_axi_bresp      <= m_b_axi_bresp;
                                m_b_axi_bready_t <= '0';
                                wrsp_sm          <= send_valid;
                            else
                                m_a_axi_bready_t <= '1';
                                m_b_axi_bready_t <= '1';
                            end if;
                        end if;

                    when send_valid =>

                        if (s_axi_bvalid_t = '1' and s_axi_bready = '1') then
                            m_a_axi_bready_t <= '1';
                            m_b_axi_bready_t <= '1';
                            s_axi_bvalid_t   <= '0';
                            wrsp_sm          <= idle;
                        end if;

                    when others =>

                        wrsp_sm <= idle;

                end case;

                case ar_sm is

                    when idle =>

                        if (s_axi_arvalid = '1' and s_axi_arready_t = '1') then
                            s_axi_arready_t                                 <= '0';
                            if (s_axi_araddr >= addr_start and s_axi_araddr <= addr_end) then
                                m_a_axi_arvalid_t                               <= '1';
                                m_a_axi_araddr                                  <= std_logic_vector(unsigned(s_axi_araddr) - unsigned(addr_offset));
                            else
                                m_b_axi_arvalid_t <= '1';
                                m_b_axi_araddr    <= std_logic_vector(unsigned(s_axi_araddr));
                            end if;
                            ar_sm <= send_valid;
                        else
                            s_axi_arready_t <= '1';
                        end if;
                        s_axi_araddr_stored <= s_axi_araddr;

                    when send_valid =>

                        if (s_axi_araddr_stored >= addr_start and s_axi_araddr_stored <= addr_end) then
                            if (m_a_axi_arvalid_t = '1' and m_a_axi_arready = '1') then
                                m_a_axi_arvalid_t <= '0';
                                s_axi_arready_t   <= '1';
                                ar_sm             <= idle;
                            end if;
                        else
                            if (m_b_axi_arvalid_t = '1' and m_b_axi_arready = '1') then
                                m_b_axi_arvalid_t <= '0';
                                s_axi_arready_t   <= '1';
                                ar_sm             <= idle;
                            end if;
                        end if;

                    when others =>

                        ar_sm <= idle;

                end case;

                case rrsp_sm is

                    when idle =>

                        if (s_axi_araddr >= addr_start and s_axi_araddr <= addr_end) then
                            if (m_a_axi_rvalid = '1' and m_a_axi_rready_t = '1') then
                                m_a_axi_rready_t     <= '0';
                                m_a_axi_rdata_stored <= m_a_axi_rdata;
                                rrsp_sm              <= send_valid;
                            else
                                m_a_axi_rready_t <= '1';
                                m_b_axi_rready_t <= '1';
                            end if;
                        else
                            if (m_b_axi_rvalid = '1' and m_b_axi_rready_t = '1') then
                                m_b_axi_rready_t     <= '0';
                                m_b_axi_rdata_stored <= m_b_axi_rdata;
                                rrsp_sm              <= send_valid;
                            else
                                m_a_axi_rready_t <= '1';
                                m_b_axi_rready_t <= '1';
                            end if;
                        end if;

                    when send_valid =>

                        if (s_axi_rvalid_t = '1' and s_axi_rready = '1') then
                            m_a_axi_rready_t <= '1';
                            m_b_axi_rready_t <= '1';
                            s_axi_rvalid_t   <= '0';
                            rrsp_sm          <= idle;
                        else
                            s_axi_rvalid_t                                                <= '1';
                            if (s_axi_araddr_stored >= addr_start and s_axi_araddr_stored <= addr_end) then
                                s_axi_rdata                                                   <= m_a_axi_rdata_stored;
                            else
                                s_axi_rdata <= m_b_axi_rdata_stored;
                            end if;
                        end if;

                    when others =>

                        rrsp_sm <= idle;

                end case;

            end if; -- end if of sync reset
        end if; -- end if of async reset

    end process;

end architecture rtl;
