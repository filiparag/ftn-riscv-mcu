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
		o_digit : out std_logic_vector(2 downto 0);
		o_7segm : out std_logic_vector(7 downto 0);
		o_btn_event : out std_logic;
		o_sw_event : out std_logic
	);
end LPRS1_Board_GPIO;

architecture Behavioral of LPRS1_Board_GPIO is

	signal s_digit : std_logic_vector(1 downto 0);
	signal s_digit_hex : std_logic_vector(3 downto 0);
	signal s_7segm_timer : std_logic_vector(18 downto 0);
	
	signal s_btn : std_logic_vector(4 downto 0);
	signal s_btn_changed : std_logic;
	
	signal s_sw : std_logic_vector(7 downto 0);
	signal s_sw_changed : std_logic;

begin

	s_btn_changed <= or_reduce(i_btn xor s_btn);
	s_sw_changed <= or_reduce(i_sw xor s_sw);
	
	events : process(clk, rst_n)
	begin
		if rst_n = '0' then
			o_btn_event <= '0';
			o_sw_event <= '0';
			s_btn <= (others => '0');
			s_sw <= (others => '0');
		elsif rising_edge(clk) then
			-- Buttons
			o_btn_event <= s_btn_changed;		
			s_sw <= i_sw;
			-- Switches
			o_sw_event <= s_sw_changed;	
			s_btn <= i_btn;
		end if;
	end process;
	
	display_heartbeat : process(clk, rst_n)
	begin
		if rst_n = '0' then
			s_7segm_timer <= (others => '0');
			s_digit <= "01";
		else
			if rising_edge(clk) then
				if s_7segm_timer > g_NANOS_PER_CLK * 1_000 then
					s_digit <= s_digit + 1;
					s_7segm_timer <= (others => '0');
				else
					s_digit <= s_digit;
					s_7segm_timer <= s_7segm_timer + 1;
				end if;
			end if;
		end if;
	end process;

	o_digit  <= "0" & s_digit;
	
	select_digit : process(s_digit, i_7segm_data)
	begin
		case s_digit is
			when "11" => s_digit_hex <= i_7segm_data(15 downto 12);
			when "10" => s_digit_hex <= i_7segm_data(11 downto 8);
			when "01" => s_digit_hex <= i_7segm_data(7 downto 4);
			when others => s_digit_hex <= i_7segm_data(3 downto 0);
		end case;
	end process;

	display_digit : process(s_digit, s_digit_hex, i_7segm_data)
	begin
		if i_7segm_data(32) = '1' then
			case s_digit is
				when "00" => o_7segm <= not i_7segm_data(7 downto 0);
				when "01" => o_7segm <= not i_7segm_data(15 downto 8);
				when "10" => o_7segm <= not i_7segm_data(23 downto 16);
				when others => o_7segm <= not i_7segm_data(31 downto 24);
			end case;
		else
			case s_digit_hex is
				when "0001" => o_7segm <= "11001111";
				when "0010" => o_7segm <= "10010010";
				when "0011" => o_7segm <= "10000110";
				when "0100" => o_7segm <= "11001100";
				when "0101" => o_7segm <= "10100100";
				when "0110" => o_7segm <= "10100000";
				when "0111" => o_7segm <= "10001111";
				when "1000" => o_7segm <= "10000000";
				when "1001" => o_7segm <= "10000100";
				when "1010" => o_7segm <= "10000010";
				when "1011" => o_7segm <= "11100000";
				when "1100" => o_7segm <= "10110001";
				when "1101" => o_7segm <= "11000010";
				when "1110" => o_7segm <= "10110000";
				when "1111" => o_7segm <= "10111000";
				when others => o_7segm <= "10000001";
			end case;
		end if;
	end process;

end Behavioral;
