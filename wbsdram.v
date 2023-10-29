////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbsdram.v
// {{{
// Project:	ArrowZip, a demonstration of the Arrow MAX1000 FPGA board
//
// Purpose:	Provide 32-bit wishbone access to the SDRAM memory on a MAX1000
//		board.  Specifically, on each access, the controller will
//	activate an appropriate bank of RAM (the SDRAM has four banks), and
//	then issue the read/write command.  In the case of walking off the
//	bank, the controller will activate the next bank before you get to it.
//	Upon concluding any wishbone access, all banks will be precharged and
//	returned to idle.
//
//	This particular implementation represents a second generation version
//	because my first version was too complex.  To speed things up, this
//	version includes an extra wait state where the wishbone inputs are
//	clocked into a flip flop before any action is taken on them.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2021, Gisselquist Technology, LLC
// {{{
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype	none
// }}}
`define	DMOD_GETINPUT	1'b0
`define	DMOD_PUTOUTPUT	1'b1
`define	RAM_OPERATIONAL		2'b11
`define	RAM_POWER_UP		2'b00
`define	RAM_SET_MODE		2'b01
`define	RAM_INITIAL_REFRESH	2'b10
// }}}
module	wbsdram #(
		// {{{
		parameter	RDLY = 6,
		parameter	NCA=8, NRA=12, AW=(NCA+NRA+2)-1, DW=32,
		parameter	[NCA-2:0] COL_THRESHOLD = -16
		// }}}
	) (
		// {{{
		input	wire			i_clk,
		// Wishbone
		// {{{
		//	inputs
		input	wire			i_wb_cyc, i_wb_stb, i_wb_we,
		input	wire	[(AW-1):0]	i_wb_addr,
		input	wire	[(DW-1):0]	i_wb_data,
		input	wire	[(DW/8-1):0]	i_wb_sel,
		//	outputs
		output	reg		o_wb_stall,
		output	wire		o_wb_ack,
		output	wire [31:0]	o_wb_data,
//		output	reg [31:0]	o_wb_data,					// MENJANO
		// }}}
		// SDRAM control
		output	reg		o_ram_cs_n,
		output	wire		o_ram_cke,
		output	reg		o_ram_ras_n, o_ram_cas_n, o_ram_we_n,
		output	reg	[1:0]	o_ram_bs,
		output	reg	[11:0]	o_ram_addr,
		output	reg		o_ram_dmod,
		input		wire [15:0]	i_ram_data,
		output	reg	[15:0]	o_ram_data,
		output	reg	[1:0]	o_ram_dqm,
		output	wire [(DW-1):0]	o_debug
		// }}}
	);

	// Local declarations
	// {{{
//	reg			need_refresh;				// menjano
	wire		need_refresh;
	reg	[9:0]		refresh_clk;
	wire			refresh_cmd;
//	reg			in_refresh;					// menjano
	wire			in_refresh;
	reg	[2:0]		in_refresh_clk;
	reg	[2:0]		bank_active	[0:3];
	reg	[(RDLY-1):0]	r_barrell_ack;
	reg			r_pending;
	reg			r_we;
	reg	[(AW-1):0]	r_addr;
	reg	[31:0]		r_data;
	reg	[3:0]		r_sel;
	reg	[(AW-NCA-2):0]	bank_row	[0:3];
	reg	[2:0]		clocks_til_idle;
	reg	[1:0]		m_state;
	wire			bus_cyc;
	reg			nxt_dmod;
	wire			pending;
	reg	[(AW-1):0]	fwd_addr;
	wire	[1:0]	wb_bs, r_bs, fwd_bs;	// Bank select
	wire	[NRA-1:0]	wb_row, r_row, fwd_row;
	reg	r_bank_valid;
	reg	fwd_bank_valid;
	reg	maintenance_mode;
	reg	m_ram_cs_n, m_ram_ras_n, m_ram_cas_n, m_ram_we_n, m_ram_dmod;
	reg	[(NRA-1):0]	m_ram_addr;
	reg		startup_hold;
	reg	[15:0]	startup_idle;
	reg	[3:0]	maintenance_clocks;
	reg		maintenance_clocks_zero;
//	reg	[15:0]	last_ram_data;
	reg	[15:0]	last_ram_data [0:4];		//MENJANO
	reg word_sel;

	localparam STATE_SIZE = 4;
	
	localparam MAINTENANCE = 0,
	NOOP = 1,
	CLOSE_ALL_ACTIVE_BANKS = 2,
	PRECHARGE_ALL = 3,
	AUTO_REFRESH = 4,
	IN_REFRESH = 5,
	ACTIVATE = 6,
	CLOSE_BANK = 7,
	READ = 8,
	WRITE = 9,
	PRECHARGE = 10,
	PRE_ACTIVATE = 11;

	reg [STATE_SIZE-1:0] state;
	// }}}

	// Calculate some metrics
	// {{{
	//
	// First, do we *need* a refresh now --- i.e., must we break out of
	// whatever we are doing to issue a refresh command?
	//
	// The step size here must be such that 8192 charges may be done in
	// 64 ms.  Thus for a clock of:
	//	ClkRate(MHz)	(64ms/1000(ms/s)*ClkRate)/8192
	//	100 MHz		781
	//	 96 MHz		750
	//	 92 MHz		718
	//	 88 MHz		687
	//	 84 MHz		656
	//	 80 MHz		625
	//   50 MHz		391  
	//   MENJANO    50 MHz  781
	// However, since we do two refresh cycles everytime we need a refresh,
	// this standard is close to overkill--but we'll use it anyway.  At
	// some later time we should address this, once we are entirely
	// convinced that the memory is otherwise working without failure.  Of
	// course, at that time, it may no longer be a priority ...
	// // }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Clock counting to know when to refresh
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	assign	refresh_cmd = (!o_ram_cs_n)&&(!o_ram_ras_n)&&(!o_ram_cas_n)&&(o_ram_we_n);

	// refresh_clk
	// {{{
	initial	refresh_clk = 0;
	always @(posedge i_clk)
	begin
		if (refresh_cmd)
			refresh_clk <= 10'd391; // Make suitable for 50 MHz clk
//			refresh_clk <= 10'd781; // Make suitable for 50 MHz clk
		else if (|refresh_clk)
			refresh_clk <= refresh_clk - 10'h1;
	end
	// }}}

	// need_refresh
	// {{{
/*	initial	need_refresh = 1'b0;
	always @(posedge i_clk)
		need_refresh <= (refresh_clk == 10'h00)&&(!refresh_cmd);*/
	assign need_refresh = (refresh_clk == 10'h00)&&(!refresh_cmd);
	// }}}

	// in_refresh_clk
	// {{{
	initial	in_refresh_clk = 3'h0;
	always @(posedge i_clk)
	if (refresh_cmd)
		in_refresh_clk <= 3'h6;
	else if (|in_refresh_clk)
		in_refresh_clk <= in_refresh_clk - 3'h1;
	// }}}

	// in_refresh
	// {{{
/*	initial	in_refresh = 0;
	always @(posedge i_clk)
		in_refresh <= (in_refresh_clk != 3'h0)||(refresh_cmd);*/

	assign in_refresh = (in_refresh_clk != 3'h0)||(refresh_cmd);

	// }}}

	//
	// Second, do we *need* a precharge now --- must be break out of
	// whatever we are doing to issue a precharge command?
	//
	// Keep in mind, the number of clocks to wait has to be reduced by
	// the amount of time it may take us to go into a precharge state.
	// You may also notice that the precharge requirement is tighter
	// than this one, so ... perhaps this isn't as required?
	//
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Incoming bus request handling and skidbuffer
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	assign	bus_cyc  = ((i_wb_cyc)&&(i_wb_stb)&&(!o_wb_stall));

	// fwd_addr, r_*: Pre-process pending operations
	// {{{
	initial	r_pending = 1'b0;
	initial	r_addr = 0;
	initial	fwd_addr = { {(AW-(NCA)){1'b0}}, 1'b1, {(NCA-1){1'b0}} };
	always @(posedge i_clk)
	begin
		fwd_addr[NCA-2:0] <= 0;
		if (bus_cyc)
		begin
			r_pending <= 1'b1;
			r_we      <= i_wb_we;
			r_addr    <= i_wb_addr;
			r_data    <= i_wb_data;
			r_sel     <= i_wb_sel;
			fwd_addr[AW-1:NCA-1]<=i_wb_addr[(AW-1):(NCA-1)] + 1'b1;
		end else if ((!o_ram_cs_n)&&(o_ram_ras_n)&&(!o_ram_cas_n))
			r_pending <= 1'b0;
		else if (!i_wb_cyc)
			r_pending <= 1'b0;
	end
	// }}}

	assign	wb_bs = i_wb_addr[NCA:NCA-1];
	assign	r_bs  =    r_addr[NCA:NCA-1];
	assign fwd_bs =  fwd_addr[NCA:NCA-1];

	assign	wb_row = i_wb_addr[AW-1:NCA+1];
	assign	 r_row =    r_addr[AW-1:NCA+1];
	assign fwd_row =  fwd_addr[AW-1:NCA+1];

	// r_bank_valid
	// {{{
	initial	r_bank_valid = 1'b0;
	always @(posedge i_clk)
	if (bus_cyc)
		r_bank_valid <=((bank_active[wb_bs][2])
				&&(bank_row[wb_bs] == wb_row));
	else
		r_bank_valid <= ((bank_active[r_bs][2])
				&&(bank_row[r_bs] == r_row));
	// }}}

	// fwd_bank_valid
	// {{{
	initial	fwd_bank_valid = 0;
	always @(posedge i_clk)
		fwd_bank_valid <= ((bank_active[fwd_bs][2])
				&&(bank_row[fwd_bs] == fwd_row));
	// }}}

	assign	pending = (r_pending)&&(o_wb_stall);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// SDRAM protocol handling
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	// Address MAP:
	// {{{
	//	22-bits bits in, 23-bits out
	//
	//	22 1111 1111 1100 0000 0000
	//	10 9876 5432 1098 7654 3210
	//	rr rrrr rrrr rrBB cccc cccc 0
	//	                  8765 4321 0
	// }}}
`ifdef ORIG_FSM
	// Monster state machine
	// {{{
	initial r_barrell_ack = 0;
	initial	clocks_til_idle = 3'h0;
	initial o_wb_stall = 1'b1;
	initial	o_ram_dmod = `DMOD_GETINPUT;
	initial	nxt_dmod = `DMOD_GETINPUT;				// 0
	initial o_ram_cs_n  = 1'b0;
	initial o_ram_ras_n = 1'b1;
	initial o_ram_cas_n = 1'b1;
	initial o_ram_we_n  = 1'b1;
	initial	o_ram_dqm   = 2'b11;
	assign	o_ram_cke   = 1'b1;
	initial bank_active[0] = 3'b000;
	initial bank_active[1] = 3'b000;
	initial bank_active[2] = 3'b000;
	initial bank_active[3] = 3'b000;

	initial word_sel = 0;							// DODATO

	always @(posedge i_clk)
	if (maintenance_mode)
	begin
		// {{{
		state = MAINTENANCE;		// ####
		bank_active[0] <= 0;
		bank_active[1] <= 0;
		bank_active[2] <= 0;
		bank_active[3] <= 0;
		r_barrell_ack[(RDLY-1):0] <= 0;
		o_wb_stall  <= 1'b1;
		//
		o_ram_cs_n  <= m_ram_cs_n;
		o_ram_ras_n <= m_ram_ras_n;
		o_ram_cas_n <= m_ram_cas_n;
		o_ram_we_n  <= m_ram_we_n;
		o_ram_dmod  <= m_ram_dmod;
		o_ram_addr  <= m_ram_addr;
		o_ram_bs    <= 2'b00;
		nxt_dmod <= `DMOD_GETINPUT;				// 0
		// }}}
	end else begin
		state = NOOP;							// ###
		o_wb_stall <= (r_pending)||(bus_cyc);
		if (!i_wb_cyc)
			r_barrell_ack <= 0;
		else
			r_barrell_ack <= r_barrell_ack >> 1;
		nxt_dmod <= `DMOD_GETINPUT;				// 0
		o_ram_dmod <= nxt_dmod;

		// default bank_active
		// {{{
		// We assume that, whatever state the bank is in, that it
		// continues in that state and set up a series of shift
		// registers to contain that information.  If it will not
		// continue in that state, all that therefore needs to be
		// done is to set bank_active[?][2] below.
		//
		bank_active[0] <= { bank_active[0][2], bank_active[0][2:1] };
		bank_active[1] <= { bank_active[1][2], bank_active[1][2:1] };
		bank_active[2] <= { bank_active[2][2], bank_active[2][2:1] };
		bank_active[3] <= { bank_active[3][2], bank_active[3][2:1] };
		// }}}
		o_ram_cs_n <= (!i_wb_cyc);
		// o_ram_cke  <= 1'b1;
		if (|clocks_til_idle[2:0])
			clocks_til_idle[2:0] <= clocks_til_idle[2:0] - 3'h1;

		// Default command is a
		//	NOOP if (i_wb_cyc)
		//	Device deselect if (!i_wb_cyc)
		// o_ram_cs_n  <= (!i_wb_cyc) above, NOOP
		o_ram_ras_n <= 1'b1;
		o_ram_cas_n <= 1'b1;
		o_ram_we_n  <= 1'b1;

		// o_ram_data <= r_data[15:0];

		if (nxt_dmod)
			state = NOOP;		// ####	
//			;
		else
		if ((!i_wb_cyc)||(need_refresh))
		begin // Issue a precharge all command (if any banks are open),
			  // otherwise an autorefresh command
			if ((bank_active[0][2:1]==2'b10)
					||(bank_active[1][2:1]==2'b10)
					||(bank_active[2][2:1]==2'b10)
					||(bank_active[3][2:1]==2'b10)
					||(|clocks_til_idle[2:0])

					||(bank_active[0] == 3'b110)			//Changed! 
					||(bank_active[1] == 3'b110)			//Added additional clock
					||(bank_active[2] == 3'b110)			//because the old version violated
					||(bank_active[3] == 3'b110))			//tRFC and tRAS constraints
			begin
				// Do nothing this clock
				// Can't precharge a bank immediately after
				// activating it
				state = NOOP;		// ####	
//			end else if (bank_active[0][2]
//				||(bank_active[1][2])
//				||(bank_active[2][2])
//				||(bank_active[3][2]))
			end else if (bank_active[0][2]
				||(bank_active[1][2])
				||(bank_active[2][2])
				||(bank_active[3][2]))
			begin  // Close all active banks
				// {{{
				state = PRECHARGE_ALL;		// ####	
				o_ram_cs_n  <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b1;
				o_ram_we_n  <= 1'b0;
				o_ram_addr[10] <= 1'b1;
				bank_active[0][2] <= 1'b0;
				bank_active[1][2] <= 1'b0;
				bank_active[2][2] <= 1'b0;
				bank_active[3][2] <= 1'b0;
				// }}}
			end else if ((|bank_active[0])
					||(|bank_active[1])
					||(|bank_active[2])
					||(|bank_active[3]))
				// Can't precharge yet, the bus is still busy
//			begin end else if ((!in_refresh)&&((refresh_clk[9:8]==2'b00)||(need_refresh)))	
//			#FIXME mozda je ovde prob
//			begin end else if (need_refresh)
			begin end else if (need_refresh && r_barrell_ack == 0)
			begin // Send autorefresh command
				// {{{
				state = AUTO_REFRESH;		// ####	
				o_ram_cs_n  <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b0;
				o_ram_we_n  <= 1'b1;
				// }}}
			end // Else just send NOOP's, the default command
		end else if (in_refresh)
		begin
			// NOOPS only here, until we are out of refresh
			state = IN_REFRESH;		// ####	
//		end else if ((pending)&&(!r_bank_valid)&&(bank_active[r_bs]==3'h0)&&(!in_refresh))
		end else if ((pending)&&(!r_bank_valid)&&(bank_active[r_bs]==3'h0)&&(!in_refresh) && (state != IN_REFRESH))
		begin // Need to activate the requested bank
			// {{{
			state = ACTIVATE;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b0;
			o_ram_cas_n <= 1'b1;
			o_ram_we_n  <= 1'b1;
			o_ram_addr  <= r_row;
			o_ram_bs    <= r_bs;
			// clocks_til_idle[2:0] <= 1;
			bank_active[r_bs][2] <= 1'b1;
			bank_row[r_bs] <= r_row;
			word_sel <= 1'b0;
			// }}}
		end else if ((pending)&&(!r_bank_valid)
				&&(bank_active[r_bs]==3'b111))
		begin // Need to close an active bank
			// {{{
			state = CLOSE_BANK;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b0;
			o_ram_cas_n <= 1'b1;
			o_ram_we_n  <= 1'b0;
			// o_ram_addr  <= r_addr[(AW-1):(NCA+2)];
			o_ram_addr[10]<= 1'b0;
			o_ram_bs    <= r_bs;
			// clocks_til_idle[2:0] <= 1;
			bank_active[r_bs][2] <= 1'b0;
			// bank_row[r_bs] <= r_row;
			// }}}
		end else if ((pending)&&(!r_we)
				&&(bank_active[r_bs][2])
				&&(r_bank_valid)
				&&(clocks_til_idle[2:0] < 4))				
		begin // Issue the read command
			// {{{
			state = READ;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b1;
			o_ram_cas_n <= 1'b0;
			o_ram_we_n  <= 1'b1;
//			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], 1'b0 };
			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], word_sel }; // MENJANO

			o_ram_bs    <= r_bs;
			clocks_til_idle[2:0] <= 4;				

			o_wb_stall <= 1'b0;
			r_barrell_ack[(RDLY-1)] <= 1'b1;
//			r_barrell_ack[1] <= 1'b1;				// MENJANO

			word_sel <= !word_sel;

			// }}}
		end else if ((pending)&&(r_we)
			&&(bank_active[r_bs][2])
			&&(r_bank_valid)
			&&(clocks_til_idle[2:0] == 0))
		begin // Issue the write command
			// {{{
			state = WRITE;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b1;
			o_ram_cas_n <= 1'b0;
			o_ram_we_n  <= 1'b0;
			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], word_sel };	
//			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], 1'b0 };	// MENJANO
			o_ram_bs    <= r_bs;
			clocks_til_idle[2:0] <= 3'h1;

			o_wb_stall <= 1'b0;
			r_barrell_ack[1] <= 1'b1;
			// o_ram_data <= r_data[31:16];
			//
			o_ram_dmod <= `DMOD_PUTOUTPUT;
			nxt_dmod <= `DMOD_PUTOUTPUT;					// 1
			// }}}
			word_sel <= !word_sel;
		end else if ((r_pending)&&(r_addr[(NCA-2):0] >= COL_THRESHOLD)
				&&(!fwd_bank_valid))
		begin
			// Do I need to close the next bank I'll need?
			if (bank_active[fwd_bs][2:1]==2'b11)
			begin // Need to close the bank first
				// {{{
				state = PRECHARGE;		// ####	
				o_ram_cs_n <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b1;
				o_ram_we_n  <= 1'b0;
				o_ram_addr[10] <= 1'b0;
				o_ram_bs       <= fwd_bs;
				bank_active[fwd_bs][2] <= 1'b0;
				// }}}
			end else if (bank_active[fwd_bs]==0)
			begin
				state = PRE_ACTIVATE;		// ####	
				// Need to (pre-)activate the next bank
				// {{{
				o_ram_cs_n  <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b1;
				o_ram_we_n  <= 1'b1;
				o_ram_addr  <= fwd_row;
				o_ram_bs    <= fwd_bs;
				// clocks_til_idle[3:0] <= 1;
				bank_active[fwd_bs] <= 3'h4;
				bank_row[fwd_bs] <= fwd_row;
				// }}}
			end
		end
		if (!i_wb_cyc)
			r_barrell_ack <= 0;
	end


`else
//############################################################################
	// Monster state machine #2 Pijetlo eddition
	// {{{
	initial r_barrell_ack = 0;
	initial	clocks_til_idle = 3'h0;
	initial o_wb_stall = 1'b1;
	initial	o_ram_dmod = `DMOD_GETINPUT;
	initial	nxt_dmod = `DMOD_GETINPUT;				// 0
	initial o_ram_cs_n  = 1'b0;
	initial o_ram_ras_n = 1'b1;
	initial o_ram_cas_n = 1'b1;
	initial o_ram_we_n  = 1'b1;
	initial	o_ram_dqm   = 2'b11;
	assign	o_ram_cke   = 1'b1;
	initial bank_active[0] = 3'b000;
	initial bank_active[1] = 3'b000;
	initial bank_active[2] = 3'b000;
	initial bank_active[3] = 3'b000;

	initial word_sel = 0;							// DODATO

	always @(posedge i_clk)
	if (maintenance_mode)
	begin
		// {{{
		state = MAINTENANCE;		// ####
		bank_active[0] <= 0;
		bank_active[1] <= 0;
		bank_active[2] <= 0;
		bank_active[3] <= 0;
		r_barrell_ack[(RDLY-1):0] <= 0;
		o_wb_stall  <= 1'b1;
		//
		o_ram_cs_n  <= m_ram_cs_n;
		o_ram_ras_n <= m_ram_ras_n;
		o_ram_cas_n <= m_ram_cas_n;
		o_ram_we_n  <= m_ram_we_n;
		o_ram_dmod  <= m_ram_dmod;
		o_ram_addr  <= m_ram_addr;
		o_ram_bs    <= 2'b00;
		nxt_dmod <= `DMOD_GETINPUT;				// 0
		// }}}
	end else begin
		state = NOOP;							// ###
		o_wb_stall <= (r_pending)||(bus_cyc);
		if (!i_wb_cyc)
			r_barrell_ack <= 0;
		else
			r_barrell_ack <= r_barrell_ack >> 1;
		nxt_dmod <= `DMOD_GETINPUT;				// 0
		o_ram_dmod <= nxt_dmod;

		// default bank_active
		// {{{
		// We assume that, whatever state the bank is in, that it
		// continues in that state and set up a series of shift
		// registers to contain that information.  If it will not
		// continue in that state, all that therefore needs to be
		// done is to set bank_active[?][2] below.
		//
		bank_active[0] <= { bank_active[0][2], bank_active[0][2:1] };
		bank_active[1] <= { bank_active[1][2], bank_active[1][2:1] };
		bank_active[2] <= { bank_active[2][2], bank_active[2][2:1] };
		bank_active[3] <= { bank_active[3][2], bank_active[3][2:1] };
		// }}}
		o_ram_cs_n <= (!i_wb_cyc);
		// o_ram_cke  <= 1'b1;
		if (|clocks_til_idle[2:0])
			clocks_til_idle[2:0] <= clocks_til_idle[2:0] - 3'h1;

		// Default command is a
		//	NOOP if (i_wb_cyc)
		//	Device deselect if (!i_wb_cyc)
		// o_ram_cs_n  <= (!i_wb_cyc) above, NOOP
		o_ram_ras_n <= 1'b1;
		o_ram_cas_n <= 1'b1;
		o_ram_we_n  <= 1'b1;

		// o_ram_data <= r_data[15:0];

		if (nxt_dmod)
			state = NOOP;		// ####	
//			;
		else
		if (in_refresh)
		begin
			// NOOPS only here, until we are out of refresh
			state = IN_REFRESH;		// ####	
//		end else if ((pending)&&(!r_bank_valid)&&(bank_active[r_bs]==3'h0)&&(!in_refresh))
		end else if ((pending)&&(!r_bank_valid)&&(bank_active[r_bs]==3'h0)&&(!in_refresh) && (state != IN_REFRESH))
		begin // Need to activate the requested bank
			// {{{
			state = ACTIVATE;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b0;
			o_ram_cas_n <= 1'b1;
			o_ram_we_n  <= 1'b1;
			o_ram_addr  <= r_row;
			o_ram_bs    <= r_bs;
			// clocks_til_idle[2:0] <= 1;
			bank_active[r_bs][2] <= 1'b1;
			bank_row[r_bs] <= r_row;
			word_sel <= 1'b0;
			// }}}
		end else if ((pending)&&(!r_bank_valid)
				&&(bank_active[r_bs]==3'b111))
		begin // Need to close an active bank
			// {{{
			state = CLOSE_BANK;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b0;
			o_ram_cas_n <= 1'b1;
			o_ram_we_n  <= 1'b0;
			// o_ram_addr  <= r_addr[(AW-1):(NCA+2)];
			o_ram_addr[10]<= 1'b0;
			o_ram_bs    <= r_bs;
			// clocks_til_idle[2:0] <= 1;
			bank_active[r_bs][2] <= 1'b0;
			// bank_row[r_bs] <= r_row;
			// }}}
		end else if ((pending)&&(!r_we)
				&&(bank_active[r_bs][2])
				&&(r_bank_valid)
				&&(clocks_til_idle[2:0] < 4))				
		begin // Issue the read command
			// {{{
			state = READ;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b1;
			o_ram_cas_n <= 1'b0;
			o_ram_we_n  <= 1'b1;
//			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], 1'b0 };
			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], word_sel }; // MENJANO

			o_ram_bs    <= r_bs;
			clocks_til_idle[2:0] <= 4;				

			o_wb_stall <= 1'b0;
			r_barrell_ack[(RDLY-1)] <= 1'b1;
//			r_barrell_ack[1] <= 1'b1;				// MENJANO

			word_sel <= !word_sel;

			// }}}
		end else if ((pending)&&(r_we)
			&&(bank_active[r_bs][2])
			&&(r_bank_valid)
			&&(clocks_til_idle[2:0] == 0))
		begin // Issue the write command
			// {{{
			state = WRITE;		// ####	
			o_ram_cs_n  <= 1'b0;
			o_ram_ras_n <= 1'b1;
			o_ram_cas_n <= 1'b0;
			o_ram_we_n  <= 1'b0;
			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], word_sel };	
//			o_ram_addr  <= { 4'h0, r_addr[NCA-2:0], 1'b0 };	// MENJANO
			o_ram_bs    <= r_bs;
			clocks_til_idle[2:0] <= 3'h1;

			o_wb_stall <= 1'b0;
			r_barrell_ack[1] <= 1'b1;
			// o_ram_data <= r_data[31:16];
			//
			o_ram_dmod <= `DMOD_PUTOUTPUT;
			nxt_dmod <= `DMOD_PUTOUTPUT;					// 1
			// }}}
			word_sel <= !word_sel;
		end else if ((r_pending)&&(r_addr[(NCA-2):0] >= COL_THRESHOLD)
				&&(!fwd_bank_valid))
		begin
			// Do I need to close the next bank I'll need?
			if (bank_active[fwd_bs][2:1]==2'b11)
			begin // Need to close the bank first
				// {{{
				state = PRECHARGE;		// ####	
				o_ram_cs_n <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b1;
				o_ram_we_n  <= 1'b0;
				o_ram_addr[10] <= 1'b0;
				o_ram_bs       <= fwd_bs;
				bank_active[fwd_bs][2] <= 1'b0;
				// }}}
			end else if (bank_active[fwd_bs]==0)
			begin
				state = PRE_ACTIVATE;		// ####	
				// Need to (pre-)activate the next bank
				// {{{
				o_ram_cs_n  <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b1;
				o_ram_we_n  <= 1'b1;
				o_ram_addr  <= fwd_row;
				o_ram_bs    <= fwd_bs;
				// clocks_til_idle[3:0] <= 1;
				bank_active[fwd_bs] <= 3'h4;
				bank_row[fwd_bs] <= fwd_row;
				// }}}
			end
		end else if ((!i_wb_cyc)||(need_refresh))
		begin // Issue a precharge all command (if any banks are open),
			  // otherwise an autorefresh command
			if ((bank_active[0][2:1]==2'b10)
					||(bank_active[1][2:1]==2'b10)
					||(bank_active[2][2:1]==2'b10)
					||(bank_active[3][2:1]==2'b10)
					||(|clocks_til_idle[2:0])

					||(bank_active[0] == 3'b110)			//Changed! 
					||(bank_active[1] == 3'b110)			//Added additional clock
					||(bank_active[2] == 3'b110)			//because the old version violated
					||(bank_active[3] == 3'b110))			//tRFC and tRAS constraints
			begin
				// Do nothing this clock
				// Can't precharge a bank immediately after
				// activating it
				state = NOOP;		// ####	
//			end else if (bank_active[0][2]
//				||(bank_active[1][2])
//				||(bank_active[2][2])
//				||(bank_active[3][2]))
			end else if (bank_active[0][2]
				||(bank_active[1][2])
				||(bank_active[2][2])
				||(bank_active[3][2]))
			begin  // Close all active banks
				// {{{
				state = PRECHARGE_ALL;		// ####	
				o_ram_cs_n  <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b1;
				o_ram_we_n  <= 1'b0;
				o_ram_addr[10] <= 1'b1;
				bank_active[0][2] <= 1'b0;
				bank_active[1][2] <= 1'b0;
				bank_active[2][2] <= 1'b0;
				bank_active[3][2] <= 1'b0;
				// }}}
			end else if ((|bank_active[0])
					||(|bank_active[1])
					||(|bank_active[2])
					||(|bank_active[3]))
				// Can't precharge yet, the bus is still busy
//			begin end else if ((!in_refresh)&&((refresh_clk[9:8]==2'b00)||(need_refresh)))	
//			#FIXME mozda je ovde prob
//			begin end else if (need_refresh)
			begin end else if (need_refresh && r_barrell_ack == 0)
			begin // Send autorefresh command
				// {{{
				state = AUTO_REFRESH;		// ####	
				o_ram_cs_n  <= 1'b0;
				o_ram_ras_n <= 1'b0;
				o_ram_cas_n <= 1'b0;
				o_ram_we_n  <= 1'b1;
				// }}}
			end // Else just send NOOP's, the default command
		end else 
		if (!i_wb_cyc)
			r_barrell_ack <= 0;
	end


//############################################################################
`endif

	// }}}
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Startup handling
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// startup_idle, startup_hold
	// {{{
	initial	startup_idle = 16'd20500;
	initial	startup_hold = 1'b1;
	always @(posedge i_clk)
	if (|startup_idle)
		startup_idle <= startup_idle - 1'b1;

	always @(posedge i_clk)
		startup_hold <= |startup_idle;
	// }}}

	// Maintenance state machine
	// {{{
	initial	maintenance_mode = 1'b1;
	initial	maintenance_clocks = 4'hf;
	initial	maintenance_clocks_zero = 1'b0;
//	initial	m_ram_addr  = { 2'b00, 1'b0, 2'b00, 3'b010, 1'b0, 3'b001 };
	initial	m_ram_addr  = { 2'b00, 1'b0, 2'b00, 3'b011, 1'b0, 3'b000 };
	initial	m_state = `RAM_POWER_UP;
	initial	m_ram_cs_n  = 1'b1;
	initial	m_ram_ras_n = 1'b1;
	initial	m_ram_cas_n = 1'b1;
	initial	m_ram_we_n  = 1'b1;
	initial	m_ram_dmod  = `DMOD_GETINPUT;
	always @(posedge i_clk)
	begin
		if (!maintenance_clocks_zero)
		begin
			maintenance_clocks <= maintenance_clocks - 4'h1;
			maintenance_clocks_zero <= (maintenance_clocks == 4'h1);
		end
		// The only time the RAM address matters is when we set
		// the mode.  At other times, addr[10] matters, but the rest
		// is ignored.  Hence ... we'll set it to a constant.
			m_ram_addr  <= { 2'b00, 1'b0, 2'b00, 3'b011, 1'b0, 3'b000 }; //Burst 1 CASLat 3
		//	m_ram_addr  <= { 2'b00, 1'b0, 2'b00, 3'b010, 1'b0, 3'b001 };
		//m_ram_addr  <= { 2'b00, 1'b0, 2'b00, 3'b011, 1'b0, 3'b000 };
		if (m_state == `RAM_POWER_UP)
		begin
			// {{{
			// All signals must be held in NOOP state during powerup
			// m_ram_cke <= 1'b1;
			m_ram_cs_n  <= 1'b1;
			m_ram_ras_n <= 1'b1;
			m_ram_cas_n <= 1'b1;
			m_ram_we_n  <= 1'b1;
			m_ram_dmod  <= `DMOD_GETINPUT;
			if (!startup_hold)
			begin
//				m_state <= `RAM_SET_MODE;
				m_state <= `RAM_INITIAL_REFRESH;				// ### MENJANO ###
//				maintenance_clocks <= 4'h3;
				maintenance_clocks <= 4'hc;						// ### MENJANO ###
				maintenance_clocks_zero <= 1'b0;
				// Precharge all cmd
				m_ram_cs_n  <= 1'b0;
				m_ram_ras_n <= 1'b0;
				m_ram_cas_n <= 1'b1;
				m_ram_we_n  <= 1'b0;
				m_ram_addr[10] <= 1'b1;
			end
			// }}}
		end else if (m_state == `RAM_INITIAL_REFRESH)
		begin
			// {{{
			// NOOP
			m_ram_cs_n     <= 1'b0;
			m_ram_ras_n    <= 1'b1;
			m_ram_cas_n    <= 1'b1;
			m_ram_we_n     <= 1'b1;
						
			if (maintenance_clocks == 4'hb || maintenance_clocks == 4'h5)	//Auto refresh
			begin 
				m_ram_cs_n <= 1'b0;
				m_ram_ras_n <= 1'b0;
				m_ram_cas_n <= 1'b0;
				m_ram_we_n  <= 1'b1;
			end	else														// NOOP
			begin
				m_ram_cs_n <= 1'b0;
				m_ram_ras_n <= 1'b1;
				m_ram_cas_n <= 1'b1;
				m_ram_we_n  <= 1'b1;
			end
			
			m_ram_dmod  <= `DMOD_GETINPUT;
			// m_ram_addr  <= { 3'b000, 1'b0, 2'b00, 3'b010, 1'b0, 3'b001 };
			if (maintenance_clocks_zero) begin
//				maintenance_mode <= 1'b0;
				m_state <= `RAM_SET_MODE;
//				maintenance_clocks <= 4'h2;			// POSLEDNJE MENJANO
			end	
			// }}}
		end else if (m_state == `RAM_SET_MODE)
		begin
			// {{{
			// Wait
			//m_ram_cs_n     <= 1'b1;
		/*	m_ram_cs_n     <= 1'b1;
			m_ram_ras_n    <= 1'b1;
			m_ram_cas_n    <= 1'b1;
			m_ram_we_n     <= 1'b1;
			m_ram_addr[10] <= 1'b1; */

			if (maintenance_clocks_zero)
			begin
				// Set mode cycle
				m_ram_cs_n  <= 1'b0;
				m_ram_ras_n <= 1'b0;
				m_ram_cas_n <= 1'b0;
				m_ram_we_n  <= 1'b0;
				m_ram_dmod  <= `DMOD_GETINPUT;
				m_ram_addr[10] <= 1'b0;
				
				//maintenance_clocks <= 4'h1;
				//m_state <= `RAM_INITIAL_REFRESH;
				if (maintenance_clocks_zero)
					m_state <= `RAM_OPERATIONAL;
				//maintenance_clocks <= 4'hc;
				//maintenance_clocks_zero <= 1'b0;
			end
		end else if (m_state == `RAM_OPERATIONAL)
		begin
			// execute commands
			maintenance_clocks_zero <= 1'b0;
			if (maintenance_clocks_zero) begin
				maintenance_mode <= 1'b0;
				maintenance_clocks_zero <= 1'b1;
			end	
		end
			// }}}
	end
	// }}}
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Bus return handling
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// o_ram_data
	// {{{
	always @(posedge i_clk)
	if (!word_sel)
		o_ram_data <= r_data[15:0];
	else
		o_ram_data <= r_data[31:16];
	// }}}

	// o_ram_dqm -- byte strobes
	// {{{
	always @(posedge i_clk)
	if (maintenance_mode)
		o_ram_dqm <= 2'b11;
	else if (r_we)
	begin
		if (!word_sel)
			o_ram_dqm <= ~r_sel[1:0];
		else
			o_ram_dqm <= ~r_sel[3:2];
	end else
		o_ram_dqm <= 2'b00;
	// }}}

	always @(posedge i_clk)
	begin
		last_ram_data[0] <= i_ram_data;
		last_ram_data[1] <= last_ram_data[0];
		last_ram_data[2] <= last_ram_data[1];
		last_ram_data[3] <= last_ram_data[2]; 
		last_ram_data[4] <= last_ram_data[3];		
	end

//	always @(posedge i_clk)
//		o_wb_data <= { last_ram_data[0], last_ram_data[2] };
	assign	o_wb_data = { last_ram_data[0], last_ram_data[2] };


//	assign	o_wb_data = { last_ram_data, i_ram_data };

	assign	o_wb_ack  = r_barrell_ack[0];
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Debugging bus
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// The following outputs are not necessary for the functionality of
	// the SDRAM, but they can be used to feed an external "scope" to
	// get an idea of what the internals of this SDRAM are doing.
	//
	// Just be aware of the r_we: it is set based upon the currently pending
	// transaction, or (if none is pending) based upon the last transaction.
	// If you want to capture the first value "written" to the device,
	// you'll need to write a nothing value to the device to set r_we.
	// The first value "written" to the device can be caught in the next
	// interaction after that.
	//
	reg	trigger;
	always @(posedge i_clk)
		trigger <= ((o_wb_data[15:0]==o_wb_data[31:16])
			&&(o_wb_ack)&&(!i_wb_we));


	assign	o_debug = { i_wb_cyc,i_wb_stb,i_wb_we,o_wb_ack, o_wb_stall, // 5
		o_ram_cs_n, o_ram_ras_n, o_ram_cas_n, o_ram_we_n, o_ram_bs,//6
			o_ram_dmod, r_pending, 				//  2
			trigger,					//  1
			o_ram_addr[9:0],				// 10 more
			(r_we) ? { o_ram_data[7:0] }			//  8 values
				: { o_wb_data[23:20], o_wb_data[3:0] }
			// i_ram_data[7:0]
			 };
	// }}}

endmodule
