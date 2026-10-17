library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.axi_lite_slave_pkg.all;

entity axi_lite_slave is
    generic (
        use_async_reset    : boolean   := TRUE;
        use_sync_reset     : boolean   := TRUE;
        async_reset_active : std_logic := '1';
        sync_reset_active  : std_logic := '1';
        nb_registers       : natural   := 16
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

        register_write    : out register_array_type;
        register_write_en : out std_logic_vector(nb_registers - 1 downto 0);
        register_read     : in register_array_type
    );
end entity axi_lite_slave;

architecture rtl of axi_lite_slave is

    type handle_sm_type is (idle, send_valid);

    signal w_sm    : handle_sm_type := idle;
    signal ar_sm   : handle_sm_type := idle;
    signal rrsp_sm : handle_sm_type := idle;

    signal s_axi_awaddr_stored : std_logic_vector(31 downto 0);
    signal s_axi_wdata_stored  : std_logic_vector(31 downto 0);
    signal s_axi_araddr_stored : std_logic_vector(31 downto 0);

    signal s_axi_wready_t  : std_logic;
    signal s_axi_bvalid_t  : std_logic;
    signal s_axi_arready_t : std_logic;
    signal s_axi_rvalid_t  : std_logic;

begin

    s_axi_wready  <= s_axi_wready_t;
    s_axi_bvalid  <= s_axi_bvalid_t;
    s_axi_arready <= s_axi_arready_t;
    s_axi_rvalid  <= s_axi_rvalid_t;

    process (clock, async_reset) is
    begin

        if ((async_reset = async_reset_active) and (use_async_reset = true)) then
            s_axi_awready       <= '0';
            s_axi_wready_t      <= '0';
            s_axi_bvalid_t      <= '0';
            s_axi_bresp         <= (others => '0');
            s_axi_arready_t     <= '0';
            s_axi_rvalid_t      <= '0';
            s_axi_rdata         <= (others => '0');
            s_axi_rresp         <= (others => '0');
            w_sm                <= idle;
            ar_sm               <= idle;
            rrsp_sm             <= idle;
            s_axi_awaddr_stored <= (others => '0');
            s_axi_wdata_stored  <= (others => '0');
            s_axi_araddr_stored <= (others => '0');
            register_write      <= (others => (others => '0'));
            register_write_en   <= (others => '0');
        elsif rising_edge(clock) then
            if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
                s_axi_awready       <= '0';
                s_axi_wready_t      <= '0';
                s_axi_bvalid_t      <= '0';
                s_axi_bresp         <= (others => '0');
                s_axi_arready_t     <= '0';
                s_axi_rvalid_t      <= '0';
                s_axi_rdata         <= (others => '0');
                s_axi_rresp         <= (others => '0');
                w_sm                <= idle;
                ar_sm               <= idle;
                rrsp_sm             <= idle;
                s_axi_awaddr_stored <= (others => '0');
                s_axi_wdata_stored  <= (others => '0');
                s_axi_araddr_stored <= (others => '0');
                register_write      <= (others => (others => '0'));
                register_write_en   <= (others => '0');
            else
                s_axi_awready <= '1';

                case w_sm is

                    when idle =>

                        if (s_axi_wvalid = '1' and s_axi_wready_t = '1') then
                            s_axi_wready_t <= '0';
                            -- for I in 0 to NB_REGISTERS-1 loop
                            --    if s_axi_awaddr(31 downto 2)=std_logic_vector(to_unsigned(I,30)) then
                            --        register_write(I) <= s_axi_wdata;
                            --        register_write_en(I) <=  '1';
                            --    else
                            --        register_write_en(I) <=  '0';
                            --    end if;
                            -- end loop;

                            -- register_write(to_integer(unsigned(s_axi_awaddr(31 downto 2)))) <= s_axi_wdata;
                            -- register_write_en(to_integer(unsigned(s_axi_awaddr(31 downto 2)))) <=  '1';
                            register_write(to_integer(unsigned(s_axi_awaddr(integer(ceil(log2(real(nb_registers)))) + 2 downto 2))))    <= s_axi_wdata;
                            register_write_en(to_integer(unsigned(s_axi_awaddr(integer(ceil(log2(real(nb_registers)))) + 2 downto 2)))) <= '1';
                            w_sm                                                                                                        <= send_valid;
                        else
                            s_axi_wready_t <= '1';
                        end if;

                    when send_valid =>

                        register_write_en <= (others => '0');
                        if (s_axi_bvalid_t = '1' and s_axi_bready = '1') then
                            s_axi_bvalid_t <= '0';
                            s_axi_wready_t <= '1';
                            w_sm           <= idle;
                        else
                            s_axi_bvalid_t <= '1';
                            s_axi_wready_t <= '0';
                            w_sm           <= send_valid;
                        end if;

                    when others =>

                        w_sm <= idle;

                end case;

                case ar_sm is

                    when idle =>

                        if (s_axi_arvalid = '1' and s_axi_arready_t = '1') then
                            s_axi_arready_t <= '0';
                            ar_sm           <= send_valid;
                        else
                            s_axi_arready_t <= '1';
                        end if;
                        -- for I in 0 to NB_REGISTERS-1 loop
                        --    if s_axi_araddr(31 downto 2)=std_logic_vector(to_unsigned(I,30)) then
                        --        s_axi_rdata <= register_read(I) ;
                        --    end if;
                        -- end loop;
                        -- s_axi_rdata <= register_read(to_integer(unsigned(s_axi_araddr(31 downto 2))));
                        s_axi_rdata <= register_read(to_integer(unsigned(s_axi_araddr(integer(ceil(log2(real(nb_registers)))) + 2 downto 2))));

                    when send_valid =>

                        if (s_axi_rvalid_t = '1' and s_axi_rready = '1') then
                            s_axi_rvalid_t  <= '0';
                            s_axi_arready_t <= '1';
                            ar_sm           <= idle;
                        else
                            s_axi_rvalid_t  <= '1';
                            s_axi_arready_t <= '0';
                        end if;

                    when others =>

                        ar_sm <= idle;

                end case;

            end if; -- end if of sync reset
        end if; -- end if of async reset

    end process;

end architecture rtl;
