library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.wb_pkg.all;

entity wb_arbiter is
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    a_i : in    wb_controller_t;
    a_o : out   wb_target_t;
    b_i : in    wb_controller_t;
    b_o : out   wb_target_t;

    target_o : out   wb_controller_t;
    target_i : in    wb_target_t
  );
end entity wb_arbiter;

architecture rtl of wb_arbiter is

  signal a_active   : std_logic;
  signal a_active_d : std_logic;

  signal a_dat : std_logic_vector(a_o.dat'range);
  signal b_dat : std_logic_vector(b_o.dat'range);

begin

  keepalive_p : process (clk_i, rst_i) is
  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        a_active_d <= '0';
      else
        a_active_d <= a_active;
      end if;
    end if;

  end process keepalive_p;

  -- Controller A gets the bus under two circumstances:
  -- 1) It is the only one asking for it
  -- 2) It had it last cycle, and continues to ask for it
  a_active <= '1' when (a_i.cyc = '1' and b_i.cyc = '0') or (a_active_d = '1' and a_i.cyc = '1') else
              '0';

  a_dat     <= target_i.dat when a_active = '1' else
               (others => '0');
  a_o.dat   <= a_dat;
  a_o.ack   <= target_i.ack when a_active = '1' else
               '0';
  a_o.stall <= target_i.stall when a_active = '1' else
               '1';
  b_dat     <= target_i.dat when a_active = '0' else
               (others => '0');
  b_o.dat   <= b_dat;
  b_o.ack   <= target_i.ack when a_active = '0' else
               '0';
  b_o.stall <= target_i.stall when a_active = '0' else
               '1';

  target_o <= a_i when a_active = '1' else
              b_i;

end architecture rtl;

