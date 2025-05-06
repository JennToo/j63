library ieee;
  use ieee.std_logic_1164.all;

package wb_pkg is

  type wb_controller_t is record
    cyc  : std_logic;
    dat  : std_logic_vector;
    addr : std_logic_vector;
    sel  : std_logic_vector;
    stb  : std_logic;
    we   : std_logic;
  end record wb_controller_t;

  type wb_target_t is record
    dat   : std_logic_vector;
    ack   : std_logic;
    stall : std_logic;
  end record wb_target_t;

end package wb_pkg;
