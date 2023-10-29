library ieee;
use ieee.std_logic_1164.all;

entity HOLD_Reg is
  port (
    i_Clk       : in  std_logic;
    i_Rstn 		 : in  std_logic;
	 i_WE 		 : in  std_logic;
	 o_Data		 : out std_logic
    );
end entity;

architecture rtl of HOLD_Reg is
	
	signal s_data : std_logic;
	
begin 

	reg : process(i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_data <= '0';
		elsif(rising_edge(i_Clk)) then
			if(i_WE = '1') then
		--	if(i_WE = '0') then			-- SDRAM CHECK
				s_data <= '1';
			end if;
		end if;
	end process;

	o_Data <= s_data;
	
end architecture;