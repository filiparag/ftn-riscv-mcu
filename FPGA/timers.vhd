library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

entity Timers is
	generic (
		g_NANOS_PER_CLK : positive := 20;
		g_TIMER_COUNT : positive := 4
	);
	port (
		clk : in std_logic;
		rst_n : in std_logic;
		i_timer_rst : in std_logic_vector(g_TIMER_COUNT - 1 downto 0);
		i_timer_sel : in std_logic_vector(positive(ceil(log2(real(g_TIMER_COUNT)))) - 1 downto 0);
		i_timer_int : in std_logic_vector(63 downto 0);
		o_timer_ev : out std_logic_vector(g_TIMER_COUNT - 1 downto 0);
		o_runtime_ns : out std_logic_vector(63 downto 0)
	);
end Timers;

architecture Behavioral of Timers is

	signal s_runtime_nanos : std_logic_vector(63 downto 0);

begin	
	
	o_runtime_ns <= s_runtime_nanos;
	
	runtime_counter : process(clk, rst_n)
	begin
		if rst_n = '0' then
			s_runtime_nanos <= (others => '0');
		elsif rising_edge(clk) then
			s_runtime_nanos <= s_runtime_nanos + g_NANOS_PER_CLK;
		end if;
	end process;
	
	timers : for i in 0 to g_TIMER_COUNT-1 generate
		signal s_timer_i_int : std_logic_vector(63 downto 0);
		signal s_timer_i_nanos : std_logic_vector(63 downto 0);
	begin
	
		o_timer_ev(i) <= '1' when unsigned(s_timer_i_nanos) < g_NANOS_PER_CLK and rst_n = '1' else '0';
	
		interval_i :  process(clk, rst_n)
		begin
			if rst_n = '0' then
				s_timer_i_int <= (others => '1');
			elsif rising_edge(clk) then
				if i_timer_sel = i then
					s_timer_i_int <= i_timer_int;
				end if;
			end if;
		end process;
	
		timer_i :  process(clk, rst_n, s_timer_i_int)
		begin
			if rst_n = '0' then
				s_timer_i_nanos <= s_timer_i_int;
			elsif rising_edge(clk) then
				if i_timer_rst(i) = '1' then
					s_timer_i_nanos <= s_timer_i_int;
				elsif unsigned(s_timer_i_nanos) < g_NANOS_PER_CLK then
					s_timer_i_nanos <= s_timer_i_int;
				else
					s_timer_i_nanos <= s_timer_i_nanos - g_NANOS_PER_CLK;
				end if;
			end if;
		end process;
		
	end generate;

end Behavioral;
