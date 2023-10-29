library ieee;
use ieee.std_logic_1164.all;

entity DBG_Reg is
  port (
    i_Clk       : in  std_logic;
    i_Rstn 		 : in  std_logic;
	 i_Data		 : in  std_logic;
	 o_Data		 : out std_logic
    );
end entity;

architecture rtl of DBG_Reg is
	
	signal s_data : std_logic;
	
begin 

	reg : process(i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_data <= '0';
		elsif(rising_edge(i_Clk)) then
				s_data <= i_Data;
		end if;
	end process;

	o_Data <= s_data;
	
end architecture;