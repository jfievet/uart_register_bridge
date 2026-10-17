from datetime import datetime

# Get current date and time
now = datetime.now()

# Format date and time for registers (raw hex)
date_hex = f"{now.day:02d}{now.month:02d}{now.year:04d}"      # e.g. "12032026"
time_hex = f"00{now.hour:02d}{now.minute:02d}00"                # e.g. "153000"

# Format date and time as ASCII strings
date_ascii = date_hex                                         # e.g. "12032026"
time_ascii = time_hex                                         # e.g. "153000"

# Convert integers in hex
day_hex    = f"{now.day:02X}"      # 8 bits
month_hex  = f"{now.month:02X}"    # 8 bits
year_hex   = f"{now.year:04X}"     # 16 bits
hour_hex   = f"{now.hour:02X}"     # 8 bits
minute_hex = f"{now.minute:02X}"   # 8 bits
second_hex = f"{now.second:02X}"   # 8 bits

# Build the VHDL package content
vhdl_content = f"""library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package timestamp_pkg is

    -- Date register (raw hex: {date_hex})
    constant C_DATE_REGISTER_HEX   : std_logic_vector(31 downto 0) := x"{date_hex}";

    -- Time register (raw hex: {time_hex})
    constant C_TIME_REGISTER_HEX   : std_logic_vector(31 downto 0) := x"{time_hex}";

    -- Individual date fields
    constant C_DAY_HEX    : std_logic_vector(7 downto 0)  := x"{day_hex}";
    constant C_MONTH_HEX  : std_logic_vector(7 downto 0)  := x"{month_hex}";
    constant C_YEAR_HEX   : std_logic_vector(15 downto 0) := x"{year_hex}";

    -- Individual time fields
    constant C_HOUR_HEX   : std_logic_vector(7 downto 0)  := x"{hour_hex}";
    constant C_MINUTE_HEX : std_logic_vector(7 downto 0)  := x"{minute_hex}";
    constant C_SECOND_HEX : std_logic_vector(7 downto 0)  := x"{second_hex}";

end package;
"""

# Write to VHDL file
with open("../src/timestamp_pkg.vhd", "w") as file:
    file.write(vhdl_content)

print("timestamp_pkg.vhd generated successfully!")
