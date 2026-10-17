library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package version_pkg is

    constant major : std_logic_vector(7 downto 0) := x"12";
    constant minor : std_logic_vector(7 downto 0) := x"34";
    constant patch : std_logic_vector(7 downto 0) := x"56";
    constant build : std_logic_vector(7 downto 0) := x"78";

end package version_pkg;

package body version_pkg is

end package body version_pkg;
