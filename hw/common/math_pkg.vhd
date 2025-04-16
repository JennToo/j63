library ieee;
  use ieee.math_real.all;

package math_pkg is

  function period_to_cycles (
    period: time;
    clk_period: time;
    round_up: boolean
  ) return integer;

  function clog2 (
    n: integer
  ) return integer;

  type range_t is record
    high : natural;
    low  : natural;
  end record range_t;

  function byte_range (
    byte_index: natural
  ) return range_t;

end package math_pkg;

package body math_pkg is

  function period_to_cycles (
    period: time;
    clk_period: time;
    round_up: boolean
  ) return integer is
  begin

    if (round_up) then
      return integer(ceil(real(period / 1 ps) / real(clk_period / 1 ps)));
    else
      return integer(floor(real(period / 1 ps) / real(clk_period / 1 ps)));
    end if;

  end function period_to_cycles;

  function clog2 (
    n: integer
  ) return integer is
  begin

    return integer(ceil(log2(real(n))));

  end function clog2;

  function byte_range (
    byte_index: natural
  ) return range_t is

    variable result : range_t;

  begin

    result.high := 8 * (byte_index + 1) - 1;
    result.low  := 8 * byte_index;
    return result;

  end function byte_range;

end package body math_pkg;
