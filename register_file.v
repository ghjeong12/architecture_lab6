`include "opcodes.v" 	   

module register_file (r1, r2, rd, writeData, regWrite, readData1, readData2, clk, reset_n);
	input [1:0] r1;
	input [1:0] r2;
	input [1:0] rd;
	input [`WORD_SIZE-1:0] writeData;
	input regWrite;
	output reg [`WORD_SIZE-1:0] readData1;
	output reg [`WORD_SIZE-1:0] readData2;
	input clk;
	input reset_n;

	reg [`WORD_SIZE-1:0] registers[0:3];

	reg i;

	initial
	begin
		registers[0] = 0;
		registers[1] = 0;
		registers[2] = 0;
		registers[3] = 0;
	end

	always @(*)
	begin
		if(!reset_n)
		begin
			registers[0] = 0;
			registers[1] = 0;
			registers[2] = 0;
			registers[3] = 0;
		end
		else
		begin
			readData1 <= registers[r1];
			readData2 <= registers[r2];
		end
	end


	always @(posedge clk)
	begin
		if(regWrite) registers[rd] = writeData;
	end

	
endmodule				