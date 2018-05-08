`include "opcodes.v" 	   

module control_unit (instruction, signal);
	input [`WORD_SIZE-1:0] instruction;
	output reg [`SIG_SIZE-1:0] signal;
	//signal order : ID (4 bits)
	//	   			RegDst, Jump, Branch, MemRead
	//              MemtoReg, MemWrite, ALUSrc, RegWrite
	//              ALUOp(4 bits)

	// ID : LHI : 1  HLT : 2  JPR : 3   JAL : 4  JRL : 5

	initial
	begin
		signal <= 0;
	end

	always @ (*)
	begin
		if(instruction == `NOP) signal = 0;
		if(instruction[15:12] == `ALU_OP)       // R-type
		begin
			case(instruction[5:0])
				`FUNC_ADD: signal = `SIG_SIZE'h0810;   // ADD
				`FUNC_SUB: signal = `SIG_SIZE'h0811;	
				`FUNC_SHR: signal = `SIG_SIZE'h081a;
				`FUNC_SHL: signal = `SIG_SIZE'h081d;
				`FUNC_ORR: signal = `SIG_SIZE'h0816;
				`FUNC_NOT: signal = `SIG_SIZE'h0819;
				`FUNC_TCP: signal = `SIG_SIZE'h081c;
				`FUNC_AND: signal = `SIG_SIZE'h0815;
				`FUNC_WWD: signal = `SIG_SIZE'h0001;
				`FUNC_HLT: signal = `SIG_SIZE'h2000;
				`FUNC_JPR: signal = `SIG_SIZE'h3400;
				`FUNC_JRL: signal = `SIG_SIZE'h5410;
			endcase
		end
		else
		begin
			case(instruction[15:12])
				`ADI_OP: signal = `SIG_SIZE'h0030;
				`SWD_OP: signal = `SIG_SIZE'h0060;
				`LWD_OP: signal = `SIG_SIZE'h01b0;
				`BNE_OP: signal = `SIG_SIZE'h0201;
				`BEQ_OP: signal = `SIG_SIZE'h0201;
				`BGZ_OP: signal = `SIG_SIZE'h0201;
				`BLZ_OP: signal = `SIG_SIZE'h0201;
				`JMP_OP: signal = `SIG_SIZE'h0400;
				`LHI_OP: signal = `SIG_SIZE'h103f;
				`ORI_OP: signal = `SIG_SIZE'h0036;
				`JAL_OP: signal = `SIG_SIZE'h4410;
			endcase
		end
	end
	
endmodule					