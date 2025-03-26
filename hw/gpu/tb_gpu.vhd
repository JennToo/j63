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
  signal rst     : std_logic;

  signal vga_hs      : std_logic;
  signal vga_vs      : std_logic;
  signal vga_vs_d    : std_logic;
  signal vga_blank_n : std_logic;
  signal vga_sync_n  : std_logic;
  signal vga_r       : std_logic_vector(7 downto 0);
  signal vga_g       : std_logic_vector(7 downto 0);
  signal vga_b       : std_logic_vector(7 downto 0);

  signal sram_addr    : std_logic_vector(19 downto 0);
  signal sram_data_wr : std_logic_vector(15 downto 0);
  signal sram_data_rd : std_logic_vector(15 downto 0);
  signal sram_we      : std_logic;

  procedure vga_cycle (
    r : in std_logic_vector(7 downto 0);
    g : in std_logic_vector(7 downto 0);
    b : in std_logic_vector(7 downto 0)
  ) is
  begin

    assert false
      report "Not reachable"
      severity failure;

  end procedure vga_cycle;

  procedure vga_save_frame is
  begin

    assert false
      report "Not reachable"
      severity failure;

  end procedure vga_save_frame;

  attribute foreign of vga_cycle      : procedure is "VHPIDIRECT vga_cycle";
  attribute foreign of vga_save_frame : procedure is "VHPIDIRECT vga_save_frame";

begin

  clk_sys <= not clk_sys after clk_sys_period / 2;
  clk_vga <= not clk_vga after clk_vga_period / 2;

  u_gpu : entity work.gpu
    port map (
      clk_sys_i => clk_sys,
      clk_vga_i => clk_vga,
      rst_i     => rst,

      vga_hs_o     => vga_hs,
      vga_vs_o     => vga_vs,
      vga_blank_no => vga_blank_n,
      vga_sync_no  => vga_sync_n,
      vga_r_o      => vga_r,
      vga_g_o      => vga_g,
      vga_b_o      => vga_b,

      sram_addr_o => sram_addr,
      sram_data_o => sram_data_wr,
      sram_data_i => sram_data_rd,
      sram_we_o   => sram_we
    );

  u_sim_vga : entity work.sim_vga
    port map (
      clk_i => clk_vga,
      rst_i => rst,

      vga_hs_i => vga_hs,
      vga_vs_i => vga_vs,
      vga_r_i  => vga_r,
      vga_g_i  => vga_g,
      vga_b_i  => vga_b
    );

  u_sim_sram : entity work.sim_sram
    port map (
      clk_i => clk_sys,
      rst_i => rst,

      sram_addr_i => sram_addr,
      sram_data_i => sram_data_wr,
      sram_data_o => sram_data_rd,
      sram_we_i   => sram_we
    );

  vga_capture_p : process (clk_vga) is
  begin

    if (rst = '0') then
      vga_vs_d <= '0';
    elsif rising_edge(clk_vga) then
      if (vga_blank_n = '1') then
        vga_cycle(vga_r, vga_g, vga_b);
      end if;
      if (vga_vs = '1' and vga_vs_d = '0') then
        vga_save_frame;
      end if;
      vga_vs_d <= vga_vs;
    end if;

  end process vga_capture_p;

  stimulus_p : process is
  begin

    rst <= '0';
    wait for clk_sys_period;
    rst <= '1';

    wait until rising_edge(vga_vs);
    wait until rising_edge(vga_vs);
    wait until rising_edge(vga_vs);

    finish;

  end process stimulus_p;

end architecture behave;
