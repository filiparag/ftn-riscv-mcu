`timescale 1 ns / 1 ps

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

	wire [15:0] s_o_ram_data;

	wire		s_sdram_clk;
	wire		s_sys_clk;
	wire 		n_rst;
	
	wire  [1:0]	startup_state;						//TODO remove
	wire [15:0] s_i_ram_data;

	assign io_ram_data 	= !s_o_ram_we_n ? s_o_ram_data : 16'bZ;
	assign s_i_ram_data 	= io_ram_data;
	assign o_ram_we_n		= s_o_ram_we_n;
	assign o_ram_clk		= s_sdram_clk;
	
	// Wishbone interface signals (master to arbiter)
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
	
	// Wishbone BRAM bootloader
	wire			s_wb_boot_cyc;
	wire			s_wb_boot_stb;
	wire			s_wb_boot_we;
	wire [31:0] s_wb_boot_addr;
	wire [31:0] s_wb_boot_data_i;
	wire	[3:0] s_wb_boot_sel;
	wire			s_wb_boot_stall;
	wire			s_wb_boot_ack;
	wire [31:0]	s_wb_boot_data_o;
	
	// Wishbone BRAM firmware
	wire			s_wb_fw_cyc;
	wire			s_wb_fw_stb;
	wire			s_wb_fw_we;
	wire [31:0] s_wb_fw_addr;
	wire [31:0] s_wb_fw_data_i;
	wire	[3:0] s_wb_fw_sel;
	wire			s_wb_fw_stall;
	wire			s_wb_fw_ack;
	wire [31:0]	s_wb_fw_data_o;
	
	// Wishbone SDRAM memory
	wire			s_wb_sdram_cyc;
	wire			s_wb_sdram_stb;
	wire			s_wb_sdram_we;
	wire [20:0] s_wb_sdram_addr;
	wire [31:0] s_wb_sdram_data_i;
	wire	[3:0] s_wb_sdram_sel;
	wire			s_wb_sdram_stall;
	wire			s_wb_sdram_ack;
	wire [31:0]	s_wb_sdram_data_o;
	
	//  Wishbone memory-mapped peripherals
	wire			s_wb_periph_cyc;
	wire			s_wb_periph_stb;
	wire			s_wb_periph_we;
	wire [31:0] s_wb_periph_addr;	
	wire [31:0] s_wb_periph_data_i;
	wire [3:0] 	s_wb_periph_sel;
	wire			s_wb_periph_stall;
	wire			s_wb_periph_ack;
	wire [31:0]	s_wb_periph_data_o;
	
	// SDRAM control signals
	wire s_o_ram_cs_n;
	wire s_o_ram_cke;
	wire s_o_ram_ras_n;
	wire s_o_ram_cas_n;
	wire s_o_ram_we_n;
	
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
	
	pll pll_inst (
		.inclk0 (i_clk),
		.c0 (s_sys_clk),
		.c1 (s_sdram_clk),
		.areset (n_rst),
		.locked (n_rst),
	);
//	assign s_sys_clk = i_clk;
//	assign s_sdram_clk = i_clk;
	
	picorv32_wb #(
		.ENABLE_PCPI(1),
		.ENABLE_MUL(1),
		.REGS_INIT_ZERO(1),
		.PROGADDR_RESET(16'h800),
		.PROGADDR_IRQ(16'h10),
		.STACKADDR(16'h4800)
	) picorv32(
		.wb_rst_i	(n_rst),
		.wb_clk_i	(s_sys_clk),
		.trap			(trap	),
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
		.pcpi_rs1	(s_pcpi_rs1),	
		.pcpi_rs2	(s_pcpi_rs2),	
		.pcpi_wr		(s_pcpi_wr),	
		.pcpi_rd		(s_pcpi_rd), 
		.pcpi_wait	(s_pcpi_wait),	
		.pcpi_ready	(s_pcpi_ready),
		// IRQ interface
		.irq			(s_irq),	
		.eoi			(s_eoi),	
		//Other
		.trace_valid(s_trace_valid),	
		.trace_data	(s_trace_data),	
		.mem_instr	(mem_instr)	
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
		.i_wb_cyc			(s_wbm_cyc_o),
		.i_wb_stb			(s_wbm_stb_o),
		.i_wb_we				(s_wbm_we_o),
		.i_wb_addr			(s_wbm_adr_o),		
		.i_wb_data			(s_wbm_dat_o),
		.i_wb_sel			(s_wbm_sel_o),
		.o_wb_stall			(s_stall),
		.o_wb_ack			(s_wbm_ack_i),
		.o_wb_data			(s_wbm_dat_i),

		// Peripherals (MM REG)
		.o_wb_periph_cyc		(s_wb_periph_cyc),
		.o_wb_periph_stb		(s_wb_periph_stb),
		.o_wb_periph_we		(s_wb_periph_we),
		.o_wb_periph_addr		(s_wb_periph_addr),
		.o_wb_periph_data		(s_wb_periph_data_o),
		.o_wb_periph_sel		(s_wb_periph_sel),
		.i_wb_periph_stall	(s_wb_periph_stall),
		.i_wb_periph_ack		(s_wb_periph_ack),
		.i_wb_periph_data		(s_wb_periph_data_i),

		// BRAM bootloader
		.o_wb_boot_cyc 			(s_wb_boot_cyc),
		.o_wb_boot_stb 			(s_wb_boot_stb),
		.o_wb_boot_we 				(s_wb_boot_we),
		.o_wb_boot_addr 			(s_wb_boot_addr),
		.o_wb_boot_data 			(s_wb_boot_data),
		.o_wb_boot_sel 			(s_wb_boot_sel),
		.i_wb_boot_stall 			(s_wb_boot_stall),
		.i_wb_boot_ack 			(s_wb_boot_ack),
		.i_wb_boot_data 			(s_wb_boot_data),

		// BRAM firmware
		.o_wb_fw_cyc 		(s_wb_fw_cyc),
		.o_wb_fw_stb 		(s_wb_fw_stb),
		.o_wb_fw_we 		(s_wb_fw_we),
		.o_wb_fw_addr 		(s_wb_fw_addr),
		.o_wb_fw_data 		(s_wb_fw_data),
		.o_wb_fw_sel 		(s_wb_fw_sel),
		.i_wb_fw_stall 	(s_wb_fw_stall),
		.i_wb_fw_ack 		(s_wb_fw_ack),
		.i_wb_fw_data 		(s_wb_fw_data),

		// SDRAM
		.o_wb_sdram_cyc 		(s_wb_sdram_cyc),
		.o_wb_sdram_stb 		(s_wb_sdram_stb),
		.o_wb_sdram_we 		(s_wb_sdram_we),
		.o_wb_sdram_addr 		(s_wb_sdram_addr),
		.o_wb_sdram_data 		(s_wb_sdram_data),
		.o_wb_sdram_sel 		(s_wb_sdram_sel),
		.i_wb_sdram_stall 	(s_wb_sdram_stall),
		.i_wb_sdram_ack 		(s_wb_sdram_ack),
		.i_wb_sdram_data 		(s_wb_sdram_data),
   );
	
	wb_ram #(.ROW_COUNT(512), .G_INIT_FILE("program.bin")) bootloader (
		.i_clk      (s_sys_clk),
		.i_rst      (n_rst),
		.i_cyc		(s_wb_boot_cyc),
		.i_stb		(s_wb_boot_stb),
		.i_we			(s_wb_boot_we),
		.i_addr		(s_wb_boot_addr),		
		.i_data		(s_wb_boot_data_o),
		.i_sel		(s_wb_boot_sel	),
		.o_stall		(s_wb_boot_stall),
		.o_ack		(s_wb_boot_ack	),
		.o_data		(s_wb_boot_data_i)
	);	
	
	wb_ram #(.ROW_COUNT(13472)) firmware (
		.i_clk      (s_sys_clk),
		.i_rst 		(n_rst),
		.i_cyc		(s_wb_fw_cyc),
		.i_stb		(s_wb_fw_stb),
		.i_we			(s_wb_fw_we),
		.i_addr		(s_wb_fw_addr),		
		.i_data		(s_wb_fw_data_o),
		.i_sel		(s_wb_fw_sel),
		.o_stall		(s_wb_fw_stall),
		.o_ack		(s_wb_fw_ack),
		.o_data		(s_wb_fw_data_i)
	);	
	
	wbsdram sdram_ctrl (
		.i_clk			(s_sys_clk),
		.i_wb_cyc		(s_wb_sdram_cyc),
		.i_wb_stb		(s_wb_sdram_stb),
		.i_wb_we			(s_wb_sdram_we),
		.i_wb_addr		(s_wb_sdram_addr),
		.i_wb_data		(s_wb_sdram_data_o),
		.i_wb_sel		(s_wb_sdram_sel),
		.o_wb_stall		(s_wb_sdram_stall),
		.o_wb_ack		(s_wb_sdram_ack),		
		.o_wb_data		(s_wb_sdram_data_i),		
		.o_ram_cs_n		(s_ram_cs_n),
		.o_ram_cke		(s_ram_cke),
		.o_ram_ras_n	(s_ram_ras_n),
		.o_ram_cas_n	(s_ram_cas_n),
		.o_ram_we_n		(s_o_ram_we_n),
		.o_ram_bs		(s_ram_bs),
		.o_ram_addr		(s_ram_addr),
		.o_ram_dmod		(s_ram_dmod),
		.i_ram_data		(s_i_ram_data),
		.o_ram_data		(s_o_ram_data),
		.o_ram_dqm		(s_ram_dqm),
		.o_debug			(s_o_debug)
	);
	
	MM_REG #(.REG_ADDR(16'h7FF), .REG_SIZE(6)) mmreg (
		.i_Clk       (s_sys_clk),			
		.i_Rstn      (n_rst),
		.i_wb_cyc	 (s_wb_periph_cyc),
		.i_wb_stb	 (s_wb_periph_stb),
		.i_wb_we	 	 (s_wb_periph_we),
		.i_wb_addr	 (s_wb_periph_addr),
		.i_wb_data	 (s_wb_periph_data_o),
		.i_wb_sel	 (s_wb_periph_sel),
		.o_wb_stall  (s_wb_periph_stall),
		.o_wb_ack	 (s_wb_periph_ack),
		.o_wb_data	 (s_wb_periph_data_i),
		.s_reg		(o_led[5:0])
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
	
//	wire [31:0] signal_tap_data;
//	assign signal_tap_data[15:0] = s_wbm_adr_o[15:0];
//	assign signal_tap_data[16] = s_wbm_we_o;
//	assign signal_tap_data[17] = s_sys_clk;
//	
//	signl_tap u0 (
//		.acq_data_in    (signal_tap_data),    //     tap.acq_data_in
//		.acq_trigger_in (s_sys_clk), //        .acq_trigger_in
//		.acq_clk        (i_clk)         // acq_clk.clk
//	);	
	
	reg [27:0] clock_counter;
	always @(posedge s_sys_clk) begin
		clock_counter <= clock_counter + 1;
		o_led[7] <= clock_counter[24] & "1";
		o_led[6] <= clock_counter[27] & "1";
	end
	
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
		
		//o_led[6:0] <= s_wbm_adr_o[6:0];			//DIS
		//o_led[7] <= s_wbm_we_o;
		
		//o_led[6:1] <= s_wbm_adr_o[6:1];
		//n_rst <= 1;
		
		
//		o_led[1] <= "1";
//		o_led[2] <= "0";
//		o_led[3] <= "1";
//		o_led[4] <= "1";
//		o_led[5] <= "1";
//		o_led[6] <= "1";
//		o_led[7] <= "1";

	end	

endmodule
