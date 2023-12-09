library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity Peripherals is
	generic (
		g_CLK_FREQ_HZ : positive := 50_000_000
	);
	port (
		clk : in std_logic;
		rst_n : in std_logic;
		i_wb_cyc : in std_logic;
		i_wb_stb : in std_logic;
		i_wb_we : in std_logic;
		i_wb_addr : in std_logic_vector(31 downto 0);
		i_wb_data : in std_logic_vector(31 downto 0);
		i_wb_sel : in std_logic_vector(3 downto 0);
		o_wb_stall : out std_logic;
		o_wb_ack : out std_logic;
		o_wb_data : out std_logic_vector(31 downto 0);
		-- LEDs
		o_led : out std_logic_vector(7 downto 0);
		-- Display
		o_n_col_or_7segm : out std_logic_vector(7 downto 0);
		o_mux_row_or_digit : out std_logic_vector(2 downto 0);
		o_mux_sel_color_or_7segm : out std_logic_vector(1 downto 0);
		-- Semaphore
		o_sem : out std_logic_vector(2 downto 0);
		-- Buttons
		i_pb : in std_logic_vector(4 downto 0);
		-- Switches
		i_sw : in std_logic_vector(7 downto 0);
		-- UART
		i_uart_rx : in std_logic;
		o_uart_tx : out std_logic;
		-- External IRQ
		i_eoi : in std_logic_vector(31 downto 0);
		o_irq : out std_logic_vector(31 downto 0)
	);
end Peripherals;

architecture Behavioral of Peripherals is

	signal s_led : std_logic_vector(7 downto 0);
	
	signal s_7segm : std_logic_vector(32 downto 0);
	signal s_7segm_fb : std_logic_vector(31 downto 0);
	
	signal s_disp_data : std_logic_vector(31 downto 0);
	signal s_disp_pos : std_logic_vector(31 downto 0);

	signal s_uart_rx_byte : std_logic_vector(7 downto 0);
	signal s_uart_rx_dv : std_logic;
	signal s_uart_rx_recv : std_logic;
	
	signal s_uart_tx_byte : std_logic_vector(7 downto 0);
	signal s_uart_tx_dv : std_logic;
	signal s_uart_tx_active : std_logic;
	signal s_uart_tx_done : std_logic;

	signal s_btn_sw : std_logic_vector(12 downto 0);
	signal s_btn_sw_changed : std_logic;

	signal s_runtime_ns : std_logic_vector(63 downto 0);
	signal s_runtime_us : std_logic_vector(63 downto 0);
	signal s_runtime_ms : std_logic_vector(63 downto 0);

	signal s_timer_rst : std_logic_vector(3 downto 0);
	signal s_timer_sel : std_logic_vector(1 downto 0);
	signal s_timer_int : std_logic_vector(31 downto 0);

	signal s_wb_ack : std_logic;
	signal s_wb_stall : std_logic;
	signal s_wb_sel_mask : std_logic_vector(31 downto 0);
	signal s_wb_sel_mask_64bit : std_logic_vector(63 downto 0);

	signal s_irq : std_logic_vector(31 downto 0);

	---------------------------
	-- Peripheral memory map --
	---------------------------

	-- MAX1000 board
	constant ADDR_LED 			: integer := 16#0000#;	--   8bit rw LED

	-- Internal counters
	constant ADDR_COUNTER_NS	: integer := 16#0004#;	--  64bit ro Runtime counter (ns)
	constant ADDR_COUNTER_US	: integer := 16#000C#;	--  64bit ro Runtime counter (us)
	constant ADDR_COUNTER_MS	: integer := 16#0014#;	--  64bit ro Runtime counter (ms)

	-- Timers
	constant ADDR_TIMER_RST		: integer := 16#0020#;	--   4bit rw Timer reset
	constant ADDR_TIMER_SEL		: integer := 16#0024#;	--   2bit rw Timer select
	constant ADDR_TIMER_INT		: integer := 16#0028#;	--  32bit ro Timer interval

	-- UART
	constant ADDR_UART_RX_RDY	: integer := 16#0030#;	--   8bit ro UART receive ready
	constant ADDR_UART_RX		: integer := 16#0034#;	--   8bit ro UART receive byte
	constant ADDR_UART_TX		: integer := 16#0038#;	--	  8bit wo UART transmit byte

	-- LPRS1 board peripherals
	constant ADDR_BTN_SW			: integer := 16#0040#;	--  13bit ro	Buttons and switches
	constant ADDR_7SEGM_HEX		: integer := 16#0044#;	--  16bit rw	7segm hex
	constant ADDR_7SEGM			: integer := 16#0048#;	--  32bit rw	7segm custom
	constant ADDR_DISP			: integer := 16#004c#;	-- 192bit rw	LED matrix framebuffer
	
	-------------------------------
	-- Interrupt register bitmap --
	-------------------------------

	constant IRQ_TIMER0			: integer := 0;	--   Timer 0 interval has elapsed
	constant IRQ_TIMER1			: integer := 1;	--   Timer 1 interval has elapsed
	constant IRQ_TIMER2			: integer := 2;	--   Timer 2 interval has elapsed
	constant IRQ_TIMER3			: integer := 3;	--   Timer 3 interval has elapsed
	constant IRQ_UART_RX			: integer := 4;	--   UART byte received
	constant IRQ_BTN				: integer := 30;	--   Button interaction event
	constant IRQ_SW				: integer := 31;	--   Switch interaction event

begin

	----------------
	-- Components --
	----------------

	timers : entity work.Timers
		generic map (
			g_NANOS_PER_CLK 	=> 1_000_000_000 / g_CLK_FREQ_HZ, -- 20ns,
			g_TIMER_COUNT 		=> 4
		)
		port map (
			clk 					=> clk,
			rst_n 				=> rst_n,
			i_timer_rst			=> s_timer_rst,
			i_timer_sel 		=> s_timer_sel,
			i_timer_int			=>	s_timer_int,
			o_timer_ev			=> s_irq(IRQ_TIMER3 downto IRQ_TIMER0),
			o_runtime_ns		=> s_runtime_ns,
			o_runtime_us		=> s_runtime_us,
			o_runtime_ms		=> s_runtime_ms
		);

	uart_rx : entity work.UART_RX
		generic map (
			g_CLKS_PER_BIT => g_CLK_FREQ_HZ / 2_000_000 -- 2Mbps
		)
		port map (
			i_Clk       => clk,
			i_RX_Serial => i_uart_rx,
			o_RX_DV     => s_uart_rx_dv,
			o_RX_Byte   => s_uart_rx_byte
		);

	uart_tx : entity work.UART_TX
		generic map (
			g_CLKS_PER_BIT => g_CLK_FREQ_HZ / 2_000_000 -- 2Mbps
		)
		port map (
			i_Clk       => clk,
			i_TX_DV     => s_uart_tx_dv,
			i_TX_Byte   => s_uart_tx_byte,
			o_TX_Active => s_uart_tx_active,
			o_TX_Serial => o_uart_tx,
			o_TX_Done   => s_uart_tx_done
		);

	lprs1_board_gpio : entity work.LPRS1_Board_GPIO
		generic map (
			g_NANOS_PER_CLK => 1_000_000_000 / g_CLK_FREQ_HZ -- 20ns
		)
		port map (
			clk 				=> clk,
			rst_n 			=> rst_n,
			i_btn				=> i_pb,
			i_sw				=> i_sw,
			i_7segm_data	=> s_7segm,
			i_disp_data		=> s_disp_data,
			i_disp_pos		=> s_disp_pos,
			o_7segm_fb		=> s_7segm_fb,
			o_sem				=> o_sem,
			o_row_digit		=> o_mux_row_or_digit,
			o_col_7segm		=> o_n_col_or_7segm,
			o_color_7segm	=> o_mux_sel_color_or_7segm,
			o_btn_event		=> s_irq(IRQ_BTN),
			o_sw_event		=> s_irq(IRQ_SW)
		);

	o_led <= s_led;

	----------------
	-- Interrupts --
	----------------

	s_irq(29 downto 5) <= (others => '0');
	s_irq(4) <= s_uart_rx_dv;
	o_irq <= s_irq;
	
	------------------
	-- Wishbone bus --
	------------------

	wb_write : process(clk, rst_n)
	begin
		if(rst_n = '0') then
			
			s_led <= (others => '0');
			s_7segm <= "100001110011001110000010101011011"; -- LPrS
			s_disp_data <= (others => '0');
			s_disp_pos <= (others => '0');
			
			s_uart_tx_byte <= (others => '0');
			s_uart_tx_dv <= '0';
			
			s_timer_rst <= (others => '1');
			s_timer_sel <= (others => '0');
			s_timer_int <= (others => '1');
			
		elsif rising_edge(clk) then
			if i_wb_stb = '1' and i_wb_we = '1' then
				s_uart_tx_dv <= '0';
				
				-- LED
				if i_wb_addr = ADDR_LED then
					s_led <= (i_wb_data(7 downto 0) and s_wb_sel_mask(7 downto 0)) or
								(s_led and not s_wb_sel_mask(7 downto 0));

				-- 7segm hex
				elsif i_wb_addr = ADDR_7SEGM_HEX then
					s_7segm(32) <= '0';
					s_7segm(15 downto 0)	<= (i_wb_data(15 downto 0) and s_wb_sel_mask(15 downto 0)) or
													(s_7segm(15 downto 0) and not s_wb_sel_mask(15 downto 0));

				-- 7segm custom
				elsif i_wb_addr = ADDR_7SEGM then
					s_7segm(32) <= '1';
					s_7segm(31 downto 0)	<= (i_wb_data and s_wb_sel_mask) or
													(s_7segm(31 downto 0) and not s_wb_sel_mask);
													
				-- LED matrix
				elsif i_wb_addr >= ADDR_DISP and i_wb_addr < ADDR_DISP + 256 then
					s_disp_data <= (i_wb_data and s_wb_sel_mask) or
										(s_disp_data and not s_wb_sel_mask);
					s_disp_pos <= std_logic_vector(to_unsigned((to_integer(unsigned(i_wb_addr)) - ADDR_DISP) / 4, s_disp_pos'length));

				-- UART TX
				elsif i_wb_addr = ADDR_UART_TX then
					if s_uart_tx_active = '0' and s_uart_tx_dv <= '0' then
						s_uart_tx_byte <= i_wb_data(7 downto 0);
						s_uart_tx_dv <= '1';
					end if;

				-- Timer reset
				elsif i_wb_addr = ADDR_TIMER_RST then
					s_timer_rst <= (i_wb_data(s_timer_rst'length-1 downto 0) and s_wb_sel_mask(s_timer_rst'length-1 downto 0));

				-- Timer select
				elsif i_wb_addr = ADDR_TIMER_SEL then
					s_timer_sel <= (i_wb_data(s_timer_sel'length-1 downto 0) and s_wb_sel_mask(s_timer_sel'length-1 downto 0));

				-- Timer interval
				elsif i_wb_addr = ADDR_TIMER_INT then
					s_timer_int <= i_wb_data and s_wb_sel_mask;
					
				end if;
			end if;
		end if;
	end process;

	wb_read : process(clk, rst_n, s_uart_rx_dv)
		variable v_uart_rx_buffer_addr : integer;
	begin
		if(rst_n = '0') then
			s_uart_rx_recv <= '0';
			o_wb_data <= (others => '1');
		elsif rising_edge(clk) then
			if s_uart_rx_dv = '1' then
				s_uart_rx_recv <= '1';
			end if;
		
			if i_wb_stb = '1' and i_wb_we = '0' then
				
				 -- LED
				if i_wb_addr = ADDR_LED then
					o_wb_data(7 downto 0) <= s_led;

				-- 7segm
				elsif i_wb_addr = ADDR_7SEGM or i_wb_addr = ADDR_7SEGM_HEX then
					o_wb_data <= s_7segm_fb;

				-- Buttons and switches
				elsif i_wb_addr = ADDR_BTN_SW then
					o_wb_data(12 downto 0) <=  i_pb & i_sw;
					o_wb_data(31 downto 13) <= (others => '0');

				-- Nanosecond runtime counter (lower half)
				elsif i_wb_addr = ADDR_COUNTER_NS then
					o_wb_data <= s_runtime_ns(31 downto 0);
				-- Nanosecond runtime counter (upper half)
				elsif i_wb_addr = ADDR_COUNTER_NS + 4 then
					o_wb_data <= s_runtime_ns(63 downto 32);

				-- Microsecond runtime counter (lower half)
				elsif i_wb_addr = ADDR_COUNTER_US then
					o_wb_data <= s_runtime_us(31 downto 0);
				-- Microsecond runtime counter (upper half)
				elsif i_wb_addr = ADDR_COUNTER_US + 4 then
					o_wb_data <= s_runtime_us(63 downto 32);

				-- Millisecond runtime counter (lower half)
				elsif i_wb_addr = ADDR_COUNTER_MS then
					o_wb_data <= s_runtime_ms(31 downto 0);
				-- Millisecond runtime counter (upper half)
				elsif i_wb_addr = ADDR_COUNTER_MS + 4 then
					o_wb_data <= s_runtime_ms(63 downto 32);

				-- UART RX ready
				elsif i_wb_addr = ADDR_UART_RX_RDY then
					o_wb_data(0) <= s_uart_rx_dv;
					o_wb_data(31 downto 1) <= (others => '0');

				-- UART RX
				elsif i_wb_addr = ADDR_UART_RX then
					if s_uart_rx_recv = '1' then
						o_wb_data(7 downto 0) <=  s_uart_rx_byte;
						o_wb_data(31 downto 8) <= (others => '0');
						s_uart_rx_recv <= '0';
					else
						o_wb_data(31 downto 0) <= (others => '1'); -- stall
					end if;

				-- Timer reset
				elsif i_wb_addr = ADDR_TIMER_RST then
					o_wb_data(s_timer_rst'length-1 downto 0) <= s_timer_rst;
					o_wb_data(31 downto s_timer_rst'length) <= (others => '0');

				-- Timer select
				elsif i_wb_addr = ADDR_TIMER_SEL then
					o_wb_data(s_timer_sel'length-1 downto 0) <= s_timer_sel;
					o_wb_data(31 downto s_timer_sel'length) <= (others => '0');

				-- Other address
				else
					o_wb_data <= (others => '1');
				end if;
			end if;
		end if;
	end process;

	wb_ack : process(clk, rst_n)
   begin
      if rising_edge(clk) then
         if rst_n = '0' then
            s_wb_ack <= '0';
         else
            if i_wb_stb = '1' and i_wb_cyc = '1' then
               s_wb_ack <= '1' and not s_wb_stall;
            else
               s_wb_ack <= '0';
            end if;
         end if;
      end if;
   end process;

	s_wb_stall <= s_uart_tx_active;

	o_wb_ack <= s_wb_ack and i_wb_stb;
	o_wb_stall <= s_wb_stall;

	s_wb_sel_mask(31 downto 24) <= x"ff" when i_wb_sel(3) = '1' else x"00";
	s_wb_sel_mask(23 downto 16) <= x"ff" when i_wb_sel(2) = '1' else x"00";
	s_wb_sel_mask(15 downto 8) <= x"ff" when i_wb_sel(1) = '1' else x"00";
	s_wb_sel_mask(7 downto 0) <= x"ff" when i_wb_sel(0) = '1' else x"00";

end Behavioral;
