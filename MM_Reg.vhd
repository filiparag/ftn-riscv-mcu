library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity MM_Reg is
	generic (
		REG_ADDR:	integer := 16#0#;
		REG_SIZE:	integer := 16#20#;
		REG_INPUT:	boolean := false
  );
	port (
		i_Clk       : in  std_logic;
		i_Rstn		: in  std_logic;
		i_wb_cyc	 	: in  std_logic;
		i_wb_stb	 	: in  std_logic;
		i_wb_we	 	: in  std_logic;
		i_wb_addr	: in  std_logic_vector(31 downto 0);
		i_wb_data	: in  std_logic_vector(31 downto 0);
		i_wb_sel	 	: in  std_logic_vector( 3 downto 0);
		o_wb_stall  : out std_logic;
		o_wb_ack	 	: out std_logic;
		o_wb_data	: out std_logic_vector(31 downto 0);
		s_reg			: inout std_logic_vector(REG_SIZE - 1 downto 0)
	);
end entity;

architecture rtl of MM_Reg is
	signal s_data : std_logic_vector(REG_SIZE - 1 downto 0);
	signal s_wb_ack: std_logic;
	
begin

	s_reg <= s_data;

	r: process(i_Clk, i_Rstn)
	begin
		if i_Rstn = '0' then
			s_data <= (others => '0');
		elsif rising_edge(i_Clk) then
			if i_wb_we = '1' and i_wb_sel /= "0000" then
				if i_wb_addr = std_logic_vector(to_unsigned(REG_ADDR, 32)) then
					s_data <= i_wb_data(REG_SIZE - 1 downto 0);
				else
					s_data <= s_data;
				end if;
			end if;
		end if;
		
	end process;

	process(i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_wb_ack <= '0';
		elsif(rising_edge(i_Clk)) then
			s_wb_ack <= i_wb_stb and i_wb_cyc;
		end if;
	end process;
	
	o_wb_ack <= s_wb_ack;
	o_wb_data(REG_SIZE - 1 downto 0) <= s_data;
	o_wb_data(31 downto REG_SIZE) <= (others => '0');
	o_wb_stall <= '0';
	
end architecture;