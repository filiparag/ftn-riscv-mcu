library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

entity Edge_catcher is
  port (
    i_Clk       : in  std_logic;	
    i_Rstn 		 : in  std_logic;
    i_Signal	 : in  std_logic;
	 
	 o_Signal 	 : out std_logic
    );
end entity;

architecture rtl of Edge_catcher is

	signal s_signal 		: std_logic;
	signal s_signal_prev	: std_logic;

begin

	r_enable1 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_signal <= '0';
		elsif(rising_edge(i_Clk)) then
			s_signal <= i_Signal;
		end if;			
	end process;
	
	
	r_enable2 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_signal_prev <= '0';
		elsif(rising_edge(i_Clk)) then
			s_signal_prev <= s_signal;
		end if;			
	end process;
	
	o_Signal <= '1' when (s_signal = '1' and s_signal_prev = '0') else '0';


end architecture;
