library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bank_end_bridge is
    generic (
        nbreg              : positive              := 128;
        use_async_reset    : boolean               := TRUE;
        use_sync_reset     : boolean               := TRUE;
        async_reset_active : std_logic             := '1';
        sync_reset_active  : std_logic             := '1';
        frame_mode         : integer               := 0; -- 0: Extended uart (14 bytes) 1:Compact
        timeout_pulses     : unsigned(23 downto 0) := to_unsigned(1_500_000, 24);
        allow_bad_crc      : integer               := 0
    );
    port (
        clock       : in std_logic;
        async_reset : in std_logic;
        sync_reset  : in std_logic;

        write_reg    : out std_logic_vector(nbreg * 32 - 1 downto 0);
        write_reg_en : out std_logic_vector(nbreg - 1 downto 0);
        read_reg     : in std_logic_vector(nbreg * 32 - 1 downto 0);

        s_axis_tdata  : in std_logic_vector(7 downto 0);
        s_axis_tvalid : in std_logic;
        s_axis_tready : out std_logic;
        s_axis_tlast  : in std_logic;

        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tvalid : out std_logic;
        m_axis_tready : in std_logic;
        m_axis_tlast  : out std_logic;

        crc_error_flag     : out std_logic;
        crc_error_flag_en  : out std_logic;
        timeout_error_flag : out std_logic
    );
end entity bank_end_bridge;

architecture rtl of bank_end_bridge is

    -----------------------------------------
    -- 14 bytes frame (Extended)
    -----------------------------------------

    -- Incoming frame, 14 bytes:
    -- START | COMMAND       | ADDR[31:0] LSB first | DATA[31:0] LSB first | CRC32 LSB first
    --  AA   | WR=01, RD=02  | cnt 2..5             | cnt 6..9             | cnt 10..13
    -- CRC is calculated over START, COMMAND, ADDR and DATA only.

    -- Outgoing frame, 14 bytes:
    -- START | COMMAND/status | ADDR[31:0] LSB first | DATA[31:0] LSB first | CRC32 LSB first
    --  AA   | WR=81, RD=82   | cnt 2..5             | cnt 6..9             | cnt 10..13
    -- COMMAND/status bits 7..4:
    -- b7: not(CRC error) / CRC OK
    -- b6: AXI response error, from BRESP/RRESP /= OKAY
    -- b5..b4: reserved, zero

    -----------------------------------------
    -- 6 bytes frame (Compact UART Protocol)
    -----------------------------------------

    -- Incoming frame, 6 bytes:
    -- START | R/W + ADDR[6:0] | DATA[31:0] LSB first
    --  AA   | cnt 1           | cnt 2..5
    --
    -- Byte 1:
    --   b7    : R/W (0 = Write, 1 = Read)
    --   b6..0 : Address[6:0]
    --
    -- No CRC.

    -- Outgoing frame, 6 bytes:
    -- START | R/W + ADDR[6:0] | DATA[31:0] LSB first
    --  AA   | cnt 1           | cnt 2..5
    --
    -- Byte 1:
    --   b7    : R/W (0 = Write response, 1 = Read response)
    --   b6..0 : Address[6:0]
    --
    -- No CRC.
    --
    -- In Compact mode, ADDR[6:0] = AXI address / 4.
    -- The AXI byte address is reconstructed as ADDR[6:0] * 4.
    -- Only 32-bit aligned AXI addresses are supported.
    constant c_start  : std_logic_vector(7 downto 0) := x"AA";
    constant c_cmd_wr : std_logic_vector(7 downto 0) := x"01";
    constant c_cmd_rd : std_logic_vector(7 downto 0) := x"02";

    type sm_type is (
        idle,
        rx_init_crc,
        rx_feed_start,
        rx_commandf,
        rx_addrf,
        rx_dataf,
        rx_crcf,
        rx_check_crc,
        reg_write,
        reg_read,
        tx_init_crc,
        tx_send_payload,
        tx_wait_crc,
        tx_send_crc
    );

    signal sm  : sm_type              := idle;
    signal cnt : unsigned(3 downto 0) := (others => '0');

    signal s_axis_tready_i : std_logic                    := '0';
    signal m_axis_tdata_i  : std_logic_vector(7 downto 0) := (others => '0');
    signal m_axis_tvalid_i : std_logic                    := '0';
    signal m_axis_tlast_i  : std_logic                    := '0';

    signal write_reg_i    : std_logic_vector(nbreg * 32 - 1 downto 0) := (others => '0');
    signal write_reg_en_i : std_logic_vector(nbreg - 1 downto 0)      := (others => '0');

    signal rx_command : std_logic_vector(7 downto 0)  := (others => '0');
    signal rx_addr    : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_crc     : std_logic_vector(31 downto 0) := (others => '0');

    signal tx_command     : std_logic_vector(7 downto 0)  := (others => '0');
    signal tx_addr        : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_data        : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_crc         : std_logic_vector(31 downto 0) := (others => '0');
    signal crc_ok         : std_logic                     := '0';
    signal axi_resp_error : std_logic                     := '0';

    signal crc_data_in     : std_logic_vector(7 downto 0) := (others => '0');
    signal crc_data_in_en  : std_logic                    := '0';
    signal crc_init_in     : std_logic                    := '0';
    signal crc_data_out    : std_logic_vector(31 downto 0);
    signal crc_data_out_en : std_logic;

    signal timeout_cnt : unsigned(23 downto 0);

    function get_payload_byte (
        byte_index : unsigned(3 downto 0);
        command_b  : std_logic_vector(7 downto 0);
        addr_b     : std_logic_vector(31 downto 0);
        data_b     : std_logic_vector(31 downto 0)
    ) return std_logic_vector is

        variable r : std_logic_vector(7 downto 0);

    begin

        if (frame_mode = 1) then
            case to_integer(byte_index) is
                when 0 =>
                    r := c_start;
                when 1 =>
                    r := command_b(1) & addr_b(8 downto 2);
                when 2 =>
                    r := data_b(7 downto 0);
                when 3 =>
                    r := data_b(15 downto 8);
                when 4 =>
                    r := data_b(23 downto 16);
                when others =>
                    r := data_b(31 downto 24);
            end case;
            return r;
        end if;

        case to_integer(byte_index) is

            when 0 =>

                r := C_START;

            when 1 =>

                r := command_b;

            when 2 =>

                r := addr_b(7 downto 0);

            when 3 =>

                r := addr_b(15 downto 8);

            when 4 =>

                r := addr_b(23 downto 16);

            when 5 =>

                r := addr_b(31 downto 24);

            when 6 =>

                r := data_b(7 downto 0);

            when 7 =>

                r := data_b(15 downto 8);

            when 8 =>

                r := data_b(23 downto 16);

            when others =>

                r := data_b(31 downto 24);

        end case;

        return r;

    end function get_payload_byte;

begin

    s_axis_tready <= s_axis_tready_i;
    m_axis_tdata  <= m_axis_tdata_i;
    m_axis_tvalid <= m_axis_tvalid_i;
    m_axis_tlast  <= m_axis_tlast_i;

    extended_crc_gen : if frame_mode = 0 generate
        crc_checksum_inst : entity work.crc_checksum
            generic map(
                use_async_reset    => use_async_reset,
                use_sync_reset     => use_sync_reset,
                async_reset_active => async_reset_active,
                sync_reset_active  => sync_reset_active,
                poly_size          => 32,
                poly_value         => x"04c11db7",
                data_in_width      => 8
            )
            port map
            (
                clock       => clock,
                async_reset => async_reset,
                sync_reset  => sync_reset,
                data_in     => crc_data_in,
                data_in_en  => crc_data_in_en,
                init_in     => crc_init_in,
                data_out    => crc_data_out,
                data_out_en => crc_data_out_en
            );
    end generate extended_crc_gen;

    compact_crc_gen : if frame_mode = 1 generate
        crc_data_out    <= (others => '0');
        crc_data_out_en <= '0';
    end generate compact_crc_gen;

    main_pr : process (clock, async_reset) is

        variable payload_byte_v : std_logic_vector(7 downto 0);

    begin

        if ((async_reset = async_reset_active) and (use_async_reset = true)) then
            sm                <= idle;
            cnt               <= (others => '0');
            s_axis_tready_i   <= '0';
            m_axis_tdata_i    <= (others => '0');
            m_axis_tvalid_i   <= '0';
            m_axis_tlast_i    <= '0';
            rx_command        <= (others => '0');
            rx_addr           <= (others => '0');
            rx_data           <= (others => '0');
            rx_crc            <= (others => '0');
            tx_command        <= (others => '0');
            tx_addr           <= (others => '0');
            tx_data           <= (others => '0');
            tx_crc            <= (others => '0');
            crc_ok            <= '0';
            axi_resp_error    <= '0';
            write_reg_i       <= (others => '0');
            write_reg_en_i    <= (others => '0');
            write_reg         <= (others => '0');
            write_reg_en      <= (others => '0');
            crc_data_in       <= (others => '0');
            crc_data_in_en    <= '0';
            crc_init_in       <= '0';
            crc_error_flag    <= '0';
            crc_error_flag_en <= '0';
        elsif rising_edge(clock) then
            if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
                sm                <= idle;
                cnt               <= (others => '0');
                s_axis_tready_i   <= '0';
                m_axis_tdata_i    <= (others => '0');
                m_axis_tvalid_i   <= '0';
                m_axis_tlast_i    <= '0';
                rx_command        <= (others => '0');
                rx_addr           <= (others => '0');
                rx_data           <= (others => '0');
                rx_crc            <= (others => '0');
                tx_command        <= (others => '0');
                tx_addr           <= (others => '0');
                tx_data           <= (others => '0');
                tx_crc            <= (others => '0');
                crc_ok            <= '0';
                axi_resp_error    <= '0';
                write_reg_i       <= (others => '0');
                write_reg_en_i    <= (others => '0');
                write_reg         <= (others => '0');
                write_reg_en      <= (others => '0');
                crc_data_in       <= (others => '0');
                crc_data_in_en    <= '0';
                crc_init_in       <= '0';
                crc_error_flag    <= '0';
                crc_error_flag_en <= '0';
            else

                -- Write regs are registered
                write_reg    <= write_reg_i;
                write_reg_en <= write_reg_en_i;

                -- Defaults, overridden per state.
                s_axis_tready_i <= '0';
                m_axis_tlast_i  <= '0';
                crc_data_in_en  <= '0';
                crc_init_in     <= '0';
                write_reg_en_i  <= (others => '0');

                case sm is

                    when idle =>

                        cnt             <= (others => '0');
                        crc_ok          <= '0';
                        axi_resp_error  <= '0';
                        s_axis_tready_i <= '1';

                        if (s_axis_tvalid = '1' and (frame_mode = 0 or s_axis_tready_i = '1')) then
                            if (s_axis_tdata = c_start) then
                                s_axis_tready_i <= '0';
                                if (frame_mode = 1) then
                                    sm <= rx_commandf;
                                else
                                    sm <= rx_init_crc;
                                end if;
                            end if;
                        end if;

                    when rx_init_crc =>

                        crc_init_in <= '1';
                        sm          <= rx_feed_start;

                    when rx_feed_start =>

                        crc_data_in    <= c_start;
                        crc_data_in_en <= '1';
                        sm             <= rx_commandf;

                    when rx_commandf =>

                        s_axis_tready_i <= '1';
                        if (s_axis_tvalid = '1' and (frame_mode = 0 or s_axis_tready_i = '1')) then
                            if (frame_mode = 1) then
                                if (s_axis_tdata(7) = '1') then
                                    rx_command <= c_cmd_rd;
                                else
                                    rx_command <= c_cmd_wr;
                                end if;
                                rx_addr <= std_logic_vector(shift_left(resize(unsigned(s_axis_tdata(6 downto 0)), rx_addr'length), 2));
                                sm      <= rx_dataf;
                            else
                                rx_command     <= s_axis_tdata;
                                crc_data_in    <= s_axis_tdata;
                                crc_data_in_en <= '1';
                                sm             <= rx_addrf;
                            end if;
                            cnt             <= (others => '0');
                            s_axis_tready_i <= '0';
                        end if;

                    when rx_addrf =>

                        s_axis_tready_i <= '1';
                        if (s_axis_tvalid = '1') then
                            crc_data_in    <= s_axis_tdata;
                            crc_data_in_en <= '1';

                            case to_integer(cnt) is

                                when 0 =>

                                    rx_addr(7 downto 0) <= s_axis_tdata;

                                when 1 =>

                                    rx_addr(15 downto 8) <= s_axis_tdata;

                                when 2 =>

                                    rx_addr(23 downto 16) <= s_axis_tdata;

                                when others =>

                                    rx_addr(31 downto 24) <= s_axis_tdata;

                            end case;

                            s_axis_tready_i <= '0';
                            if (cnt = to_unsigned(3, cnt'length)) then
                                cnt <= (others => '0');
                                sm  <= rx_dataf;
                            else
                                cnt <= cnt + 1;
                            end if;
                        end if;

                    when rx_dataf =>

                        s_axis_tready_i <= '1';
                        if (s_axis_tvalid = '1' and (frame_mode = 0 or s_axis_tready_i = '1')) then
                            if (frame_mode = 0) then
                                crc_data_in    <= s_axis_tdata;
                                crc_data_in_en <= '1';
                            end if;

                            case to_integer(cnt) is

                                when 0 =>

                                    rx_data(7 downto 0) <= s_axis_tdata;

                                when 1 =>

                                    rx_data(15 downto 8) <= s_axis_tdata;

                                when 2 =>

                                    rx_data(23 downto 16) <= s_axis_tdata;

                                when others =>

                                    rx_data(31 downto 24) <= s_axis_tdata;

                            end case;

                            s_axis_tready_i <= '0';
                            if (cnt = to_unsigned(3, cnt'length)) then
                                cnt <= (others => '0');
                                if (frame_mode = 1) then
                                    if (rx_command = c_cmd_wr) then
                                        sm <= reg_write;
                                    else
                                        sm <= reg_read;
                                    end if;
                                else
                                    sm <= rx_crcf;
                                end if;
                            else
                                cnt <= cnt + 1;
                            end if;
                        end if;

                    when rx_crcf =>

                        s_axis_tready_i <= '1';
                        if (s_axis_tvalid = '1') then

                            case to_integer(cnt) is

                                when 0 =>

                                    rx_crc(7 downto 0) <= s_axis_tdata;

                                when 1 =>

                                    rx_crc(15 downto 8) <= s_axis_tdata;

                                when 2 =>

                                    rx_crc(23 downto 16) <= s_axis_tdata;

                                when others =>

                                    rx_crc(31 downto 24) <= s_axis_tdata;

                            end case;

                            s_axis_tready_i <= '0';
                            if (cnt = to_unsigned(3, cnt'length)) then
                                cnt <= (others => '0');
                                sm  <= rx_check_crc;
                            else
                                cnt <= cnt + 1;
                            end if;
                        end if;

                    when rx_check_crc =>

                        if (rx_crc = crc_data_out) then
                            crc_error_flag <= '0';
                            crc_ok         <= '1';
                            if (rx_command = c_cmd_wr) then
                                sm <= reg_write;
                            elsif (rx_command = c_cmd_rd) then
                                sm <= reg_read;
                            else
                                tx_addr    <= rx_addr;
                                tx_data    <= (others => '0');
                                tx_command <= '1' & '0' & "00" & rx_command(3 downto 0);
                                sm         <= tx_init_crc;
                            end if;
                        elsif (allow_bad_crc = 1) then
                            crc_error_flag <= '1';
                            crc_ok         <= '0';
                            if (rx_command = c_cmd_wr) then
                                sm <= reg_write;
                            elsif (rx_command = c_cmd_rd) then
                                sm <= reg_read;
                            else
                                tx_addr    <= rx_addr;
                                tx_data    <= (others => '0');
                                tx_command <= '1' & '0' & "00" & rx_command(3 downto 0);
                                sm         <= tx_init_crc;
                            end if;
                        else
                            crc_ok         <= '0';
                            crc_error_flag <= '1';
                            tx_addr        <= rx_addr;
                            tx_data        <= (others => '0');
                            tx_command     <= '0' & '0' & "00" & rx_command(3 downto 0);
                            sm             <= tx_init_crc;
                        end if;

                    when reg_write =>

                        -- Address is a byte address, register index = address / 4.
                        -- Write data remains stable; write enable is a one-clock pulse.
                        tx_addr <= rx_addr;
                        tx_data <= rx_data;
                        if rx_addr(1 downto 0) = "00" and
                            (unsigned(rx_addr(31 downto 2)) < to_unsigned(nbreg, 30)) then
                            write_reg_i((to_integer(unsigned(rx_addr(31 downto 2))) + 1) * 32 - 1 downto
                            to_integer(unsigned(rx_addr(31 downto 2))) * 32)           <= rx_data;
                            write_reg_en_i(to_integer(unsigned(rx_addr(31 downto 2)))) <= '1';
                            axi_resp_error                                             <= '0';
                            tx_command                                                 <= "1000" & c_cmd_wr(3 downto 0);
                        else
                            axi_resp_error <= '1';
                            tx_command     <= "1100" & c_cmd_wr(3 downto 0);
                        end if;
                        sm <= tx_init_crc;

                    when reg_read =>

                        tx_addr <= rx_addr;
                        if rx_addr(1 downto 0) = "00" and
                            (unsigned(rx_addr(31 downto 2)) < to_unsigned(nbreg, 30)) then
                            tx_data <= read_reg((to_integer(unsigned(rx_addr(31 downto 2))) + 1) * 32 - 1 downto
                                to_integer(unsigned(rx_addr(31 downto 2))) * 32);
                            axi_resp_error <= '0';
                            tx_command     <= "1000" & c_cmd_rd(3 downto 0);
                        else
                            tx_data        <= (others => '0');
                            axi_resp_error <= '1';
                            tx_command     <= "1100" & c_cmd_rd(3 downto 0);
                        end if;
                        sm <= tx_init_crc;

                    when tx_init_crc =>

                        if (frame_mode = 0) then
                            crc_init_in <= '1';
                        end if;
                        cnt <= (others => '0');
                        sm  <= tx_send_payload;

                    when tx_send_payload =>

                        -- Keep TLAST asserted with the final compact byte during stalls.
                        if (frame_mode = 1 and cnt = to_unsigned(5, cnt'length)) then
                            m_axis_tlast_i <= '1';
                        end if;

                        -- If no byte is currently valid, load the current payload byte
                        if (m_axis_tvalid_i = '0') then
                            m_axis_tdata_i  <= get_payload_byte(cnt, tx_command, tx_addr, tx_data);
                            m_axis_tvalid_i <= '1';

                            -- Transfer happens only here
                        elsif (m_axis_tready = '1') then
                            -- CRC uses the byte that was actually handshaken
                            if (frame_mode = 0) then
                                crc_data_in    <= m_axis_tdata_i;
                                crc_data_in_en <= '1';
                            end if;

                            if ((frame_mode = 0 and cnt = to_unsigned(9, cnt'length)) or
                                (frame_mode = 1 and cnt = to_unsigned(5, cnt'length))) then
                                cnt             <= (others => '0');
                                m_axis_tvalid_i <= '0';
                                if (frame_mode = 1) then
                                    m_axis_tlast_i <= '0';
                                    sm             <= idle;
                                else
                                    sm <= tx_wait_crc;
                                end if;
                            else
                                cnt <= cnt + 1;

                                -- Preload next byte for next transfer
                                m_axis_tdata_i  <= get_payload_byte(cnt + 1, tx_command, tx_addr, tx_data);
                                m_axis_tvalid_i <= '1';
                                if (frame_mode = 1 and cnt = to_unsigned(4, cnt'length)) then
                                    m_axis_tlast_i <= '1';
                                end if;
                            end if;
                        end if;

                    when tx_wait_crc =>

                        if (crc_data_out_en = '1') then
                            tx_crc <= crc_data_out;
                            cnt    <= (others => '0');
                            sm     <= tx_send_crc;
                        end if;

                    when tx_send_crc =>

                        case to_integer(cnt) is

                            when 0 =>

                                m_axis_tdata_i <= tx_crc(7 downto 0);

                            when 1 =>

                                m_axis_tdata_i <= tx_crc(15 downto 8);

                            when 2 =>

                                m_axis_tdata_i <= tx_crc(23 downto 16);

                            when others =>

                                m_axis_tdata_i <= tx_crc(31 downto 24);

                        end case;

                        m_axis_tvalid_i <= '1';
                        if (cnt = to_unsigned(3, cnt'length)) then
                            m_axis_tlast_i <= '1';
                        else
                            m_axis_tlast_i <= '0';
                        end if;
                        if (m_axis_tready = '1') then
                            if (cnt = to_unsigned(3, cnt'length)) then
                                cnt             <= (others => '0');
                                sm              <= idle;
                                m_axis_tvalid_i <= '0';
                            else
                                cnt <= cnt + 1;
                            end if;
                        end if;

                    when others =>

                        sm <= idle;

                end case;

                if (sm = rx_check_crc) then
                    crc_error_flag_en <= '1';
                else
                    crc_error_flag_en <= '0';
                end if;
            end if;
        end if;

    end process main_pr;

    timeout_pulse_pr : process (clock, async_reset) is
    begin

        if ((async_reset = async_reset_active) and (use_async_reset = true)) then
            timeout_cnt        <= (others => '0');
            timeout_error_flag <= '0';
        elsif rising_edge(clock) then
            if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
                timeout_cnt        <= (others => '0');
                timeout_error_flag <= '0';
            else
                if (s_axis_tvalid = '1' and s_axis_tready_i = '1') then
                    timeout_cnt <= (others => '0');
                elsif (timeout_cnt = timeout_pulses) then
                    timeout_error_flag <= '1';
                else
                    timeout_cnt <= timeout_cnt + 1;
                end if;
            end if;
        end if;

    end process timeout_pulse_pr;

end architecture rtl;
