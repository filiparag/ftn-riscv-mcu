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
		i_timer_int : in std_logic_vector(31 downto 0);
		o_timer_ev : out std_logic_vector(g_TIMER_COUNT - 1 downto 0);
		o_runtime_ns : out std_logic_vector(63 downto 0);
		o_runtime_us : out std_logic_vector(63 downto 0);
		o_runtime_ms : out std_logic_vector(63 downto 0)
	);
end Timers;

architecture Behavioral of Timers is

	constant c_scale : positive := 1000;

	signal s_runtime_ns : std_logic_vector(63 downto 0);
	signal s_runtime_us : std_logic_vector(63 downto 0);
	signal s_runtime_ms : std_logic_vector(63 downto 0);
	
	signal s_elapsed_us : std_logic;
	signal s_elapsed_ms : std_logic;
	
	signal s_countdown_us : std_logic_vector(9 downto 0);
	signal s_countdown_ms : std_logic_vector(9 downto 0);

begin	
	
	o_runtime_ns <= s_runtime_ns;
	o_runtime_us <= s_runtime_us;
	o_runtime_ms <= s_runtime_ms;
	
	s_elapsed_us <= '1' when s_countdown_us < g_NANOS_PER_CLK else '0';
	s_elapsed_ms <= '1' when s_countdown_ms = 0 else '0';
		
	elapsed_us : process(clk, rst_n)
	begin
		if rst_n = '0' then
			s_countdown_us <= std_logic_vector(to_unsigned(c_scale, s_countdown_us'length));
		elsif rising_edge(clk) then
			if s_countdown_us >= g_NANOS_PER_CLK then
				s_countdown_us <= s_countdown_us - g_NANOS_PER_CLK;
			else
				s_countdown_us <= std_logic_vector(to_unsigned(c_scale, s_countdown_us'length));
			end if;
		end if;
	end process;
	
	elapsed_ms : process(clk, rst_n)
	begin
		if rst_n = '0' then
			s_countdown_ms <= std_logic_vector(to_unsigned(c_scale, s_countdown_us'length));
		elsif rising_edge(clk) then
			if s_countdown_ms > 0 then
				s_countdown_ms <= s_countdown_ms - s_elapsed_us;
			else
				s_countdown_ms <= std_logic_vector(to_unsigned(c_scale, s_countdown_us'length));
			end if;
		end if;
	end process;
	
	runtime : process(clk, rst_n)
	begin
		if rst_n = '0' then
			s_runtime_ns <= (others => '0');
			s_runtime_us <= (others => '0');
			s_runtime_ms <= (others => '0');
		elsif rising_edge(clk) then
			s_runtime_ns <= s_runtime_ns + g_NANOS_PER_CLK;
			s_runtime_us <= s_runtime_us + s_elapsed_us;
			s_runtime_ms <= s_runtime_ms + s_elapsed_ms;
		end if;
	end process;

	timers : for i in 0 to g_TIMER_COUNT-1 generate
		signal s_timer_i_int : std_logic_vector(31 downto 0);
		signal s_timer_i_us : std_logic_vector(31 downto 0) := (others => '0');
	begin
	
		o_timer_ev(i) <= '1' when s_timer_i_us = 0 and rst_n = '1' else '0';
	
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
	
		timer_i :  process(clk, rst_n)
		begin
			if rst_n = '0' then
				s_timer_i_us <= s_timer_i_int;
			elsif rising_edge(clk) then
				if i_timer_rst(i) = '1' or s_timer_i_us = 0 then
					s_timer_i_us <= s_timer_i_int;
				else
					s_timer_i_us <= s_timer_i_us - s_elapsed_us;
				end if;
			end if;
		end process;
		
	end generate;

end Behavioral;
