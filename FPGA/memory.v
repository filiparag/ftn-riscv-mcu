`timescale 1 ns / 1 ps

module memory (
	input             clk,
	input             resetn,
	// DMA interface	
	input             mem_valid,
	input             mem_instr,
	output            mem_ready,
	input      [31:0] mem_addr,
	input      [31:0] mem_wdata,
	output reg [31:0] mem_rdata,
	input             mem_la_write,
	input      [31:0] mem_la_addr,
	input      [31:0] mem_la_wdata,
	input      [ 3:0] mem_la_wstrb,	
	// Wishbone Interface
	input			  i_wb_cyc,
	input			  i_wb_stb,
	input			  i_wb_we,
	input	   [31:0] i_wb_addr,
	input	   [31:0] i_wb_data,
	input	   [ 3:0] i_wb_sel,
	
	output				o_wb_stall,
	output reg			o_wb_ack,
	output reg [31:0]	o_wb_data
	
);

	// 4096 32bit words = 32kB memory
	parameter ADDR_W = 13;
	parameter MEM_SIZE = 1<<ADDR_W; // 8192

	reg [7:0] memory3 [0:MEM_SIZE-1];
	reg [7:0] memory2 [0:MEM_SIZE-1];
	reg [7:0] memory1 [0:MEM_SIZE-1];
	reg [7:0] memory0 [0:MEM_SIZE-1];
	
	wire [ADDR_W-1:0] addr_a;
	assign addr_a = i_wb_addr[ADDR_W+2-1:2];		//i_wb_addr[13:2]
	
	// Wishbone read
	always @(posedge clk) begin
		if(i_wb_we) begin
			if((i_wb_stb)&&(i_wb_sel[3])) memory3[addr_a] <= i_wb_data[31:24];
			if((i_wb_stb)&&(i_wb_sel[2])) memory2[addr_a] <= i_wb_data[23:16];	
			if((i_wb_stb)&&(i_wb_sel[1])) memory1[addr_a] <= i_wb_data[15: 8];
			if((i_wb_stb)&&(i_wb_sel[0])) memory0[addr_a] <= i_wb_data[ 7: 0];
		end
		o_wb_data[31:24] <= memory3[addr_a];
		o_wb_data[23:16] <= memory2[addr_a];
		o_wb_data[15: 8] <= memory1[addr_a];
		o_wb_data[ 7: 0] <= memory0[addr_a];
	end
	
	
	always @(posedge clk) begin
	if (resetn)							
		o_wb_ack <= (i_wb_stb)&&(i_wb_cyc);	
	else
		o_wb_ack <= 1'b0;
	end
	
	assign o_wb_stall = 1'b0;
	
	
	wire [ADDR_W-1:0] addr_b;
	assign addr_b = mem_la_addr[ADDR_W+2-1:2];
	wire we_b;
	assign we_b = mem_la_write && (mem_la_addr[31:ADDR_W+2] == 0);	
	
	
	always @(posedge clk) begin
		if (we_b) begin
			if (mem_la_wstrb[3]) memory3[addr_b] <= mem_la_wdata[31:24];
			if (mem_la_wstrb[2]) memory2[addr_b] <= mem_la_wdata[23:16];
			if (mem_la_wstrb[1]) memory1[addr_b] <= mem_la_wdata[15: 8];
			if (mem_la_wstrb[0]) memory0[addr_b] <= mem_la_wdata[ 7: 0];
		end
		mem_rdata[31:24] <= memory3[addr_b];
		mem_rdata[23:16] <= memory2[addr_b];
		mem_rdata[15: 8] <= memory1[addr_b];
		mem_rdata[ 7: 0] <= memory0[addr_b];
	end
	
	assign mem_ready = 1;
	
endmodule
