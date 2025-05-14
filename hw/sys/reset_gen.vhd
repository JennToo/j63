library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity reset_gen is
  port (
    async_rst_ni : in    std_logic;

    clk_sys_i : in    std_logic;
    clk_vga_i : in    std_logic;

    rst_sys_o : out   std_logic;
    rst_vga_o : out   std_logic
  );
end entity reset_gen;

architecture rtl of reset_gen is

  signal counter        : unsigned(3 downto 0) := "1111";
  signal rst_sys_sync   : std_logic;
  signal rst_input_sync : std_logic;

begin

  -- Done in VGA clock domain since it is the slowest
  counter_p : process (clk_vga_i) is
  begin

    if rising_edge(clk_vga_i) then
      if (rst_input_sync = '0') then
        counter <= "1111";
      elsif (counter /= 0) then
        counter <= counter - 1;
      end if;
    end if;

  end process counter_p;

  generator_p : process (clk_vga_i) is
  begin

    if rising_edge(clk_vga_i) then
      if (counter = 0) then
        rst_vga_o    <= '0';
        rst_sys_sync <= '0';
      else
        rst_vga_o    <= '1';
        rst_sys_sync <= '1';
      end if;
    end if;

  end process generator_p;

  -- CDC from clk_vga into clk_sys
  u_sync_sys : entity work.sync_bit
    port map (
      clk_dest_i => clk_sys_i,
      bit_i      => rst_sys_sync,
      bit_o      => rst_sys_o
    );

  -- Improve metastability for the async input. Its probably fine without it,
  -- but synchronizing it is cheap too
  u_sync_input : entity work.sync_bit
    port map (
      clk_dest_i => clk_vga_i,
      bit_i      => async_rst_ni,
      bit_o      => rst_input_sync
    );

end architecture rtl;

