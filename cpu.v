`timescale 1ns/1ns
`include "opcodes.v"
`include "control_unit.v"

module cpu(Clk, Reset_N, readM1, address1, data1, readM2, writeM2, address2, data2, num_inst, output_port, is_halted);
	input Clk;
	wire Clk;
	input Reset_N;
	wire Reset_N;

	output readM1;
	wire readM1;
	output [`WORD_SIZE-1:0] address1;
	wire [`WORD_SIZE-1:0] address1;
	output readM2;
	wire readM2;
	output writeM2;
	wire writeM2;
	output [`WORD_SIZE-1:0] address2;
	wire [`WORD_SIZE-1:0] address2;

	input [`LINE_SIZE-1:0] data1;
	wire [`LINE_SIZE-1:0] data1;
	inout [`WORD_SIZE-1:0] data2;
	wire [`LINE_SIZE-1:0] data2;

	output [`WORD_SIZE-1:0] num_inst;
	wire [`WORD_SIZE-1:0] num_inst;
	output [`WORD_SIZE-1:0] output_port;
	wire [`WORD_SIZE-1:0] output_port;
	output is_halted;
	wire is_halted;

	wire [`WORD_SIZE-1:0] output_reg;
	wire [`WORD_SIZE-1:0] instruction;
	reg [`WORD_SIZE-1:0] PC;
	wire [`WORD_SIZE-1:0] nextPC;
	wire [`SIG_SIZE-1:0] signal;

	//output port for wwd
	assign output_port = output_reg;

	/* Declaration for I-cache and D-cache */
	wire [`WORD_SIZE-1:0] i_cache_result;
	wire hit;
	i_cache INS_CACHE (PC, i_cache_result, Clk, Reset_N, hit, readM1, address1, data1);
	
	wire [`WORD_SIZE-1:0] d_cache_result;
	wire d_hit;
	wire DP_readM2;
	wire DP_writeM2;
	wire [`WORD_SIZE-1:0] DP_address2;
	wire [`WORD_SIZE-1:0] DP_data2;
	d_cache DATA_CACHE(d_cache_result, Clk, Reset_N, d_hit, 
		DP_readM2, DP_writeM2, DP_address2, DP_data2, readM2, writeM2, address2, data2);
	
	// Set up the data_path and control_unit 
	data_path DP (
		Clk, 
		Reset_N,
		readM1, 
		address1, 
		i_cache_result, 
		DP_readM2, 
		DP_writeM2, 
		DP_address2, 
		DP_data2, 
		output_reg, 
		instruction,
		PC,
		nextPC,
		signal,
		is_halted,
		num_inst,
		hit,
		d_hit
	);

	control_unit CON (instruction, signal);


	initial begin
		PC <= 0;
	end

	// Change the PC value on each clock cycle
	always @ (posedge Clk) begin
		if(!Reset_N) begin
			PC <= 0;
		end
		else begin
			PC <= nextPC;
		end
	end

endmodule
