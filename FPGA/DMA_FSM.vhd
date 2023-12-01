library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

entity DMA_FSM is
  port (
    i_Clk       : in  std_logic;	
    i_Rstn 		 : in  std_logic;
    i_Data_Valid: in  std_logic;
	 i_UART_Data : in  std_logic_vector(7 downto 0);
	 i_Mem_Data  : in  std_logic_vector(31 downto 0);
	 i_TX_Active : in  std_logic;
	 o_Data		 : out std_logic_vector(31 downto 0);
	 o_Byte		 : out std_logic_vector(7 downto 0);
	 o_Data_Valid: out std_logic;
	 o_Address	 : out std_logic_vector(31 downto 0);
    o_WE   		 : out std_logic
    );
end entity;

architecture rtl of DMA_FSM is

	type t_state is (START, DATA_SIZE, START_ADDRESS, WRITE_DATA, SEND, 
						  READ_DATA, PASS_THROUGH, RETRIEVE);
	signal s_state 				: t_state := START;
	signal s_next_state 			: t_state;
	
	constant c_write_cmd 		: std_logic_vector(7 downto 0) := "10000000";
	constant c_read_cmd  		: std_logic_vector(7 downto 0) := "01000000";
	
	signal s_address 				: std_logic_vector(31 downto 0);
	signal s_data 					: std_logic_vector(31 downto 0);
	signal s_byte 					: std_logic_vector(7 downto 0);
	signal s_cmd 					: std_logic_vector(7 downto 0);
	
	signal s_remaining_data		: std_logic_vector(23 downto 0);
	signal s_cnt_data_size 		: std_logic_vector(1 downto 0);
	signal s_cnt_start_addr 	: std_logic_vector(1 downto 0);
	signal s_counter_r 			: std_logic_vector(1 downto 0);
	signal s_counter_w 			: std_logic_vector(1 downto 0);
	
	signal s_decrease_size 			: std_logic;
	signal s_decrease_size_prev	: std_logic;
	signal s_increase_address		: std_logic;
	signal s_increase_address_prev: std_logic;
	
	signal s_tx_active 			: std_logic;
	signal s_tx_active_prev 	: std_logic;
	signal s_read_en 				: std_logic;
	signal s_dec_size_en			: std_logic;
	signal s_inc_addr_en			: std_logic;
	
	--------------------------- debug ----------------
	
	signal deb_data_size 		: std_logic_vector(23 downto 0);
	signal deb_address			: std_logic_vector(31 downto 0);
	signal deb_data				: std_logic_vector(31 downto 0);
	
	signal deb_mm_data			: std_logic_vector(31 downto 0);
	
	signal deb_state				: std_logic_vector(3 downto 0);
	
	signal deb_cnt_read_en		: std_logic_vector(7 downto 0);
	
	

begin

	-- counts 3 bytes which have the size of the data to be read/written
	counter_data_size : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_cnt_data_size <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(s_state = DATA_SIZE) then
				if(i_data_valid = '1') then
					if(s_cnt_data_size = 2) then
						s_cnt_data_size <= (others => '0');
					else
						s_cnt_data_size <= s_cnt_data_size + 1;
					end if;
				end if;
			else
				s_cnt_data_size <= (others => '0');
			end if;
		end if;
	end process;

	-- counts 4 bytes which represent the starting address for the data to be read/written
	counter_start_address : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_cnt_start_addr <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(s_state = START_ADDRESS) then
				if(i_data_valid = '1') then
					if(s_cnt_start_addr = 3) then
						s_cnt_start_addr <= (others => '0');
					else
						s_cnt_start_addr <= s_cnt_start_addr + 1;
					end if;
				end if;
			else
				s_cnt_start_addr <= (others => '0');
			end if;
		end if;
	end process;
	
	r_enable1 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_tx_active <= '0';
		elsif(rising_edge(i_Clk)) then
			s_tx_active <= i_TX_Active;
		end if;			
	end process;
	
	
	r_enable2 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_tx_active_prev <= '0';
		elsif(rising_edge(i_Clk)) then
			s_tx_active_prev <= s_tx_active;
		end if;			
	end process;
	
	r_size_enable1 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_decrease_size <= '0';
		elsif(rising_edge(i_Clk)) then
			if(s_state = SEND or s_STATE = RETRIEVE) then
				s_decrease_size <= '1';
			else
				s_decrease_size <= '0';
			end if;
		end if;			
	end process;
	
	r_size_enable2 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_decrease_size_prev <= '0';
		elsif(rising_edge(i_Clk)) then
			s_decrease_size_prev <= s_decrease_size;
		end if;			
	end process;
	
	r_addr_enable1 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_increase_address <= '0';
		elsif(rising_edge(i_Clk)) then
			if(s_state = SEND or s_STATE = PASS_THROUGH) then
				s_increase_address <= '1';
			else
				s_increase_address <= '0';
			end if;
		end if;			
	end process;
	
	r_addr_enable2 : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_increase_address_prev <= '0';
		elsif(rising_edge(i_Clk)) then
			s_increase_address_prev <= s_increase_address;
		end if;			
	end process;
	
	-- so that these processes happen only once per state
	s_read_en <= '1' when (s_tx_active = '1' and s_tx_active_prev = '0') else '0';
	s_dec_size_en <= '1' when (s_decrease_size = '1' and s_decrease_size_prev = '0') else '0';
	s_inc_addr_en <= '1' when (s_increase_address = '1' and s_increase_address_prev = '0') else '0';
	
	-- sending data to TX
	counter_r : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_counter_r <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if (s_state = RETRIEVE) then
				if(s_read_en = '1') then
					s_counter_r <= s_counter_r + 1;
				end if;
			else
				s_counter_r <= (others => '0');	
			end if;
		end if;
	end process;

	-- receiveing data from RX
	counter_w : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_counter_w <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(s_state = WRITE_DATA) then
				if(i_data_valid = '1') then
					if(s_counter_w = 3) then
						s_counter_w <= (others => '0');
					else
						s_counter_w <= s_counter_w + 1;
					end if;
				else
					s_counter_w <= s_counter_w;
				end if;
			else
				s_counter_w <= (others => '0');
			end if;
		end if;
	end process;	

	fsm_reg : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_state <= START;
		elsif(rising_edge(i_Clk)) then
			s_state <= s_next_state;
		end if;
	end process;

	fsm_transition : process (s_state, s_counter_w, i_data_valid, i_UART_Data, s_cmd, s_counter_r,
						s_cnt_data_size, s_cnt_start_addr, s_remaining_data, s_read_en)
	begin
		case(s_state) is
			
			when START =>
				if(i_data_valid = '1') then
					if(i_UART_Data = c_write_cmd or i_UART_Data = c_read_cmd) then	-- write / read command
						s_next_state <= DATA_SIZE;			
					else
						s_next_state <= START;
					end if;
				else
					s_next_state <= START;
				end if;
				
			when DATA_SIZE =>
				if(i_data_valid = '1') then
					if(s_cnt_data_size = 2)	then		-- 3th byte of data size
						s_next_state <= START_ADDRESS;
					else
						s_next_state <= DATA_SIZE;		-- something is wrong
					end if;
				else
					s_next_state <= DATA_SIZE;
				end if;
				
			when START_ADDRESS =>
				if(i_data_valid = '1') then
					if(s_cnt_start_addr = 3)	then		-- 4th byte of address
						if(s_cmd = c_write_cmd) then
							s_next_state <= WRITE_DATA;
						elsif(s_cmd = c_read_cmd) then
							s_next_state <= READ_DATA;
						else
							s_next_state <= START;		-- something is wrong, restart
						end if;
					else
						s_next_state <= START_ADDRESS;
					end if;
				else
					s_next_state <= START_ADDRESS;
				end if;
				
			when WRITE_DATA => 								
				if(i_data_valid = '1') then
					if(s_counter_w = 3) then					-- 1 word
						s_next_state <= SEND;
					else
						s_next_state <= WRITE_DATA;
					end if;
				else
					s_next_state <= WRITE_DATA;
				end if;
				
			when SEND =>
				-- activate signals
				if(s_remaining_data = 4) then				
					s_next_state <= START;
				else
					s_next_state <= WRITE_DATA;
				end if;
			
			when READ_DATA =>
				s_next_state <= PASS_THROUGH;
				
			when PASS_THROUGH =>								
				s_next_state <= RETRIEVE;
							
			when RETRIEVE =>									
				if (s_counter_r = 3 and s_read_en = '1') then	
					if(s_remaining_data = 0) then			
						s_next_state <= START;
					else
						s_next_state <= READ_DATA;
					end if;
				else
					s_next_state <= RETRIEVE;
				end if;
		end case;
	end process;

	-- FSM output function
	o_Data_Valid 		<= '1' when s_state = RETRIEVE else '0';
--	o_WE 					<= '1' when s_state = WRITE_DATA or s_state = SEND else '0';
	o_WE 					<= '1' when s_state = SEND else '0';
	o_Byte 				<= s_data(7 downto 0);

	fsm_output : process (s_state, s_data, s_Address)
	begin
		
		case(s_state) is
			when WRITE_DATA =>
				o_Data 		<= s_data;
				o_Address 	<= s_Address;
			when SEND =>								
				o_Data 		<= s_data;
				o_Address 	<= s_Address;
			when READ_DATA =>
				o_Data 		<= (others => '0');
				o_Address 	<= s_Address;
			when PASS_THROUGH =>
				o_Data 		<= (others => '0');
				o_Address 	<= s_Address;
			when RETRIEVE =>
				o_Data 		<= s_data;
				o_Address 	<= (others => '0');
			when others =>
				o_Data 		<= (others => '0');
				o_Address 	<= (others => '0');
		end case;	
	end process;
	
	cmd_reg : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_cmd <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(s_state = START) then
				if(i_data_valid = '1') then
					s_cmd <= i_UART_Data;
				else
					s_cmd <= s_cmd;
				end if;
			end if;
		end if;
	end process;
	

	remaining_data_reg : process (i_Clk, i_Rstn) 	-- how much data is there to read / write
	begin
		if(i_Rstn = '0') then
			s_remaining_data <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(s_state = DATA_SIZE) then
				if(i_data_valid = '1' and s_cnt_data_size < 3) then
					s_remaining_data <= i_UART_Data & s_remaining_data(23 downto 8);
				else
					s_remaining_data <= s_remaining_data;
				end if;
			else
				if(s_dec_size_en = '1') then
					s_remaining_data <= s_remaining_data - 4;	
				end if;
			end if;
		end if;
	end process;
	
	addr_reg : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_address <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(s_state = START_ADDRESS) then
				if(i_data_valid = '1') then
					s_address <= i_UART_Data & s_address(31 downto 8);
				else
					s_address <= s_address;
				end if;
			else
				if(s_inc_addr_en = '1') then
					s_address <= s_address + 4;
				end if;
			end if;
		end if;
	end process;
	
	data_reg : process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_data <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(i_data_valid = '1' and s_state = WRITE_DATA) then		-- if write / read drugacije je
				s_data <= i_UART_Data & s_data(31 downto 8);
			elsif(s_state = PASS_THROUGH) then
				s_data <= i_Mem_Data;
			elsif(s_state = RETRIEVE and s_read_en = '1') then
				s_data <= x"00" & s_data(31 downto 8);		
			else
				s_data <= s_data;
			end if;
		end if;
	end process;
	
end architecture;