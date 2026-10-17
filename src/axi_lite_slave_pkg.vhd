library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axi_lite_slave_pkg is

    constant register_array : integer := 1024;
    type register_array_type is array (0 to register_array - 1) of std_logic_vector(31 downto 0);

end package axi_lite_slave_pkg;

package body axi_lite_slave_pkg is

end package body axi_lite_slave_pkg;
