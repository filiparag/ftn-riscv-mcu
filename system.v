`timescale 1 ns / 1 ps

//`define HOLD								// Hold or DBG registers
//`define SYM 

module system (
	input           	i_clk,
	input            	i_rst,
	output reg [7:0] 	o_led,
	
	input  i_serial_rx,
	output o_serial_tx,
	output on_serial_cts,
	output on_serial_dsr,
	
	// SDRAM
	output				o_ram_clk,	
	output				o_ram_cs_n,
	output				o_ram_cke,
	output				o_ram_ras_n,
	output				o_ram_cas_n,
	output				o_ram_we_n,
	output [1:0]		o_ram_bs,
	output [11:0]		o_ram_addr,
//	output  				o_ram_dmod,					
	inout [15:0] 		io_ram_data,
	output [1:0]  		o_ram_dqm,	
	output				locked,						//TODO remove
	output [1:0]		state							//TODO remove
);

	//moved here for simulation purposes
	wire 		s_o_ram_we_n;
	wire [15:0] s_o_ram_data;
//`ifdef SYM
//	reg			s_sdram_clk;
//	reg 		n_rst;
//	reg	 [5:0]	pll_clk;
//`else
//	wire		s_sdram_clk;
//	wire 		n_rst;
//`endif

	wire		s_sdram_clk;
	wire 		n_rst;
	
	wire  [1:0]	startup_state;						//TODO remove
	wire [15:0] s_i_ram_data;

	assign io_ram_data 	= !s_o_ram_we_n ? s_o_ram_data : 16'bZ;
	assign s_i_ram_data 	= io_ram_data;
	assign o_ram_we_n		= s_o_ram_we_n;
	assign o_ram_clk		= s_sdram_clk;

//`ifdef SYM
//	//fake pll locked
//	always @(posedge i_clk) begin
//		if(!i_rst) begin
//			n_rst 	 <= 0;
//			pll_clk  <= 0;
//		end else
//			if(pll_clk == 50) begin
//				n_rst <= 1;
//				pll_clk <= 50;
//			end 
//			else
//				pll_clk <= pll_clk + 1;
//	end
//`else	
//	assign locked			= n_rst;
//`endif
//	assign state			= startup_state;		//TODO remove
//	
//	//wire	[1:0]	startup_state;						//TODO remove
//
//`ifdef SYM
//	reg				s_sys_clk;
//`else	
//	wire			s_sys_clk;
//`endif
	
	// Wishbone interface signals -master2arbiter
	wire [31:0]	s_wbm_adr_o;
	wire [31:0] s_wbm_dat_o;
	wire [31:0] s_wbm_dat_i;
	wire [31:0] s_wbm_bram_dat_i;
	wire [31:0] s_wbm_sdram_dat_i;
	wire 			s_wbm_we_o;
	wire [3:0] 	s_wbm_sel_o;
	wire 			s_wbm_stb_o;
	wire 			s_wbm_ack_i;
	wire 			s_wbm_cyc_o;
	// Wishbone BROM (NEW)
	wire			s_wb_rom_cyc;
	wire			s_wb_rom_stb;
	wire			s_wb_rom_we;
	wire [31:0] s_wb_rom_addr;
	wire [31:0] s_wb_rom_data_i;
	wire	[3:0] s_wb_rom_sel;
	wire			s_wb_rom_stall;
	wire			s_wb_rom_ack;
	wire [31:0]	s_wb_rom_data_o;
	// Wishbone BRAM (fast ram)
	wire			s_wb_bram_cyc;
	wire			s_wb_bram_stb;
	wire			s_wb_bram_we;
	wire [31:0] s_wb_bram_addr;
	wire [31:0] s_wb_bram_data_i;
	wire	[3:0] s_wb_bram_sel;
	wire			s_wb_bram_stall;
	wire			s_wb_bram_ack;
	wire [31:0]	s_wb_bram_data_o;
	// Wishbone SDRAM (slow ram)
	wire			s_wb_sdram_cyc;
	wire			s_wb_sdram_stb;
	wire			s_wb_sdram_we;
	wire [20:0] s_wb_sdram_addr;
	wire [31:0] s_wb_sdram_data_i;
	wire	[3:0] s_wb_sdram_sel;
	wire			s_wb_sdram_stall;
	wire			s_wb_sdram_ack;
	wire [31:0]	s_wb_sdram_data_o;
	//  Wishbone MM REG 
	wire		s_wb_mmreg_cyc;
	wire		s_wb_mmreg_stb;
	wire		s_wb_mmreg_we;
	wire [31:0] s_wb_mmreg_addr;	
	wire [31:0] s_wb_mmreg_data_i;
	wire [3:0] 	s_wb_mmreg_sel;
	wire		s_wb_mmreg_stall;
	wire		s_wb_mmreg_ack;
	wire [31:0]	s_wb_mmreg_data_o;
	// SDRAM control signals
	wire s_o_ram_cs_n;
	wire s_o_ram_cke;
	wire s_o_ram_ras_n;
	wire s_o_ram_cas_n;
	//wire s_o_ram_we_n;
	
	wire [1:0] s_o_ram_bs;
	wire s_o_ram_dmod;
	//wire [15:0] s_i_ram_data;
	//wire [15:0] s_o_ram_data;
	wire [1:0] s_o_ram_dqm;
	wire [31:0] s_o_debug;
	
	wire			startup_hold;
	//wire 			n_rst;
	
	// Pico Co-Processor Interface
	wire 			s_pcpi_valid;
	wire [31:0] s_pcpi_insn;
	wire [31:0] s_pcpi_rs1;
	wire [31:0] s_pcpi_rs2;
	wire			s_pcpi_wr;
	wire [31:0] s_pcpi_rd;
	wire			s_pcpi_wait;
	wire			s_pcpi_ready;
		
	// IRQ interface
	wire [31:0] s_irq;
	wire [31:0] s_eoi;
	
	// Other
	wire			s_trace_valid;
	wire [35:0] s_trace_data;
	wire 			mem_instr;

	// Check and group the rest
	wire 			mem_valid;
	wire 			mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [31:0] o_dma_data;	
	wire  [3:0] mem_wstrb;

//	// UART signals		-- TODO: Rename to remove confusion
//	wire 			data_valid_w;
//	wire 			o_dma_data_valid;
//	wire 			s_tx_active;
//	wire  [7:0] s_data_byte_write;
//	wire  [7:0] o_dma_byte_read;
//	wire [31:0] o_dma_address;
//	wire [31:0] s_data;
//	wire [31:0] mem_rdata;
//	wire [31:0] o_mm_data;
//	wire 			o_dma_mem_we;
	
	// Other signals
	wire 			rst_proc;			//manually reset the processor from rst reg
	wire  [3:0] const_wstrb = 15;
	
	// Debug	
	wire  [7:0] s_led7_0;
	
	wire 			s_led7;
	wire 			s_led6;
	wire  		s_led5;
	wire 			s_led4;
	wire 			s_led3;
	wire 			s_led2;
	wire 			s_led1;
	wire 			s_led0;
	
	wire 			s_edge_catch;
	
	wire			s_ram_cs_n;
	wire			s_ram_cke;
	wire			s_ram_ras_n;
	wire			s_ram_cas_n;
	wire [1:0]	s_ram_bs;			
	wire [11:0]	s_ram_addr;				
	wire [1:0]  s_ram_dqm;	
	
	assign	o_ram_cs_n	= s_ram_cs_n;
	assign   o_ram_cke 	= s_ram_cke;
	assign	o_ram_ras_n	= s_ram_ras_n;
	assign	o_ram_cas_n	= s_ram_cas_n;
	assign 	o_ram_bs		= s_ram_bs;			
	assign 	o_ram_addr	= s_ram_addr;
	assign  	o_ram_dqm	= s_ram_dqm;
	
	//assign o_led = s_wb_mmreg_data_i;			// ################
	
	pll pll_inst (
		.areset ( i_rst ),
		.inclk0 ( i_clk ),
		.c0 ( s_sys_clk ),
		.c1 ( s_sdram_clk ),
		.locked ( n_rst )
	);

	
	picorv32_wb #(.ENABLE_PCPI(1), .ENABLE_MUL(1)) picorv32(
		.wb_rst_i	(n_rst), //nrst
		.wb_clk_i	(s_sys_clk	),
		.trap			(trap			),
		// Wishbone interface
		.wbm_adr_o	(s_wbm_adr_o),		
		.wbm_dat_o	(s_wbm_dat_o),		
		.wbm_dat_i	(s_wbm_dat_i),
		.wbm_we_o	(s_wbm_we_o	),		
		.wbm_sel_o	(s_wbm_sel_o),		
		.wbm_stb_o	(s_wbm_stb_o),		
		.wbm_ack_i	(s_wbm_ack_i),		
		.wbm_cyc_o	(s_wbm_cyc_o),		
		// Pico Co-Processor Interface
		.pcpi_valid (s_pcpi_valid),
		.pcpi_insn	(s_pcpi_insn),	
		.pcpi_rs1	(s_pcpi_rs1	),	
		.pcpi_rs2	(s_pcpi_rs2	),	
		.pcpi_wr		(s_pcpi_wr	),	
		.pcpi_rd		(s_pcpi_rd	), 
		.pcpi_wait	(s_pcpi_wait),	
		.pcpi_ready	(s_pcpi_ready),
		// IRQ interface
		.irq			(s_irq		),	
		.eoi			(s_eoi		),	
		//Other
		.trace_valid(s_trace_valid),	
		.trace_data	(s_trace_data),	
		.mem_instr	(mem_instr	)	
	);
	
	picorv32_pcpi_mul pcpi_mul(
		.clk			(s_sys_clk),
		.resetn		(n_rst), //nrst
		.pcpi_valid	(s_pcpi_valid),
		.pcpi_insn	(s_pcpi_insn),
		.pcpi_rs1	(s_pcpi_rs1),
		.pcpi_rs2	(s_pcpi_rs2),
		.pcpi_wr		(s_pcpi_wr),
		.pcpi_rd		(s_pcpi_rd),
		.pcpi_wait	(s_pcpi_wait),
		.pcpi_ready	(s_pcpi_ready)
	);
	
	WB_slave_arbiter arbiter (
		.i_wb_cyc			(s_wbm_cyc_o	),
		.i_wb_stb			(s_wbm_stb_o	),
		.i_wb_we				(s_wbm_we_o		),
		.i_wb_addr			(s_wbm_adr_o	),		
		.i_wb_data			(s_wbm_dat_o	),
		.i_wb_sel			(s_wbm_sel_o	),
		.o_wb_stall			(s_stall		),
		.o_wb_ack			(s_wbm_ack_i	),
		.o_wb_data			(s_wbm_dat_i	),

		// Peripherals (MM REG)
//		.o_wb_peripheral_cyc (s_wb_peripheral_cyc),
//		.o_wb_peripheral_stb (s_wb_peripheral_stb),
//		.o_wb_peripheral_we (s_wb_peripheral_we),
//		.o_wb_peripheral_addr (s_wb_peripheral_addr),
//		.o_wb_peripheral_data (s_wb_peripheral_data),
//		.o_wb_peripheral_sel (s_wb_peripheral_sel),
//		.i_wb_peripheral_stall (s_wb_peripheral_stall),
//		.i_wb_peripheral_ack (s_wb_peripheral_ack),
//		.i_wb_peripheral_data (s_wb_peripheral_data),
		.o_wb_peripheral_cyc	(s_wb_mmreg_cyc),
		.o_wb_peripheral_stb	(s_wb_mmreg_stb),
		.o_wb_peripheral_we		(s_wb_mmreg_we),
		.o_wb_peripheral_addr	(s_wb_mmreg_addr),
		.o_wb_peripheral_data	(s_wb_mmreg_data_o),
		.o_wb_peripheral_sel	(s_wb_mmreg_sel),
		.i_wb_peripheral_stall	(s_wb_mmreg_stall),
		.i_wb_peripheral_ack	(s_wb_mmreg_ack),
		.i_wb_peripheral_data	(s_wb_mmreg_data_i),

		// BRAM Bootloader ROM
		.o_wb_rom_cyc (s_wb_rom_cyc),
		.o_wb_rom_stb (s_wb_rom_stb),
		.o_wb_rom_we (s_wb_rom_we),
		.o_wb_rom_addr (s_wb_rom_addr),
		.o_wb_rom_data (s_wb_rom_data),
		.o_wb_rom_sel (s_wb_rom_sel),
		.i_wb_rom_stall (s_wb_rom_stall),
		.i_wb_rom_ack (s_wb_rom_ack),
		.i_wb_rom_data (s_wb_rom_data),

		// BRAM Fast RAM
		.o_wb_fast_ram_cyc (s_wb_fast_ram_cyc),
		.o_wb_fast_ram_stb (s_wb_fast_ram_stb),
		.o_wb_fast_ram_we (s_wb_fast_ram_we),
		.o_wb_fast_ram_addr (s_wb_fast_ram_addr),
		.o_wb_fast_ram_data (s_wb_fast_ram_data),
		.o_wb_fast_ram_sel (s_wb_fast_ram_sel),
		.i_wb_fast_ram_stall (s_wb_fast_ram_stall),
		.i_wb_fast_ram_ack (s_wb_fast_ram_ack),
		.i_wb_fast_ram_data (s_wb_fast_ram_data),

		// SDRAM Slow RAM
		.o_wb_slow_ram_cyc (s_wb_slow_ram_cyc),
		.o_wb_slow_ram_stb (s_wb_slow_ram_stb),
		.o_wb_slow_ram_we (s_wb_slow_ram_we),
		.o_wb_slow_ram_addr (s_wb_slow_ram_addr),
		.o_wb_slow_ram_data (s_wb_slow_ram_data),
		.o_wb_slow_ram_sel (s_wb_slow_ram_sel),
		.i_wb_slow_ram_stall (s_wb_slow_ram_stall),
		.i_wb_slow_ram_ack (s_wb_slow_ram_ack),
		.i_wb_slow_ram_data (s_wb_slow_ram_data),
   );
		
//	memory bram (
//		.i_clk         	(s_sys_clk    	),
//		.i_rst      	(n_rst     	),
//		.i_cyc		(s_wb_bram_cyc	),
//		.i_stb		(s_wb_bram_stb	),
//		.i_we		(s_wb_bram_we	),
//		.i_addr		(s_wb_bram_addr),		
//		.i_data		(s_wb_bram_data_o),
//		.i_sel		(s_wb_bram_sel	),
//		.o_stall		(s_wb_bram_stall),
//		.o_ack		(s_wb_bram_ack	),
//		.o_data		(s_wb_bram_data_i)
//	);	
	
		wb_ram #(.REAL_RAM_DEPTH(32768), .G_INIT_FILE("program.bin")) bootloader_rom (
			.i_clk         	(s_sys_clk),
			.i_rst      	(n_rst), //nrst
			.i_cyc		(s_wb_rom_cyc),
			.i_stb		(s_wb_rom_stb),
			.i_we			(s_wb_rom_we),
			.i_addr		(s_wb_rom_addr),		
			.i_data		(s_wb_rom_data_o),
			.i_sel		(s_wb_rom_sel	),
			.o_stall		(s_wb_rom_stall),
			.o_ack		(s_wb_rom_ack	),
			.o_data		(s_wb_rom_data_i)
		);	
		
		wb_ram #(.REAL_RAM_DEPTH(37504)) fast_ram  (
			.i_clk      (s_sys_clk),
			.i_rst 		(n_rst), //nrst
			.i_cyc		(s_wb_fast_ram_cyc),
			.i_stb		(s_wb_fast_ram_stb),
			.i_we			(s_wb_fast_ram_we),
			.i_addr		(s_wb_fast_ram_addr),		
			.i_data		(s_wb_fast_ram_data_o),
			.i_sel		(s_wb_fast_ram_sel	),
			.o_stall		(s_wb_fast_ram_stall),
			.o_ack		(s_wb_fast_ram_ack	),
			.o_data		(s_wb_fast_ram_data_i)
		);	
	
	wbsdram sdram_ctrl(
		.i_clk			(s_sys_clk			),
		.i_wb_cyc		(s_wb_sdram_cyc	),
		.i_wb_stb		(s_wb_sdram_stb	),
		.i_wb_we			(s_wb_sdram_we		),
		.i_wb_addr		(s_wb_sdram_addr	),
		.i_wb_data		(s_wb_sdram_data_o),
		.i_wb_sel		(s_wb_sdram_sel	),
		.o_wb_stall		(s_wb_sdram_stall	),
		.o_wb_ack		(s_wb_sdram_ack	),		
		.o_wb_data		(s_wb_sdram_data_i),		
		.o_ram_cs_n		(s_ram_cs_n			),
		.o_ram_cke		(s_ram_cke			),
		.o_ram_ras_n	(s_ram_ras_n		),
		.o_ram_cas_n	(s_ram_cas_n		),
		.o_ram_we_n		(s_o_ram_we_n		),
		.o_ram_bs		(s_ram_bs			),
		.o_ram_addr		(s_ram_addr			),
		.o_ram_dmod		(s_ram_dmod			),
		.i_ram_data		(s_i_ram_data		),
		.o_ram_data		(s_o_ram_data		),
		.o_ram_dqm		(s_ram_dqm			),
		.o_debug			(s_o_debug			)
	);

//`ifdef SYM
//
//	localparam period = 10;
//
//	//TODO fake pll
//	always 
//	begin
//		s_sys_clk <= 1'b1; 
//		s_sdram_clk <= 1'b0;
//		#period; // high for 20 * timescale = 20 ns
//
//		s_sys_clk <= 1'b0;
//		s_sdram_clk <= 1'b1;
//		#period; // low for 20 * timescale = 20 ns
//	end
//`else	
//	sdram_pll pll1(
//		.areset		(i_rst),
//		.inclk0		(i_clk),
//		.c0			(s_sys_clk),
//		.c1			(s_sdram_clk),
//		.locked		(n_rst)
//	);
//`endif
	
	MM_REG mmreg (										
		.i_Clk       (s_sys_clk),			
		.i_Rstn      (n_rst),	 //nrst
		.i_wb_cyc	 (s_wb_mmreg_cyc	),
		.i_wb_stb	 (s_wb_mmreg_stb	),
		.i_wb_we	 	 (s_wb_mmreg_we		),
		.i_wb_addr	 (s_wb_mmreg_addr	),
		.i_wb_data	 (s_wb_mmreg_data_o	),
		.i_wb_sel	 (s_wb_mmreg_sel	),
		.o_wb_stall  (s_wb_mmreg_stall  ),
		.o_wb_ack	 (s_wb_mmreg_ack	),
		.o_wb_data	 (s_wb_mmreg_data_i	)	
	);
	
//	wire [31:0] signal_tap_data;
//	assign signal_tap_data[15:0] = s_wbm_adr_o[15:0];
//	//assign signal_tap_data[63:32] = s_wbm_dat_i;
//	//assign signal_tap_data[95:64] = s_wbm_dat_o;
//	//assign signal_tap_data[99:96] = s_wbm_sel_o;
//	assign signal_tap_data[16] = s_wbm_we_o;
//	assign signal_tap_data[17] = s_sys_clk;
//	
//	signl_tap u0 (
//		.acq_data_in    (signal_tap_data),    //     tap.acq_data_in
//		.acq_trigger_in (s_sys_clk), //        .acq_trigger_in
//		.acq_clk        (i_clk)         // acq_clk.clk
//	);	
	
	
	
	always @(posedge s_sys_clk) begin
	/*	o_led[0] <= s_led0;
		o_led[1] <= s_led1;
		o_led[2] <= s_led2;
		o_led[3] <= s_led3;
		o_led[4] <= s_led4;
		o_led[5] <= s_led5;
		o_led[6] <= s_led6;
		o_led[7] <= s_led7; */
		
/*		o_led[0] <= startup_idle_cnt[0];
		o_led[1] <= startup_idle_cnt[1];
		o_led[2] <= startup_idle_cnt[2];
		o_led[3] <= startup_idle_cnt[3];
		o_led[4] <= startup_idle_cnt[4];
		o_led[5] <= startup_idle_cnt[5];
		o_led[6] <= startup_idle_cnt[6];
		o_led[7] <= startup_hold;*/
		
		//o_led <= o_mm_data[7:0];			//DIS
		
		o_led[6:1] <= s_wbm_adr_o[6:1];
		//n_rst <= 1;
		
		o_led[0] <= n_rst;
//		o_led[1] <= "1";
//		o_led[2] <= "0";
//		o_led[3] <= "1";
//		o_led[4] <= "1";
//		o_led[5] <= "1";
	//	o_led[6] <= "1";
		o_led[7] <= s_wb_rom_we;

	end	

endmodule
