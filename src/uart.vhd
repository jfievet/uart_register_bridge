library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity uart is
  generic (
    use_async_reset    : boolean   := TRUE;
    use_sync_reset     : boolean   := TRUE;
    async_reset_active : std_logic := '1';
    sync_reset_active  : std_logic := '1';
    uart_clock_divider : integer   := 108 -- round(clock / uart_bitrate*8)  ie. for 100e6/115200/8=108
  );
  port (
    clock       : in    std_logic;
    async_reset : in    std_logic;
    sync_reset  : in    std_logic;

    s_axis_tdata  : in    std_logic_vector(7 downto 0);
    s_axis_tvalid : in    std_logic;
    s_axis_tready : out   std_logic;

    m_axis_tdata  : out   std_logic_vector(7 downto 0);
    m_axis_tvalid : out   std_logic;
    m_axis_tready : in    std_logic;

    tx_en : out   std_logic; -- unused
    txd   : out   std_logic;
    rxd   : in    std_logic
  );
end entity uart;

architecture rtl of uart is

  type uart_tx_state_t is (
    sm_tx_idle,
    sm_tx_bit_start,
    sm_tx_bit_0,
    sm_tx_bit_1,
    sm_tx_bit_2,
    sm_tx_bit_3,
    sm_tx_bit_4,
    sm_tx_bit_5,
    sm_tx_bit_6,
    sm_tx_bit_7,
    sm_tx_bit_stop
  );

  type uart_rx_state_t is (
    sm_rx_idle,
    sm_rx_bit_start,
    sm_rx_bit_0,
    sm_rx_bit_1,
    sm_rx_bit_2,
    sm_rx_bit_3,
    sm_rx_bit_4,
    sm_rx_bit_5,
    sm_rx_bit_6,
    sm_rx_bit_7,
    sm_rx_bit_stop
  );

  signal uart_clock_tx_cnt          : unsigned(31 downto 0);
  signal uart_clock_tx_en           : std_logic;
  signal uart_clock_tx_en_pulse_cnt : unsigned(31 downto 0);
  signal uart_clock_rx_cnt          : unsigned(31 downto 0);
  signal uart_clock_rx_en           : std_logic;
  signal uart_clock_rx_en_pulse_cnt : unsigned(31 downto 0);
  signal uart_tx_sm                 : uart_tx_state_t := sm_tx_idle;
  signal uart_rx_sm                 : uart_rx_state_t := sm_rx_idle;

  signal stored_data     : std_logic_vector(7 downto 0);
  signal s_axis_tready_t : std_logic;
  signal m_axis_tvalid_t : std_logic;

begin

  s_axis_tready <= s_axis_tready_t;
  m_axis_tvalid <= m_axis_tvalid_t;

  uart_clock_pr : process (clock, async_reset) is
  begin

    if ((async_reset = async_reset_active) and (use_async_reset = true)) then
      uart_clock_tx_cnt <= (others => '0');
      uart_clock_tx_en  <= '0';
    elsif rising_edge(clock) then
      if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
        uart_clock_tx_cnt <= (others => '0');
        uart_clock_tx_en  <= '0';
      else
        if (uart_tx_sm = sm_tx_idle) then
          uart_clock_tx_cnt <= (others => '0');
          uart_clock_tx_en  <= '0';
        else
          if (uart_clock_tx_cnt = to_unsigned(uart_clock_divider - 1, 32)) then
            uart_clock_tx_cnt <= (others => '0');
            uart_clock_tx_en  <= '1';
          else
            uart_clock_tx_cnt <= uart_clock_tx_cnt + 1;
            uart_clock_tx_en  <= '0';
          end if;
        end if;

        if (uart_rx_sm = sm_rx_idle) then
          uart_clock_rx_cnt <= (others => '0');
          uart_clock_rx_en  <= '0';
        else
          if (uart_clock_rx_cnt = to_unsigned(uart_clock_divider - 1, 32)) then
            uart_clock_rx_cnt <= (others => '0');
            uart_clock_rx_en  <= '1';
          else
            uart_clock_rx_cnt <= uart_clock_rx_cnt + 1;
            uart_clock_rx_en  <= '0';
          end if;
        end if;
      end if;
    end if;

  end process uart_clock_pr;

  uart_tx_pr : process (clock, async_reset) is
  begin

    if ((async_reset = async_reset_active) and (use_async_reset = true)) then
      txd         <= '1';
      stored_data <= (others => '0');
    elsif rising_edge(clock) then
      if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
        txd         <= '1';
        stored_data <= (others => '0');
      else
        -- tx sm
        case uart_tx_sm is

          when sm_tx_idle =>

            uart_clock_tx_en_pulse_cnt <= (others => '0');
            if (s_axis_tvalid = '1' and s_axis_tready_t = '1') then
              s_axis_tready_t <= '0';
              stored_data     <= s_axis_tdata;
              uart_tx_sm      <= sm_tx_bit_start;
            else
              s_axis_tready_t <= '1';
            end if;

          when sm_tx_bit_start =>

            txd <= '0';
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_0;
            end if;

          when sm_tx_bit_0 =>

            txd <= stored_data(0);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_1;
            end if;

          when sm_tx_bit_1 =>

            txd <= stored_data(1);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_2;
            end if;

          when sm_tx_bit_2 =>

            txd <= stored_data(2);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_3;
            end if;

          when sm_tx_bit_3 =>

            txd <= stored_data(3);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_4;
            end if;

          when sm_tx_bit_4 =>

            txd <= stored_data(4);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_5;
            end if;

          when sm_tx_bit_5 =>

            txd <= stored_data(5);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_6;
            end if;

          when sm_tx_bit_6 =>

            txd <= stored_data(6);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_7;
            end if;

          when sm_tx_bit_7 =>

            txd <= stored_data(7);
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_bit_stop;
            end if;

          when sm_tx_bit_stop =>

            txd <= '1';
            if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_tx_sm <= sm_tx_idle;
            end if;

          when others =>

            uart_tx_sm <= sm_tx_idle;

        end case;

        -- tx subcounter
        if (uart_clock_tx_en = '1' and uart_clock_tx_en_pulse_cnt = to_unsigned(7, 32)) then
          uart_clock_tx_en_pulse_cnt <= to_unsigned(0, 32);
        elsif (uart_clock_tx_en = '1') then
          uart_clock_tx_en_pulse_cnt <= uart_clock_tx_en_pulse_cnt + 1;
        end if;
      end if;
    end if;

  end process uart_tx_pr;

  uart_rx_pr : process (clock, async_reset) is
  begin

    if ((async_reset = async_reset_active) and (use_async_reset = true)) then
      m_axis_tvalid_t <= '0';
      m_axis_tdata    <= (others => '0');
    elsif rising_edge(clock) then
      if ((sync_reset = sync_reset_active) and (use_sync_reset = true)) then
        m_axis_tvalid_t <= '0';
        m_axis_tdata    <= (others => '0');
      else
        -- rx sm
        case uart_rx_sm is

          when sm_rx_idle =>

            uart_clock_rx_en_pulse_cnt <= (others => '0');
            m_axis_tvalid_t            <= '0';
            if (rxd = '0') then
              uart_rx_sm <= sm_rx_bit_start;
            else
            end if;

          when sm_rx_bit_start =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
            -- HANDLE AN ERROR HERE TBD
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_0;
            end if;

          when sm_rx_bit_0 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(0) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_1;
            end if;

          when sm_rx_bit_1 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(1) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_2;
            end if;

          when sm_rx_bit_2 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(2) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_3;
            end if;

          when sm_rx_bit_3 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(3) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_4;
            end if;

          when sm_rx_bit_4 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(4) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_5;
            end if;

          when sm_rx_bit_5 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(5) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_6;
            end if;

          when sm_rx_bit_6 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(6) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_7;
            end if;

          when sm_rx_bit_7 =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              m_axis_tdata(7) <= rxd;
            end if;
            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
              uart_rx_sm <= sm_rx_bit_stop;
            end if;

          when sm_rx_bit_stop =>

            if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
              -- HANDLE AN ERROR HERE TBD
              uart_rx_sm <= sm_rx_idle;
            end if;

          -- if uart_clock_rx_en='1' and uart_clock_rx_en_pulse_cnt=to_unsigned(7,32) then
          --    uart_rx_sm <= SM_RX_IDLE;
          -- end if;
          when others =>

            uart_rx_sm <= sm_rx_idle;

        end case;

        -- Detect SM_RX_BIT_7 and set the m_axis_tvalid_t='1'
        if (uart_rx_sm = sm_rx_bit_7 and uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(4, 32)) then
          m_axis_tvalid_t <= '1';
        elsif (m_axis_tvalid_t = '1' and m_axis_tready = '1') then
          m_axis_tvalid_t <= '0';
        end if;

        -- rx subcounter
        if (uart_clock_rx_en = '1' and uart_clock_rx_en_pulse_cnt = to_unsigned(7, 32)) then
          uart_clock_rx_en_pulse_cnt <= to_unsigned(0, 32);
        elsif (uart_clock_rx_en = '1') then
          uart_clock_rx_en_pulse_cnt <= uart_clock_rx_en_pulse_cnt + 1;
        end if;
      end if;
    end if;

  end process uart_rx_pr;

end architecture rtl;
