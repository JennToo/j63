library ieee;
  use ieee.std_logic_1164.all;
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

  procedure set_byte32 (
    signal current_value : in std_logic_vector(31 downto 0);
    variable byte_index  : in natural;
    signal byte          : in std_logic_vector(7 downto 0);
    signal new_value     : out std_logic_vector(31 downto 0)
  );

  procedure get_byte32 (
    signal value        : in std_logic_vector(31 downto 0);
    variable byte_index : in natural;
    signal byte         : out std_logic_vector(7 downto 0)
  );

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

  procedure set_byte32 (
    signal current_value : in std_logic_vector(31 downto 0);
    variable byte_index  : in natural;
    signal byte          : in std_logic_vector(7 downto 0);
    signal new_value     : out std_logic_vector(31 downto 0)
  ) is
  begin

    new_value <= current_value;

    case (byte_index) is

      when 0 =>

        new_value(7 downto 0) <= byte;

      when 1 =>

        new_value(15 downto 8) <= byte;

      when 2 =>

        new_value(23 downto 16) <= byte;

      when 3 =>

        new_value(31 downto 24) <= byte;

      when others =>

    end case;

  end procedure set_byte32;

  procedure get_byte32 (
    signal value        : in std_logic_vector(31 downto 0);
    variable byte_index : in natural;
    signal byte         : out std_logic_vector(7 downto 0)
  ) is
  begin

    case (byte_index) is

      when 0 =>

        byte <= value(7 downto 0);

      when 1 =>

        byte <= value(15 downto 8);

      when 2 =>

        byte <= value(23 downto 16);

      when 3 =>

        byte <= value(31 downto 24);

      when others =>

    end case;

  end procedure get_byte32;

end package body math_pkg;
