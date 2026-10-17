library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package utilities_pkg is

    function unsigned_to_real (
        data_in : unsigned
    ) return real;

    function log10 (
        data_in : real
    ) return real;

    function log2 (
        data_in : real
    ) return real;

end package utilities_pkg;

package body utilities_pkg is

    function unsigned_to_real (
        data_in : unsigned
    )
        return real is

        variable tmp : real := 0.0;

    begin

        for i in 0 to data_in'length - 1 loop

            if (data_in(I) = '1') then
                tmp := tmp + real(2 ** I);
            end if;

        end loop;

        return tmp;

    end function unsigned_to_real;

    function log10 (
        data_in : real
    )
        return real is
    begin

        return log(data_in) / log(real(10));

    end function log10;

    function log2 (
        data_in : real
    )
        return real is
    begin

        return log(data_in) / log(real(2));

    end function log2;

end package body utilities_pkg;
