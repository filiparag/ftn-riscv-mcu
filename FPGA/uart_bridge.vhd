
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

library work;

entity uart_bridge is
	generic(
		-- Default frequency used in synthesis.
		constant CLK_FREQ : positive := 50000000
	);
	port(
		-- On MAX1000.
		-- System signals.
		i_clk                :  in std_logic;
		in_rst               :  in std_logic; -- Active low reset.
		
		-- UART as DCE.
		-- FT2232 as DTE.
		-- https://en.wikipedia.org/wiki/RS-232#Data_and_control_signals
		i_serial_rx          :  in std_logic; -- Data DTE -> DCE.
		o_serial_tx          : out std_logic; -- Data DTE <- DCE.
		on_serial_cts        : out std_logic; -- DCE ready to Rx.
		on_serial_dsr        : out std_logic; -- DCE ready to Rx and Tx.
		-- in_rts               :  in std_logic; -- DTE ready to Tx.
		-- in_dtr               :  in std_logic; -- DTE ready to Rx.
		
		i_byte_tx_data       :  in std_logic_vector(7 downto 0);
		i_byte_tx_valid      :  in std_logic;
		o_byte_tx_busy       : out std_logic;
		o_byte_rx_data       : out std_logic_vector(7 downto 0);
		o_byte_rx_valid      : out std_logic
		
	);
end entity;

architecture arch of uart_bridge is
	
	-- Config.
	constant BAUD_RATE : natural := 2000000;
--	constant BAUD_RATE : natural := 115200;
	
	-------------
	
	constant CLKS_PER_BIT : natural := 
		integer(round(real(CLK_FREQ)/real(BAUD_RATE)));
	
	signal dv   : std_logic;
	signal b    : std_logic_vector(7 downto 0);
	
begin
	
	on_serial_cts <= '0';
	on_serial_dsr <= '0';
	
	-- Instantiate UART Receiver
	uart_rx_i : entity work.uart_rx
	generic map (
		g_CLKS_PER_BIT => CLKS_PER_BIT
	)
	port map (
		i_clk       => i_clk,
		i_rx_serial => i_serial_rx,
		o_rx_dv     => dv,
		o_rx_byte   => b
	);
	
	o_byte_rx_data <= b;
	o_byte_rx_valid  <= dv;
	
	-- Instantiate UART transmitter
	uart_tx_i : entity work.uart_tx
	generic map (
		g_CLKS_PER_BIT => CLKS_PER_BIT
	)
	port map (
		i_clk       => i_clk,
		i_tx_dv     => i_byte_tx_valid,
		i_tx_byte   => i_byte_tx_data,
		o_tx_active => o_byte_tx_busy,
		o_tx_serial => o_serial_tx,
		o_tx_done   => open
	);

	
end architecture;
