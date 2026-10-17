library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axi_lite_interconnect_pkg is

    constant nb_axi_lite_array : integer := 32;
    type axi_32b_bus_type is array (0 to nb_axi_lite_array - 1) of std_logic_vector(31 downto 0);
    type axi_4b_bus_type is array (0 to nb_axi_lite_array - 1) of std_logic_vector(3 downto 0);
    type axi_2b_bus_type is array (0 to nb_axi_lite_array - 1) of std_logic_vector(1 downto 0);

end package axi_lite_interconnect_pkg;

package body axi_lite_interconnect_pkg is

end package body axi_lite_interconnect_pkg;
