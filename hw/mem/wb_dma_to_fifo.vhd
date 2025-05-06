library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.wb_pkg.all;

-- Wishbone B4 pipelined host that copies data from a pipelined Wishbone B4
-- target into a FIFO

entity wb_dma_to_fifo is
  generic (
    addr_width     : natural;
    data_width     : natural;
    fifo_cnt_width : natural;
    fifo_cnt_max   : natural
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    -- DMA config
    dma_addr_i     : in    std_logic_vector(addr_width - 1 downto 0);
    dma_word_cnt_i : in    std_logic_vector(addr_width - 1 downto 0);
    dma_start_i    : in    std_logic;
    dma_done_o     : out   std_logic;

    wb_controller_o : out   wb_controller_t;
    wb_target_i     : in    wb_target_t;
    -- FIFO interface
    fifo_cnt_i  : in    std_logic_vector(fifo_cnt_width - 1 downto 0);
    fifo_data_o : out   std_logic_vector(data_width - 1 downto 0);
    fifo_put_o  : out   std_logic
  );
end entity wb_dma_to_fifo;

architecture rtl of wb_dma_to_fifo is

  signal fifo_cnt_unsigned    : unsigned(fifo_cnt_width - 1 downto 0);
  signal room_in_fifo         : unsigned(fifo_cnt_width - 1 downto 0);
  signal outstanding_requests : unsigned(fifo_cnt_width - 1 downto 0);

  signal words_remaining : unsigned(addr_width - 1 downto 0);
  signal cursor          : unsigned(addr_width - 1 downto 0);

  signal request_accepted : std_logic;

  signal dat : std_logic_vector(wb_controller_o.dat'range);
  signal sel : std_logic_vector(wb_controller_o.sel'range);

begin

  -- Only reads, and always request all bytes
  dat <= (others => '0');

  wb_controller_o.dat  <= dat;
  wb_controller_o.we   <= '0';
  sel                  <= (others => '1');
  wb_controller_o.sel  <= sel;
  wb_controller_o.addr <= std_logic_vector(cursor);
  wb_controller_o.stb  <= '1' when words_remaining > 0 and outstanding_requests < room_in_fifo else
                          '0';
  wb_controller_o.cyc  <= '1' when wb_controller_o.stb = '1' or outstanding_requests > 0 else
                          '0';
  request_accepted     <= '1' when wb_controller_o.stb = '1' and wb_target_i.stall = '0' else
                          '0';

  dma_done_o <= '1' when words_remaining = 0 and outstanding_requests = 0  and dma_start_i = '0' else
                '0';

  -- When we receive the data, give it to the FIFO
  fifo_data_o       <= wb_target_i.dat;
  fifo_put_o        <= wb_target_i.ack;
  fifo_cnt_unsigned <= unsigned(fifo_cnt_i);
  room_in_fifo      <= fifo_cnt_max - fifo_cnt_unsigned - 1 when fifo_cnt_max > fifo_cnt_unsigned else
                       to_unsigned(0, fifo_cnt_width);

  dma_p : process (clk_i, rst_i) is
  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        outstanding_requests <= (others => '0');
        cursor               <= (others => '0');
        words_remaining      <= (others => '0');
      else
        if (dma_start_i = '1') then
          cursor          <= unsigned(dma_addr_i);
          words_remaining <= unsigned(dma_word_cnt_i);
        end if;

        if (request_accepted = '1') then
          if (wb_target_i.ack = '0') then
            outstanding_requests <= outstanding_requests + 1;
          end if;
          cursor          <= cursor + 1;
          words_remaining <= words_remaining - 1;
        else
          if (wb_target_i.ack = '1') then
            outstanding_requests <= outstanding_requests - 1;
          end if;
        end if;
      end if;
    end if;

  end process dma_p;

end architecture rtl;

