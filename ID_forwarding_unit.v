`include "opcodes.v"

module ID_forwarding_unit (
	EX_MEM_RegWrite, 
	EX_MEM_rd, 
	MEM_WB_RegWrite, 
	MEM_WB_rd, 
	IF_ID_rs, 
	IF_ID_rt, 
	f_A, 
	f_B
);
	input EX_MEM_RegWrite;
	input [1:0] EX_MEM_rd;
	input MEM_WB_RegWrite;
	input [1:0] MEM_WB_rd;
	input [1:0] IF_ID_rs;
	input [1:0] IF_ID_rt;
	output [1:0] f_A;
	output [1:0] f_B;

	wire EX_rs_hazard;
	wire EX_rt_hazard;

	wire MEM_rs_hazard;
	wire MEM_rt_hazard;

	// Detect when forward should be needed 
	
	assign EX_rs_hazard = (EX_MEM_RegWrite && (EX_MEM_rd == IF_ID_rs));
	assign EX_rt_hazard = (EX_MEM_RegWrite && (EX_MEM_rd == IF_ID_rt));
	assign MEM_rs_hazard = (MEM_WB_RegWrite && (MEM_WB_rd == IF_ID_rs)) && (!EX_rs_hazard);
	assign MEM_rt_hazard = (MEM_WB_RegWrite && (MEM_WB_rd == IF_ID_rt)) && (!EX_rt_hazard);

	assign f_A = EX_rs_hazard ? 2'b10 : (MEM_rs_hazard ? 2'b01 : 2'b00);
	assign f_B = EX_rt_hazard ? 2'b10 : (MEM_rt_hazard ? 2'b01 : 2'b00);

endmodule					

