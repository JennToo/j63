library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_gpu is
end entity tb_gpu;

architecture behave of tb_gpu is

  constant clk_vga_period : time := 39.72194638 ns; -- 25.175 MHz
  constant clk_sys_period : time := 10          ns; -- 100    MHz

  signal clk_vga : std_logic := '0';
  signal clk_sys : std_logic := '0';
  signal arst    : std_logic;

  signal vga_hs      : std_logic;
  signal vga_vs      : std_logic;
  signal vga_blank_n : std_logic;
  signal vga_sync_n  : std_logic;
  signal vga_r       : std_logic_vector(7 downto 0);
  signal vga_g       : std_logic_vector(7 downto 0);
  signal vga_b       : std_logic_vector(7 downto 0);

begin

  clk_sys <= not clk_sys after clk_sys_period / 2;
  clk_vga <= not clk_vga after clk_vga_period / 2;

  u_gpu : entity work.gpu
    port map (
      clk_sys => clk_sys,
      clk_vga => clk_vga,
      arst    => arst,

      vga_hs      => vga_hs,
      vga_vs      => vga_vs,
      vga_blank_n => vga_blank_n,
      vga_sync_n  => vga_sync_n,
      vga_r       => vga_r,
      vga_g       => vga_g,
      vga_b       => vga_b
    );

  u_sim_vga : entity work.sim_vga
    port map (
      clk  => clk_vga,
      arst => arst,

      vga_hs => vga_hs,
      vga_vs => vga_vs,
      vga_r  => vga_r,
      vga_g  => vga_g,
      vga_b  => vga_b
    );

  stimulus_p : process is
  begin

    arst <= '0';
    wait for clk_sys_period;
    arst <= '1';

    wait until rising_edge(vga_vs);
    wait until rising_edge(vga_vs);
    wait until rising_edge(vga_vs);

    finish;

  end process stimulus_p;

end architecture behave;
