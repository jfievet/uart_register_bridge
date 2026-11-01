
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top is
    generic (
        simu   : integer := 0;
        target : integer := 1 -- 0: altera, 1: xilinx
    );
    port (
        CLOCK_27  : in  std_logic;
        button    : in  std_logic;
        LEDG      : out std_logic
    );
end entity top;

architecture rtl of top is

    --------------------------------------------------------
    -- Integration design constants
    --------------------------------------------------------
    constant CLOCK_FREQUENCY    : natural   := 27_000_000;
    constant INTERFACE_CONF     : integer   := 1; -- 0: AXI-L 1: UART
    constant DATA_WIDTH         : integer   := 16;

    --------------------------------------------------------
    -- Global
    --------------------------------------------------------
    signal rst        : std_logic;
    signal clk_main   : std_logic;
    signal rst_main   : std_logic;
    signal rst_n_main : std_logic;

    --------------------------------------------------------
    -- NCO generation signals
    --------------------------------------------------------
    signal nco_accu            : unsigned(31 downto 0) := (others => '0');
    signal nco_accu_incr       : unsigned(31 downto 0) := to_unsigned(43, 32);
    signal nco_clock           : std_logic;
    signal nco_clock_d1        : std_logic;
    signal nco_clock_top       : std_logic;


begin

    --------------------------------------------------------
    -- Reset input
    --------------------------------------------------------
    rst <= button;

    --------------------------------------------------------
    -- NCO
    --------------------------------------------------------
    nco_pro : process (CLOCK_27)
    begin


        if rising_edge(CLOCK_27) then

            nco_accu     <= nco_accu + nco_accu_incr;
            nco_clock    <= nco_accu(31);
            nco_clock_d1 <= nco_clock;

            if nco_clock = '1' and nco_clock_d1 = '0' then
                nco_clock_top <= not nco_clock_top;
            end if;

        end if;


    end process;

    --------------------------------------------------------
    -- Outputs
    --------------------------------------------------------
    LEDG <= nco_clock_top;

end architecture rtl;
