package test_pkg is

  function time_equal_ish (
    time_a: time;
    time_b: time;
    epsilon : time
  ) return boolean;

end package test_pkg;

package body test_pkg is

  function time_equal_ish (
    time_a: time;
    time_b: time;
    epsilon : time
  ) return boolean is

    variable time_difference : time;

  begin

    time_difference := time_a - time_b;

    if (time_difference > 0 fs) then
      return time_difference < epsilon;
    else
      return -time_difference < epsilon;
    end if;

  end function time_equal_ish;

end package body test_pkg;
