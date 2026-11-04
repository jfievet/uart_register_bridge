library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package top_integration_pkg is

    -- ---------------------------------------------------------------
    -- AXI COMPACT MODE - Address Mapping
    -- ---------------------------------------------------------------
    -- 7-bit address: 128 registers, 4 AXI slots, 32 registers per slot
    -- AXI byte address = Compact address * 4
    --
    -- +--------+-------------------+---------------------+
    -- | Slot   | Frame Address     | AXI Byte Address    |
    -- +--------+-------------------+---------------------+
    -- | Slot 0 | 0x00 - 0x1F       | 0x000 - 0x07C       |
    -- | Slot 1 | 0x20 - 0x3F       | 0x080 - 0x0FC       |
    -- | Slot 2 | 0x40 - 0x5F       | 0x100 - 0x17C       |
    -- | Slot 3 | 0x60 - 0x7F       | 0x180 - 0x1FC       |
    -- +--------+-------------------+---------------------+
    --
    -- Address decoding:
    --   ADDR[6:5] : AXI slot selection (0 to 3)
    --   ADDR[4:0] : Register index (0 to 31)
    --   AXI_ADDR  : ADDR[6:0] & "00"
    -- ---------------------------------------------------------------


    constant const_nb_bank_registers      : positive := 4;
    constant register_interface_mode      : integer  := 1; -- 0: AXI-Lite interface 1: Register bank interface
    constant frame_mode                   : integer  := 1; -- 0:extended 1:compact
    constant const_system_module_slot     : integer  := 0;
    constant const_nb_slots               : integer  := 4;
    constant const_nb_reg_per_slot        : integer  := 32;
    constant const_nb_interc_slave_ports  : integer  := 2;
    constant const_nb_interc_master_ports : integer  := 4;
    -- From index 1 to 31 it is a testslot, slot 0 is assigned to system

end package top_integration_pkg;
