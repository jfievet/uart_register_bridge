library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axi_lite_interconnect_pkg.all;

package top_integration_pkg is

    constant addr_start : axi_32b_bus_type :=
    (
    x"00000000",
    x"00001000",
    x"00002000",
    x"00003000",
    x"00004000",
    x"00005000",
    x"00006000",
    x"00007000",
    x"00008000",
    x"00009000",
    x"0000A000",
    x"0000B000",
    x"0000C000",
    x"0000D000",
    x"0000E000",
    x"0000F000",
    x"00010000",
    x"00011000",
    x"00012000",
    x"00013000",
    x"00014000",
    x"00015000",
    x"00016000",
    x"00017000",
    x"00018000",
    x"00019000",
    x"0001A000",
    x"0001B000",
    x"0001C000",
    x"0001D000",
    x"0001E000",
    x"0001F000"
    );

    constant addr_end : axi_32b_bus_type :=
    (
    x"000001FF",
    x"000011FF",
    x"000021FF",
    x"000031FF",
    x"000041FF",
    x"000051FF",
    x"000061FF",
    x"000071FF",
    x"000081FF",
    x"000091FF",
    x"0000A1FF",
    x"0000B1FF",
    x"0000C1FF",
    x"0000D1FF",
    x"0000E1FF",
    x"0000F1FF",
    x"000101FF",
    x"000111FF",
    x"000121FF",
    x"000131FF",
    x"000141FF",
    x"000151FF",
    x"000161FF",
    x"000171FF",
    x"000181FF",
    x"000191FF",
    x"0001A1FF",
    x"0001B1FF",
    x"0001C1FF",
    x"0001D1FF",
    x"0001E1FF",
    x"0001F1FF"
    );

    constant register_interface_mode      : integer := 0; -- 0: AXI-Lite interface 1: Register bank interface
    constant frame_mode                   : integer := 0; -- 0:extended 1:compact
    constant const_system_module_slot     : integer := 0;
    constant const_nb_slots               : integer := 4;
    constant const_nb_reg_per_slot        : integer := 32;
    constant const_nb_interc_slave_ports  : integer := 2;
    constant const_nb_interc_master_ports : integer := 4;
    -- From index 1 to 31 it is a testslot, slot 0 is assigned to system

end package top_integration_pkg;
