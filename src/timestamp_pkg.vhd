library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package timestamp_pkg is

    -- Date register (raw hex: 16102026)
    constant C_DATE_REGISTER_HEX   : std_logic_vector(31 downto 0) := x"16102026";

    -- Time register (raw hex: 00233700)
    constant C_TIME_REGISTER_HEX   : std_logic_vector(31 downto 0) := x"00233700";

    -- Individual date fields
    constant C_DAY_HEX    : std_logic_vector(7 downto 0)  := x"10";
    constant C_MONTH_HEX  : std_logic_vector(7 downto 0)  := x"0A";
    constant C_YEAR_HEX   : std_logic_vector(15 downto 0) := x"07EA";

    -- Individual time fields
    constant C_HOUR_HEX   : std_logic_vector(7 downto 0)  := x"17";
    constant C_MINUTE_HEX : std_logic_vector(7 downto 0)  := x"25";
    constant C_SECOND_HEX : std_logic_vector(7 downto 0)  := x"3A";

end package;
