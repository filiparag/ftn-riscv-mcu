library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity LPRS1_Board_GPIO is
	generic (
		g_NANOS_PER_CLK : positive := 20
	);
	port (
		clk : in std_logic;
		rst_n : in std_logic;
		i_btn : in std_logic_vector(4 downto 0);
		i_sw : in std_logic_vector(7 downto 0);
		i_7segm_data : in std_logic_vector(32 downto 0);
		i_disp_data : in std_logic_vector(31 downto 0);
		i_disp_pos : in std_logic_vector(31 downto 0);
		o_7segm_fb	: out std_logic_vector(31 downto 0);
		o_row_digit : out std_logic_vector(2 downto 0);
		o_col_7segm : out std_logic_vector(7 downto 0);
		o_color_7segm : out std_logic_vector(1 downto 0);
		o_btn_event : out std_logic;
		o_sw_event : out std_logic
	);
end LPRS1_Board_GPIO;

architecture Behavioral of LPRS1_Board_GPIO is

	type DISPLAY_COLOR is (RED, GREEN, BLUE, SEGM);
	type DISPLAY_FB is array (natural range 0 to 7) of std_logic_vector(7 downto 0);

	signal s_mux : std_logic_vector(5 downto 0);
	
	signal s_display_timer : std_logic_vector(31 downto 0);
	signal s_row_digit : std_logic_vector(2 downto 0);
	signal s_color_7segm : std_logic_vector(1 downto 0);
	
	signal s_7segm : std_logic_vector(7 downto 0);
	signal s_7segm_fb : std_logic_vector(31 downto 0);
	signal s_7segm_hex : std_logic_vector(3 downto 0);
	
	signal s_disp_col : std_logic_vector(7 downto 0);
	signal s_disp_r : DISPLAY_FB;
	signal s_disp_g : DISPLAY_FB;
	signal s_disp_b : DISPLAY_FB;

	signal s_btn : std_logic_vector(4 downto 0);
	signal s_btn_changed : std_logic;

	signal s_sw : std_logic_vector(7 downto 0);
	signal s_sw_changed : std_logic;

begin

	s_btn_changed <= or_reduce(i_btn xor s_btn);
	s_sw_changed <= or_reduce(i_sw xor s_sw);

	input_events : process(clk, rst_n)
	begin
		if rst_n = '0' then
			o_btn_event <= '0';
			o_sw_event <= '0';
			s_btn <= (others => '0');
			s_sw <= (others => '0');
		elsif rising_edge(clk) then
			-- Buttons
			o_btn_event <= s_btn_changed;
			s_btn <= i_btn;
			-- Switches
			o_sw_event <= s_sw_changed;
			s_sw <= i_sw;
		end if;
	end process;

	output_mux : process(clk, rst_n)
	begin
		if rst_n = '0' then
			s_display_timer <= (others => '0');
			s_mux <= (others => '0');
		elsif rising_edge(clk) then
			if s_display_timer > g_NANOS_PER_CLK * 1000 then
				if s_mux < 36 then
					s_mux <= s_mux + 1;
				else
					s_mux <= (others => '0');
				end if;
				s_display_timer <= (others => '0');
			else
				s_display_timer <= s_display_timer + 1;
				s_mux <= s_mux;
			end if;
		end if;
	end process;
	
	s_color_7segm <= "00" when s_mux < 8 else
						  "01" when s_mux < 16 else
						  "10" when s_mux < 24 else
						  "11";

	s_row_digit <= "000" when s_mux = 0 or s_mux =  8 or s_mux = 16 or s_mux = 24 or s_mux = 25 or s_mux = 26 else
						"001" when s_mux = 1 or s_mux =  9 or s_mux = 17 or s_mux = 27 or s_mux = 28 or s_mux = 29 else
						"010" when s_mux = 2 or s_mux = 10 or s_mux = 18 or s_mux = 30 or s_mux = 31 or s_mux = 32 else
						"011" when s_mux = 3 or s_mux = 11 or s_mux = 19 or s_mux = 33 or s_mux = 34 or s_mux = 35 else
						"100" when s_mux = 4 or s_mux = 12 or s_mux = 20 else
						"101" when s_mux = 5 or s_mux = 13 or s_mux = 21 else
						"110" when s_mux = 6 or s_mux = 14 or s_mux = 22 else
						"111";
	
	s_disp_col <= s_disp_r(to_integer(unsigned(s_row_digit))) when s_color_7segm = "00" else
					  s_disp_g(to_integer(unsigned(s_row_digit))) when s_color_7segm = "01" else
					  s_disp_b(to_integer(unsigned(s_row_digit))) when s_color_7segm = "10" else
					  (others => '0');
	
	o_col_7segm <= s_7segm when s_color_7segm = "11" else not s_disp_col(6 downto 0) & not s_disp_col(7);
	o_color_7segm <= s_color_7segm;
	o_row_digit <= s_row_digit;
	
	disk_framebuffer : process(clk, rst_n)
		variable row : integer;
		variable column : integer;
	begin
		if rst_n = '0' then
			s_disp_r <= ((others => (others=>'0')));
			s_disp_g <= ((others => (others=>'0')));
			s_disp_b <= ((others => (others=>'0')));
		elsif rising_edge(clk) then
			column := (7 - to_integer(unsigned(i_disp_pos)) / 8 - 2) mod 8;
			row := to_integer(unsigned(i_disp_pos)) mod 8;
			s_disp_r(row)(column) <= i_disp_data(0);
			s_disp_g(row)(column) <= i_disp_data(1);
			s_disp_b(row)(column) <= i_disp_data(2);
		end if;
	end process;

	select_digit : process(s_row_digit, i_7segm_data)
	begin
		case s_row_digit(1 downto 0) is
			when "11" => s_7segm_hex <= i_7segm_data(15 downto 12);
			when "10" => s_7segm_hex <= i_7segm_data(11 downto 8);
			when "01" => s_7segm_hex <= i_7segm_data(7 downto 4);
			when others => s_7segm_hex <= i_7segm_data(3 downto 0);
		end case;
	end process;

	display_digit : process(s_row_digit, s_7segm_hex, i_7segm_data)
	begin
		if i_7segm_data(32) = '1' then
			case s_row_digit(1 downto 0) is
				when "00" => s_7segm <= not i_7segm_data(7 downto 0);
				when "01" => s_7segm <= not i_7segm_data(15 downto 8);
				when "10" => s_7segm <= not i_7segm_data(23 downto 16);
				when others => s_7segm <= not i_7segm_data(31 downto 24);
			end case;
		else
			case s_7segm_hex is
				when "0001" => s_7segm <= "11001111";
				when "0010" => s_7segm <= "10010010";
				when "0011" => s_7segm <= "10000110";
				when "0100" => s_7segm <= "11001100";
				when "0101" => s_7segm <= "10100100";
				when "0110" => s_7segm <= "10100000";
				when "0111" => s_7segm <= "10001111";
				when "1000" => s_7segm <= "10000000";
				when "1001" => s_7segm <= "10000100";
				when "1010" => s_7segm <= "10000010";
				when "1011" => s_7segm <= "11100000";
				when "1100" => s_7segm <= "10110001";
				when "1101" => s_7segm <= "11000010";
				when "1110" => s_7segm <= "10110000";
				when "1111" => s_7segm <= "10111000";
				when others => s_7segm <= "10000001";
			end case;
		end if;
	end process;

	o_7segm_fb <= s_7segm_fb;

	segm_framebuffer : process(clk, rst_n)
		variable digit : integer;
	begin
		if rst_n = '0' then
			s_7segm_fb <= (others => '0');
		elsif rising_edge(clk) then
				digit := to_integer(unsigned(s_row_digit));
				s_7segm_fb(((digit+1)*8)-1 downto digit*8) <= not s_7segm;
		end if;
	end process;

end Behavioral;
