`include "opcodes.v"

module forwarding_unit (
	EX_MEM_RegWrite, 
	EX_MEM_rd, 
	MEM_WB_RegWrite, 
	MEM_WB_rd, 
	ID_EX_rs, 
	ID_EX_rt, 
	f_A, 
	f_B
);
	input EX_MEM_RegWrite;
	input [1:0] EX_MEM_rd;
	input MEM_WB_RegWrite;
	input [1:0] MEM_WB_rd;
	input [1:0] ID_EX_rs;
	input [1:0] ID_EX_rt;
	output [1:0] f_A;
	output [1:0] f_B;

	wire EX_rs_hazard;
	wire EX_rt_hazard;

	wire MEM_rs_hazard;
	wire MEM_rt_hazard;

	assign EX_rs_hazard = (EX_MEM_RegWrite && (EX_MEM_rd == ID_EX_rs));
	assign EX_rt_hazard = (EX_MEM_RegWrite && (EX_MEM_rd == ID_EX_rt));
	assign MEM_rs_hazard = (MEM_WB_RegWrite && (MEM_WB_rd == ID_EX_rs)) && (!EX_rs_hazard);
	assign MEM_rt_hazard = (MEM_WB_RegWrite && (MEM_WB_rd == ID_EX_rt)) && (!EX_rt_hazard);

	assign f_A = EX_rs_hazard ? 2'b10 : (MEM_rs_hazard ? 2'b01 : 2'b00);
	assign f_B = EX_rt_hazard ? 2'b10 : (MEM_rt_hazard ? 2'b01 : 2'b00);

endmodule					
