library ieee;
  use ieee.std_logic_1164.all;

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
    wb_cyc_i   : in    std_logic;
    wb_dat_i   : in    std_logic_vector(data_width - 1 downto 0);
    wb_dat_o   : out   std_logic_vector(data_width - 1 downto 0);
    wb_ack_o   : out   std_logic;
    wb_addr_i  : in    std_logic_vector(addr_width - 1 downto 0);
    wb_stall_o : out   std_logic;
    wb_sel_i   : in    std_logic_vector((data_width / 8) - 1 downto 0);
    wb_stb_i   : in    std_logic;
    wb_we_i    : in    std_logic;

    -- SRAM interface
    sram_addr_o : out   std_logic_vector(addr_width - 1 downto 0);
    sram_dat_o  : out   std_logic_vector(data_width - 1 downto 0);
    sram_dat_i  : in    std_logic_vector(data_width - 1 downto 0);
    sram_sel_o  : out   std_logic_vector((data_width / 8) - 1 downto 0);
    sram_we_o   : out   std_logic
  );
end entity wb_sram;

architecture rtl of wb_sram is

begin

  wb_stall_o <= '0';
  wb_dat_o   <= sram_dat_i;

  transaction_p : process (clk_i, rst_i) is
  begin

    if (rst_i = '0') then
      sram_addr_o <= (others => '0');
      sram_dat_o  <= (others => '0');
      sram_sel_o  <= (others => '0');
      sram_we_o   <= '0';

      wb_ack_o <= '0';
    elsif rising_edge(clk_i) then
      wb_ack_o <= '0';

      if (wb_cyc_i = '1' and wb_stb_i = '1') then
        sram_we_o   <= wb_we_i;
        sram_sel_o  <= wb_sel_i;
        sram_addr_o <= wb_addr_i;
        -- This will be tri-stated later anyways
        sram_dat_o <= wb_dat_i;
        wb_ack_o   <= '1';
      end if;
    end if;

  end process transaction_p;

end architecture rtl;
