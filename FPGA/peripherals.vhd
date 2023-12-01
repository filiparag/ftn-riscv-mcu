library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity Peripherals is port ( 
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
		o_periph_led : out std_logic_vector(7 downto 0);
		-- 7 segment display
		o_periph_7segm : out std_logic_vector(7 downto 0);
		o_periph_digit : out std_logic_vector(2 downto 0);
		-- Buttons
		i_periph_btn : in std_logic_vector(4 downto 0);
		-- Switches
		i_periph_sw : in std_logic_vector(7 downto 0);
		-- UART
		i_uart_rx : in std_logic;
		o_uart_tx : out std_logic
	);
end entity;

architecture Behavioral of Peripherals is

	signal s_led : std_logic_vector(7 downto 0);
	
	signal s_digit : std_logic_vector(1 downto 0);
	signal s_digit_hex : std_logic_vector(3 downto 0);
	signal s_7segm : std_logic_vector(32 downto 0);
	signal s_7segm_timer : std_logic_vector(15 downto 0);
	
	signal s_btn : std_logic_vector(4 downto 0);
	signal s_sw : std_logic_vector(7 downto 0);
	
	signal s_uart_rx_byte : std_logic_vector(7 downto 0);
	signal s_uart_tx_byte : std_logic_vector(7 downto 0);
	signal s_uart_rx_dv : std_logic;
	signal s_uart_tx_dv : std_logic;
	signal s_uart_tx_active : std_logic;
	signal s_uart_tx_done : std_logic;
	signal s_uart_tx_busy : std_logic;
	signal s_uart_rx_waiting : std_logic;
	signal s_uart_rx_ready : std_logic;
	
	signal s_wb_ack : std_logic;
	signal s_wb_stall : std_logic;
	
begin

	uart_rx : entity work.UART_RX(RTL)
		generic map (
			g_CLKS_PER_BIT => 25
		)
		port map (
			i_Clk       => clk,
			i_RX_Serial => i_uart_rx,
			o_RX_DV     => s_uart_rx_dv,
			o_RX_Byte   => s_uart_rx_byte
		);
		
	uart_tx : entity work.UART_TX(RTL)
		generic map (
			g_CLKS_PER_BIT => 25
		)
		port map (
			i_Clk       => clk,
			i_TX_DV     => s_uart_tx_dv,
			i_TX_Byte   => s_uart_tx_byte,
			o_TX_Active => s_uart_tx_active,
			o_TX_Serial => o_uart_tx,
			o_TX_Done   => s_uart_tx_done
		);
	
	display_heartbeat : process(clk, rst_n)
	begin
		if rst_n = '0' then
			s_7segm_timer <= (others => '0');
			s_digit <= (others => '0');
		else
			if rising_edge(clk) then
				if s_7segm_timer > 50000 then
					s_digit <= s_digit + 1;
					s_7segm_timer <= (others => '0');
				else
					s_digit <= s_digit;
					s_7segm_timer <= s_7segm_timer + 1;
				end if;
			end if;
		end if;
	end process;
	
	o_periph_digit <= "0" & s_digit;
	select_digit : process(s_digit)
	begin
		case s_digit is
			when "11" => s_digit_hex <= s_7segm(15 downto 12);
			when "10" => s_digit_hex <= s_7segm(11 downto 8);
			when "01" => s_digit_hex <= s_7segm(7 downto 4);
			when others => s_digit_hex <= s_7segm(3 downto 0);
		end case;
	end process;
					
	display_digit : process(s_digit_hex, s_7segm)
	begin
		if s_7segm(32) = '1' then
			case s_digit is
				when "00" => o_periph_7segm <= not s_7segm(7 downto 0);
				when "01" => o_periph_7segm <= not s_7segm(15 downto 8);
				when "10" => o_periph_7segm <= not s_7segm(23 downto 16);
				when others => o_periph_7segm <= not s_7segm(31 downto 24);
			end case;
		else
			case s_digit_hex is
				when "0001" => o_periph_7segm <= "11001111";
				when "0010" => o_periph_7segm <= "10010010";
				when "0011" => o_periph_7segm <= "10000110";
				when "0100" => o_periph_7segm <= "11001100";
				when "0101" => o_periph_7segm <= "10100100";
				when "0110" => o_periph_7segm <= "10100000";
				when "0111" => o_periph_7segm <= "10001111";
				when "1000" => o_periph_7segm <= "10000000";
				when "1001" => o_periph_7segm <= "10000100";
				when "1010" => o_periph_7segm <= "10000010";
				when "1011" => o_periph_7segm <= "11100000";
				when "1100" => o_periph_7segm <= "10110001";
				when "1101" => o_periph_7segm <= "11000010";
				when "1110" => o_periph_7segm <= "10110000";
				when "1111" => o_periph_7segm <= "10111000";
				when others => o_periph_7segm <= "11111111";
			end case;
		end if;
	end process;
	
	o_periph_led <= s_led;
	
	wb_write : process(clk, rst_n)
	begin
		if(rst_n = '0') then
			--s_led <= (others => '0');
			s_7segm <= "100001110011001110000010101011011";
			s_uart_tx_byte <= (others => '0');
			s_uart_tx_dv <= '0';
		elsif rising_edge(clk) then
			if i_wb_stb = '1' and i_wb_we = '1' then
				if i_wb_addr = x"000" then -- LED
					--s_led <= i_wb_data(7 downto 0);
				elsif i_wb_addr = x"004" then -- 7segm hex
					s_7segm <= '0' & i_wb_data;
				elsif i_wb_addr = x"0008" then -- 7segm custom
					s_7segm <= '1' & i_wb_data;
				elsif i_wb_addr = x"ffc" then -- UART TX
					if s_uart_tx_active = '0' and s_uart_tx_dv <= '0' then
						s_uart_tx_byte <= i_wb_data(7 downto 0);
						s_uart_tx_dv <= '1';
					end if;
				end if;
			end if;
			if s_uart_tx_dv = '1' then
				s_uart_tx_dv <= '0';
			end if;
		end if;
	end process;
	
	s_led <= s_uart_tx_active & s_uart_tx_done & s_uart_rx_dv & s_uart_rx_ready & s_uart_rx_waiting & s_uart_tx_busy & "0" & i_uart_rx; --dbg
	--s_led <= s_uart_rx_byte;
	
	wb_read : process(clk, rst_n)
	begin
		if(rst_n = '0') then
			s_uart_rx_ready <= '0';
			s_uart_rx_waiting <= '0';
		elsif rising_edge(clk) then
			if i_wb_stb = '1' and i_wb_we = '0' then
				if i_wb_addr = x"00c" then -- Buttons and switches
					o_wb_data(12 downto 0) <=  i_periph_btn & i_periph_sw;
					o_wb_data(31 downto 13) <= (others => '0');
				elsif i_wb_addr = x"ff8" then -- UART RX
					if s_uart_rx_ready = '1' then
						o_wb_data(7 downto 0) <=  s_uart_rx_byte;
						o_wb_data(31 downto 8) <= (others => '0');
						s_uart_rx_ready <= '0';
						s_uart_rx_waiting <= '0';
					else
						s_uart_rx_waiting <= '1';
					end if;
				else
					o_wb_data <= (others => '1');
				end if;
			end if;
			if s_uart_rx_dv = '1' then
				s_uart_rx_ready <= '1';
			end if;
		end if;
	end process;
	
	wb_ack: process(clk, rst_n)
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
	
	s_wb_stall <= s_uart_tx_busy or s_uart_rx_waiting;
	
	wb_stall : process(s_uart_tx_active, s_uart_tx_done)
	begin
		if(rst_n = '0') then
			s_uart_tx_busy <= '0';
		else
			if rising_edge(clk) then
				if s_uart_tx_active = '1' then
					s_uart_tx_busy <= '1';
				elsif s_uart_tx_done = '1' then
					s_uart_tx_busy <= '0';
				end if;
			end if;
		end if;
	end process;

	o_wb_ack <= s_wb_ack and i_wb_stb and not s_wb_stall;
	o_wb_stall <= s_wb_stall;
	
end Behavioral;
