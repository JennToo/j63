library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wb_debug is
  generic (
    addr_width : natural;
    data_width : natural
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    -- Wishbone interface
    wb_cyc_o   : out   std_logic;
    wb_dat_i   : in    std_logic_vector(data_width - 1 downto 0);
    wb_dat_o   : out   std_logic_vector(data_width - 1 downto 0);
    wb_ack_i   : in    std_logic;
    wb_addr_o  : out   std_logic_vector(addr_width - 1 downto 0);
    wb_stall_i : in    std_logic;
    wb_sel_o   : out   std_logic_vector((data_width / 8) - 1 downto 0);
    wb_stb_o   : out   std_logic;
    wb_we_o    : out   std_logic
  );
end entity wb_debug;

architecture rtl of wb_debug is

begin

end architecture rtl;

