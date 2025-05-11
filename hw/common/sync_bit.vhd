library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity sync_bit is
  port (
    clk_dest_i : in    std_logic;

    bit_i : in    std_logic;
    bit_o : out   std_logic
  );
  attribute preserve          : boolean;
  attribute preserve of bit_o : signal is true;
end entity sync_bit;

architecture rtl of sync_bit is

  signal bit_delay : std_logic;

  attribute preserve of bit_delay : signal is true;

begin

  crosser_p : process (clk_dest_i) is
  begin

    if rising_edge(clk_dest_i) then
      bit_delay <= bit_i;
      bit_o     <= bit_delay;
    end if;

  end process crosser_p;

end architecture rtl;

