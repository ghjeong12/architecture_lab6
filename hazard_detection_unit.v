`include "opcodes.v"

module hazard_detection_unit (
	ID_EX_signal, 
	ID_EX_rd,
	EX_MEM_signal,
	EX_MEM_rd,  
	IF_ID_rs, 
	IF_ID_rt, 
	IF_ID_signal,
	stall
);
	input [`SIG_SIZE-1:0] ID_EX_signal;
	input [1:0] ID_EX_rd;
	input [`SIG_SIZE-1:0] EX_MEM_signal;
	input [1:0] EX_MEM_rd;
	input [1:0] IF_ID_rs;
	input [1:0] IF_ID_rt;
	input [`SIG_SIZE-1:0] IF_ID_signal;
	output stall;

	wire ID_EX_MemRead = ID_EX_signal[8];
	wire IF_ID_isBR = IF_ID_signal[9];
	wire IF_ID_isJPR = (IF_ID_signal[15:12] == 3);
	wire IF_ID_isJRL = (IF_ID_signal[15:12] == 5);
	wire IF_ID_isRegJMP = IF_ID_isJPR || IF_ID_isJRL;
	wire ID_EX_isNOP = (!ID_EX_signal);
	wire EX_MEM_isNOP = (!EX_MEM_signal);
	wire EX_MEM_MemRead = EX_MEM_signal[8];

	// Stall when data hazard is detected
	wire br_jmp_stall = ID_EX_isNOP ? 0 : ((IF_ID_isBR || IF_ID_isRegJMP) ? ((ID_EX_rd == IF_ID_rs || ID_EX_rd == IF_ID_rt) ? 1 : 0) : 0);
	wire br_jmp_mem_stall = EX_MEM_isNOP ? 0 : (((IF_ID_isBR || IF_ID_isRegJMP) && EX_MEM_MemRead) ? ((EX_MEM_rd == IF_ID_rs || EX_MEM_rd == IF_ID_rt) ? 1 : 0) : 0);
	wire alu_stall = ID_EX_isNOP ? 0 : (ID_EX_MemRead ? ((ID_EX_rd == IF_ID_rs || ID_EX_rd == IF_ID_rt) ? 1 : 0) : 0);

	assign stall = br_jmp_stall || br_jmp_mem_stall || alu_stall;

endmodule					

