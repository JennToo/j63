library ieee;
  use ieee.std_logic_1164.all;
  use work.wb_pkg.all;

-- Pipelined Wishbone B4 adapter for SRAM

entity wb_sram is
  generic (
    addr_width : natural;
    data_width : natural
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    -- Wishbone interface
    wb_controller_i : in    wb_controller_t;
    wb_target_o     : out   wb_target_t;

    -- SRAM interface
    sram_addr_o : out   std_logic_vector(addr_width - 1 downto 0);
    sram_dat_o  : out   std_logic_vector(data_width - 1 downto 0);
    sram_dat_i  : in    std_logic_vector(data_width - 1 downto 0);
    sram_sel_o  : out   std_logic_vector((data_width / 8) - 1 downto 0);
    sram_we_o   : out   std_logic := '0'
  );
end entity wb_sram;

architecture rtl of wb_sram is

begin

  wb_target_o.stall <= '0';
  wb_target_o.dat   <= sram_dat_i;

  transaction_p : process (clk_i, rst_i) is
  begin

    if rising_edge(clk_i) then
      wb_target_o.ack <= '0';
      sram_we_o       <= '0';
      if (rst_i = '1') then
        sram_addr_o <= (others => '0');
        sram_dat_o  <= (others => '0');
        sram_sel_o  <= (others => '0');
      else
        if (wb_controller_i.cyc = '1' and wb_controller_i.stb = '1') then
          sram_we_o       <= wb_controller_i.we;
          sram_sel_o      <= wb_controller_i.sel;
          sram_addr_o     <= wb_controller_i.addr;
          sram_dat_o      <= wb_controller_i.dat;
          wb_target_o.ack <= '1';
        end if;
      end if;
    end if;

  end process transaction_p;

end architecture rtl;
