`include "opcodes.v"

module br_resolve_unit (
	readData1,
	readData2,
	instruction,
	bcond
);

	input signed [`WORD_SIZE-1:0] readData1;
	input signed [`WORD_SIZE-1:0] readData2;
	input [`WORD_SIZE-1:0] instruction;
	output bcond;

	wire [3:0] opcode = instruction[15:12];
	wire equal = ((readData1 - readData2) == 0) ? 1 : 0;
	wire greater = (readData1 > 0) ? 1 : 0;
	wire less = (readData1 < 0) ? 1 : 0;

	//set bcond to 1 when branch is taken.
	//if not, set to 0
	wire BNE_taken = (opcode == `BNE_OP && !equal) ? 1 : 0;
	wire BEQ_taken = (opcode == `BEQ_OP && equal) ? 1 : 0;
	wire BGZ_taken = (opcode == `BGZ_OP && greater) ? 1 : 0;
	wire BLZ_taken = (opcode == `BLZ_OP && less) ? 1 : 0;

	assign bcond = (BNE_taken || BEQ_taken || BGZ_taken || BLZ_taken) ? 1 : 0;
endmodule					
