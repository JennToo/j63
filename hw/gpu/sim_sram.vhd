library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity sim_sram is
  port (
    clk  : in    std_logic;
    arst : in    std_logic;

    sram_addr    : in    std_logic_vector(19 downto 0);
    sram_data_wr : in    std_logic_vector(15 downto 0);
    sram_data_rd : out   std_logic_vector(15 downto 0);
    sram_we      : in    std_logic
  );
end entity sim_sram;

architecture behave of sim_sram is

  constant word_count : integer := 1024 * 1024;

  type memory_array is array (0 to word_count) of std_logic_vector(15 downto 0);

  signal memory : memory_array;

begin

  rw_p : process (clk, arst) is
  begin

    if (arst = '0') then
      sram_data_rd <= (others => '0');
    elsif rising_edge(clk) then
      if (sram_we = '1') then
        memory(to_integer(unsigned(sram_addr))) <= sram_data_wr;
      else
        sram_data_rd <= memory(to_integer(unsigned(sram_addr)));
      end if;
    end if;

  end process rw_p;

end architecture behave;
