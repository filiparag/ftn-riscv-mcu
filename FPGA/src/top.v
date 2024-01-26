`timescale 1 ns / 1 ps

module top (
	input   			i_clk,
	input				i_rst,

	// LPRS1 GPIO
	input	  [7:0]	i_sw,
	input	  [4:0]	i_pb, // 0bcenter_right_left_down_up
	output  [7:0]	o_led,
	output  [7:0]	o_n_col_or_7segm, // 0bDpABCDEFG
	output  [2:0]	o_mux_row_or_digit,
	output  [1:0]	o_mux_sel_color_or_7segm, // RGB7segm
	output  [2:0]	o_sem,

	// Internal UART
	input  			i_serial_rx,
	output 			o_serial_tx,
	output 			o_serial_ndsr,
	output 			o_serial_ncts,
	input 			i_serial_nrts,
	input 			i_serial_ndtr,

	// External UART
	input 			i_uart_rx,
	output 			o_uart_tx,

	// SDRAM
	output			o_ram_clk,
	output			o_ram_cs_n,
	output			o_ram_cke,
	output			o_ram_ras_n,
	output			o_ram_cas_n,
	output			o_ram_we_n,
	output  [1:0]	o_ram_bs,
	output [11:0]	o_ram_addr,
	inout	 [15:0] 	io_ram_data,
	output  [1:0]	o_ram_dqm
);

	// Synchronization

	wire 			s_nrst;
	wire			s_clk_sys;
	wire			s_clk_sdram;
	reg			s_rst_proc;
	reg			s_rst_rom;
	reg			s_rst_ram;

	//////////////
	// Wishbone //
	//////////////

	// Wishbone interface signals

	wire [31:0]	s_wbm_adr_o;
	wire [31:0] s_wbm_dat_o;
	wire [31:0] s_wbm_dat_i;
	wire [31:0] s_wbm_bram_dat_i;
	wire [31:0] s_wbm_sdram_dat_i;
	wire 			s_wbm_we_o;
	wire  [3:0] s_wbm_sel_o;
	wire 			s_wbm_stb_o;
	wire 			s_wbm_ack_i;
	wire 			s_wbm_cyc_o;

	//  Wishbone BROM

	wire			s_wb_brom_cyc;
	wire			s_wb_brom_stb;
	wire			s_wb_brom_we;
	wire [31:0] s_wb_brom_addr;
	wire [31:0] s_wb_brom_data_i;
	wire  [3:0]	s_wb_brom_sel;
	wire			s_wb_brom_stall;
	wire			s_wb_brom_ack;
	wire [31:0]	s_wb_brom_data_o;

	// Wishbone BRAM

	wire			s_wb_bram_cyc;
	wire			s_wb_bram_stb;
	wire			s_wb_bram_we;
	wire [31:0] s_wb_bram_addr;
	wire [31:0] s_wb_bram_data_i;
	wire	[3:0] s_wb_bram_sel;
	wire			s_wb_bram_stall;
	wire			s_wb_bram_ack;
	wire [31:0]	s_wb_bram_data_o;

	//  Wishbone MMAP

	wire			s_wb_mmap_cyc;
	wire			s_wb_mmap_stb;
	wire			s_wb_mmap_we;
	wire [31:0] s_wb_mmap_addr;
	wire [31:0] s_wb_mmap_data_i;
	wire  [3:0]	s_wb_mmap_sel;
	wire			s_wb_mmap_stall;
	wire			s_wb_mmap_ack;
	wire [31:0]	s_wb_mmap_data_o;

	// Wishbone SDRAM

	wire			s_wb_sdram_cyc;
	wire			s_wb_sdram_stb;
	wire			s_wb_sdram_we;
	wire [20:0] s_wb_sdram_addr;
	wire [31:0] s_wb_sdram_data_i;
	wire	[3:0] s_wb_sdram_sel;
	wire			s_wb_sdram_stall;
	wire			s_wb_sdram_ack;
	wire [31:0]	s_wb_sdram_data_o;

	///////////
	// SDRAM //
	///////////

	wire 			s_o_ram_cs_n;
	wire 			s_o_ram_cke;
	wire 			s_o_ram_ras_n;
	wire 			s_o_ram_cas_n;
	wire 			s_o_ram_we_n;

	wire 			s_o_ram_dmod;
	wire [15:0] s_i_ram_data;
	wire [15:0] s_o_ram_data;
	wire [31:0] s_o_debug;
	wire  [1:0] s_o_ram_bs;
	wire  [1:0] s_o_ram_dqm;

	wire			s_ram_cs_n;
	wire			s_ram_cke;
	wire			s_ram_ras_n;
	wire			s_ram_cas_n;
	wire [1:0]	s_ram_bs;
	wire [11:0]	s_ram_addr;
	wire [1:0]  s_ram_dqm;

	assign io_ram_data 	= !s_o_ram_we_n ? s_o_ram_data : 16'bZ;
	assign s_i_ram_data 	= io_ram_data;
	assign o_ram_we_n		= s_o_ram_we_n;
	assign o_ram_clk		= s_clk_sdram;

	assign o_ram_cs_n		= s_ram_cs_n;
	assign o_ram_cke 		= s_ram_cke;
	assign o_ram_ras_n	= s_ram_ras_n;
	assign o_ram_cas_n	= s_ram_cas_n;
	assign o_ram_bs		= s_ram_bs;
	assign o_ram_addr		= s_ram_addr;
	assign o_ram_dqm		= s_ram_dqm;

	//////////////
	// PicoRV32 //
	//////////////

	// IRQ interface
	wire [31:0] s_irq;
	wire [31:0] s_eoi;

	// Other
	wire			s_trace_valid;
	wire [35:0] s_trace_data;
	wire 			mem_instr;

	picorv32_wb #(
		.COMPRESSED_ISA	(0),
		.ENABLE_PCPI		(0),
		.ENABLE_MUL			(1),
		.ENABLE_FAST_MUL	(1),
		.ENABLE_DIV			(1),
		.BARREL_SHIFTER	(1),
		.REGS_INIT_ZERO	(1),
		.PROGADDR_RESET	(32'h 0001_0000), // BROM
		.STACKADDR			(32'h 0000_bffc), // BRAM
		.ENABLE_IRQ			(1),
		.MASKED_IRQ			(32'h 0000_0000), // Enable all
		.LATCHED_IRQ		(32'h ffff_ffff), // Latch all
		.PROGADDR_IRQ		(32'h 0001_0060) // BROM
	) picorv32(
		.wb_rst_i			(s_rst_proc),
		.wb_clk_i			(s_clk_sys),
		.trap					(trap),
		// Wishbone interface
		.wbm_adr_o			(s_wbm_adr_o),
		.wbm_dat_o			(s_wbm_dat_o),
		.wbm_dat_i			(s_wbm_dat_i),
		.wbm_we_o			(s_wbm_we_o	),
		.wbm_sel_o			(s_wbm_sel_o),
		.wbm_stb_o			(s_wbm_stb_o),
		.wbm_ack_i			(s_wbm_ack_i),
		.wbm_cyc_o			(s_wbm_cyc_o),
		// Pico Co-Processor Interface
		.pcpi_valid 		(s_pcpi_valid),
		.pcpi_insn			(s_pcpi_insn),
		.pcpi_rs1			(s_pcpi_rs1),
		.pcpi_rs2			(s_pcpi_rs2),
		.pcpi_wr				(s_pcpi_wr),
		.pcpi_rd				(s_pcpi_rd),
		.pcpi_wait			(s_pcpi_wait),
		.pcpi_ready			(s_pcpi_ready),
		// IRQ interface
		.irq					(s_irq),
		.eoi					(s_eoi),
		//Other
		.trace_valid		(s_trace_valid),
		.trace_data			(s_trace_data),
		.mem_instr			(mem_instr)
	);

	WB_slave_arbiter arbiter (
		.i_wb_cyc			(s_wbm_cyc_o),
		.i_wb_stb			(s_wbm_stb_o),
		.i_wb_we				(s_wbm_we_o),
		.i_wb_addr			(s_wbm_adr_o),
		.i_wb_data			(s_wbm_dat_o),
		.i_wb_sel			(s_wbm_sel_o),
		.o_wb_stall			(s_stall),
		.o_wb_ack			(s_wbm_ack_i),
		.o_wb_data			(s_wbm_dat_i),
		// BRAM
		.o_wb_bram_cyc		(s_wb_bram_cyc),
		.o_wb_bram_stb		(s_wb_bram_stb),
		.o_wb_bram_we		(s_wb_bram_we),
		.o_wb_bram_addr	(s_wb_bram_addr),
		.o_wb_bram_data	(s_wb_bram_data_o),
		.o_wb_bram_sel		(s_wb_bram_sel),
		.i_wb_bram_stall	(s_wb_bram_stall),
		.i_wb_bram_ack		(s_wb_bram_ack),
		.i_wb_bram_data	(s_wb_bram_data_i),
		// SDRAM
		.o_wb_sdram_cyc	(s_wb_sdram_cyc),
		.o_wb_sdram_stb	(s_wb_sdram_stb),
		.o_wb_sdram_we		(s_wb_sdram_we),
		.o_wb_sdram_addr	(s_wb_sdram_addr),
		.o_wb_sdram_data	(s_wb_sdram_data_o),
		.o_wb_sdram_sel	(s_wb_sdram_sel),
		.i_wb_sdram_stall	(s_wb_sdram_stall),
		.i_wb_sdram_ack	(s_wb_sdram_ack),
		.i_wb_sdram_data	(s_wb_sdram_data_i),
		// MMAP
	   .o_wb_mmap_cyc		(s_wb_mmap_cyc),
		.o_wb_mmap_stb		(s_wb_mmap_stb),
		.o_wb_mmap_we		(s_wb_mmap_we),
		.o_wb_mmap_addr	(s_wb_mmap_addr),
		.o_wb_mmap_data	(s_wb_mmap_data_o),
		.o_wb_mmap_sel		(s_wb_mmap_sel),
		.i_wb_mmap_stall	(s_wb_mmap_stall),
		.i_wb_mmap_ack		(s_wb_mmap_ack),
		.i_wb_mmap_data	(s_wb_mmap_data_i),
		// BROM
	   .o_wb_brom_cyc		(s_wb_brom_cyc),
		.o_wb_brom_stb		(s_wb_brom_stb),
		.o_wb_brom_we		(s_wb_brom_we),
		.o_wb_brom_addr	(s_wb_brom_addr),
		.o_wb_brom_data	(s_wb_brom_data_o),
		.o_wb_brom_sel		(s_wb_brom_sel),
		.i_wb_brom_stall	(s_wb_brom_stall),
		.i_wb_brom_ack		(s_wb_brom_ack	),
		.i_wb_brom_data	(s_wb_brom_data_i)
   );

	MEM_BRAM bram (
		.clk 					(s_clk_sys),
		.rst_n       		(~s_rst_ram),
		.i_wb_cyc	 		(s_wb_bram_cyc),
		.i_wb_stb	 		(s_wb_bram_stb),
		.i_wb_we	 	 		(s_wb_bram_we),
		.i_wb_addr	 		(s_wb_bram_addr),
		.i_wb_data	 		(s_wb_bram_data_o),
		.i_wb_sel	 		(s_wb_bram_sel),
		.o_wb_stall  		(s_wb_bram_stall),
		.o_wb_ack	 		(s_wb_bram_ack),
		.o_wb_data	 		(s_wb_bram_data_i),
	);

	MEM_BROM brom (
		.clk       			(s_clk_sys),
		.rst_n     			(~s_rst_rom),
		.i_wb_cyc	 		(s_wb_brom_cyc),
		.i_wb_stb	 		(s_wb_brom_stb),
		.i_wb_we	 	 		(s_wb_brom_we),
		.i_wb_addr	 		(s_wb_brom_addr),
		.i_wb_data	 		(s_wb_brom_data_o),
		.i_wb_sel	 		(s_wb_brom_sel),
		.o_wb_stall  		(s_wb_brom_stall),
		.o_wb_ack	 		(s_wb_brom_ack),
		.o_wb_data	 		(s_wb_brom_data_i),
	);

	Peripherals mmap (
		.clk       			(s_clk_sys),
		.rst_n      		(s_nrst),
		.i_wb_cyc	 		(s_wb_mmap_cyc),
		.i_wb_stb	 		(s_wb_mmap_stb),
		.i_wb_we	 	 		(s_wb_mmap_we),
		.i_wb_addr	 		(s_wb_mmap_addr),
		.i_wb_data	 		(s_wb_mmap_data_o),
		.i_wb_sel	 		(s_wb_mmap_sel),
		.o_wb_stall  		(s_wb_mmap_stall),
		.o_wb_ack	 		(s_wb_mmap_ack),
		.o_wb_data	 		(s_wb_mmap_data_i),
		// GPIO
		.o_led 				(o_led),
		.o_sem 				(o_sem),
		.o_mux_sel_color_or_7segm
								(o_mux_sel_color_or_7segm),
		.o_n_col_or_7segm (o_n_col_or_7segm),
		.o_mux_row_or_digit
								(o_mux_row_or_digit),
		.i_sw 				(i_sw),
		.i_pb					(i_pb),
		// UART
		.i_uart0_rx 		(i_serial_rx),
		.o_uart0_tx 		(o_serial_tx),
		.o_uart0_ndsr 		(o_serial_ndsr),
		.o_uart0_ncts 		(o_serial_ncts),
		.i_uart0_nrts 		(i_serial_nrts),
		.i_uart0_ndtr 		(i_serial_ndtr),
		.i_uart1_rx 		(i_uart_rx),
		.o_uart1_tx 		(o_uart_tx),
		// IRQ
		.o_irq 				(s_irq),
		.i_eoi 				(s_eoi)
	);

	wbsdram sdram_ctrl (
		.i_clk				(s_clk_sys),
		.i_wb_cyc			(s_wb_sdram_cyc),
		.i_wb_stb			(s_wb_sdram_stb),
		.i_wb_we				(s_wb_sdram_we),
		.i_wb_addr			(s_wb_sdram_addr),
		.i_wb_data			(s_wb_sdram_data_o),
		.i_wb_sel			(s_wb_sdram_sel),
		.o_wb_stall			(s_wb_sdram_stall),
		.o_wb_ack			(s_wb_sdram_ack),
		.o_wb_data			(s_wb_sdram_data_i),
		.o_ram_cs_n			(s_ram_cs_n),
		.o_ram_cke			(s_ram_cke),
		.o_ram_ras_n		(s_ram_ras_n),
		.o_ram_cas_n		(s_ram_cas_n),
		.o_ram_we_n			(s_o_ram_we_n),
		.o_ram_bs			(s_ram_bs),
		.o_ram_addr			(s_ram_addr),
		.o_ram_dmod			(s_ram_dmod),
		.i_ram_data			(s_i_ram_data),
		.o_ram_data			(s_o_ram_data),
		.o_ram_dqm			(s_ram_dqm),
		.o_debug				(s_o_debug)
	);

	sdram_pll pll1 (
		.areset				(i_rst),
		.inclk0				(i_clk),
		.c0					(s_clk_sys),
		.c1					(s_clk_sdram),
		.locked				(s_nrst)
	);

	Reset_handler reset (
		.i_clk 				(i_clk),
		.i_nrst				(s_nrst),
		.i_serial_ndtr		(i_serial_ndtr),
		.i_serial_nrts		(i_serial_nrts),
		.o_rst_proc			(s_rst_proc),
		.o_rst_rom			(s_rst_rom),
		.o_rst_ram			(s_rst_ram)
	);

endmodule
