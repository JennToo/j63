library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity sim_sram is
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    sram_addr_i : in    std_logic_vector(19 downto 0);
    sram_data_i : in    std_logic_vector(15 downto 0);
    sram_data_o : out   std_logic_vector(15 downto 0);
    sram_we_i   : in    std_logic
  );
end entity sim_sram;

architecture behave of sim_sram is

  constant word_count : integer := 1024 * 1024;

  type memory_array is array (0 to word_count) of std_logic_vector(15 downto 0);

  signal memory : memory_array;

begin

  rw_p : process (clk_i, rst_i) is
  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        sram_data_o <= (others => '0');
      else
        if (sram_we_i = '1') then
          memory(to_integer(unsigned(sram_addr_i))) <= sram_data_i;
        else
          sram_data_o <= memory(to_integer(unsigned(sram_addr_i)));
        end if;
      end if;
    end if;

  end process rw_p;

end architecture behave;
