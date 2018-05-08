`include "opcodes.v" 
`include "alu.v"
`include "register_file.v"
`include "forwarding_unit.v"
`include "hazard_detection_unit.v"
`include "br_resolve_unit.v"
`include "ID_forwarding_unit.v"
`include "btb.v"   
`include "sat_counter.v"

module data_path (
	clk,
	reset_n,
	readM1,
	address1,
	data1,
	readM2,
	writeM2,
	address2,
	data2,
	output_reg,
	instruction,
	PC,
	nextPC,
	signal,
	is_halted,
	num_inst
);

	/* Input / Output Declaration */
	input clk;
	input reset_n;
	output readM1;
	output [`WORD_SIZE-1:0] address1;
	output readM2;
	output writeM2;
	output [`WORD_SIZE-1:0] address2;
	input [`WORD_SIZE-1:0] data1;
	inout [`WORD_SIZE-1:0] data2;
	output wire [`WORD_SIZE-1:0] output_reg;
	output [`WORD_SIZE-1:0] instruction;
	input [`WORD_SIZE-1:0] PC;
	output [`WORD_SIZE-1:0] nextPC;
	input [`SIG_SIZE-1:0] signal;
	output is_halted;
	output [`WORD_SIZE-1:0] num_inst;


	//always read instruction
	assign readM1 = 1;

	assign address1 = PC;
	reg [`WORD_SIZE-1:0] num_inst_counter;

	assign num_inst = num_inst_counter;

	//** IF STAGE **//
	reg [`WORD_SIZE-1:0] IF_ID_ins;
	reg [`WORD_SIZE-1:0] IF_ID_nextPC;
	reg [`WORD_SIZE-1:0] IF_ID_PC;
	//** IF STAGE **//

	//** ID STAGE **//
	assign instruction = IF_ID_ins;
	wire IF_ID_isJAL = signal[15:12] == 4;
	wire IF_ID_isJPR = signal[15:12] == 3;
	wire IF_ID_isJRL = signal[15:12] == 5;
	wire [1:0] rs = IF_ID_ins[11:10];
	wire [1:0] rt = (IF_ID_isJAL || IF_ID_isJRL) ? 2 : IF_ID_ins[9:8];
	wire stall;
	wire [1:0] rd;
	wire isBR = signal[9];

	wire [`WORD_SIZE-1:0] writeData;
	wire [`WORD_SIZE-1:0] readData1;
	wire [`WORD_SIZE-1:0] readData2;
	reg [`WORD_SIZE-1:0] ID_EX_ins;
	reg [`SIG_SIZE-1:0] ID_EX_signal;
	reg [`WORD_SIZE-1:0] ID_EX_readData1;
	reg [`WORD_SIZE-1:0] ID_EX_readData2;
	reg [`WORD_SIZE-1:0] ID_EX_sign_extended;
	reg [1:0] ID_EX_rs;
	reg [1:0] ID_EX_rt;
	reg [1:0] ID_EX_rd;
	reg [`WORD_SIZE-1:0] ID_EX_nextPC;   		//used for JAL

	wire [`WORD_SIZE-1:0] forward_readData1;    //forwarded rs
	wire [`WORD_SIZE-1:0] forward_readData2;    //forwarded rt
	wire [1:0] ID_f_A;                          //choose which value to forward
	wire [1:0] ID_f_B;                          //choose which value to forward

	wire [`WORD_SIZE-1:0] sign_extended = { {8{IF_ID_ins[7]}}, IF_ID_ins[7:0] };
	wire [`WORD_SIZE-1:0] jmp_target = (IF_ID_isJRL || IF_ID_isJPR) ? forward_readData1 : {PC[15:12], IF_ID_ins[11:0]};

	wire [`WORD_SIZE-1:0] br_target = IF_ID_PC + IF_ID_ins[7:0] + 1;

	wire regFileWrite;
	wire bcond;

	/* Set up br_resolve unit and register_file */
	br_resolve_unit BR_RES (forward_readData1, forward_readData2, IF_ID_ins, bcond);
	register_file regFile (rs, rt, rd, writeData, regFileWrite, readData1, readData2, !clk, reset_n);
	
	//** ID STAGE END **//

	//** EX STAGE **//
	
	wire [3:0] OP = ID_EX_signal[3:0];
	wire [3:0] isLHI = ID_EX_signal[15:12] == 1;
	wire [3:0] ID_EX_isJAL = ID_EX_signal[15:12] == 4;
	wire [3:0] ID_EX_isJRL = ID_EX_signal[15:12] == 5;
	wire [3:0] opcode = ID_EX_ins[15:12];

	wire ALUSrc = ID_EX_signal[5];
	wire [`WORD_SIZE-1:0] forwardA;
	wire [`WORD_SIZE-1:0] A = (isLHI == 4'b0001) ? 0 : forwardA;        //if instruction is an LHI, input to ALU is 0
	wire [`WORD_SIZE-1:0] forwardB;
	wire [`WORD_SIZE-1:0] B = ALUSrc ? ID_EX_sign_extended : forwardB;
	wire [`WORD_SIZE-1:0] ALUOut;
	ALU alu(A, B, OP, ALUOut, opcode);

	wire RegDst = ID_EX_signal[11];
	reg [`WORD_SIZE-1:0] EX_MEM_rs;
	reg [`WORD_SIZE-1:0] EX_MEM_rt;
	reg [`WORD_SIZE-1:0] EX_MEM_ALUout;
	reg [1:0] EX_MEM_rd;
	reg [`WORD_SIZE-1:0] EX_MEM_ins;
	reg [`SIG_SIZE-1:0] EX_MEM_sig;
	
	// ** EX STAGE END **//

	//** MEM STAGE **//
	
	wire MemRead = EX_MEM_sig[8];
	wire MemWrite = EX_MEM_sig[6];
	assign data2 = MemRead ? `WORD_SIZE'bz : (MemWrite ? EX_MEM_rt : 0);
	assign readM2 = MemRead ? 1 : 0;
	assign writeM2 = MemWrite ? 1 : 0;
	reg [`WORD_SIZE-1:0] MEM_WB_ins;
	reg [`SIG_SIZE-1:0] MEM_WB_sig;
	reg [`WORD_SIZE-1:0] MEM_WB_data;
	reg [`WORD_SIZE-1:0] MEM_WB_ALUout;
	reg [`WORD_SIZE-1:0] MEM_WB_rs;
	reg [`WORD_SIZE-1:0] MEM_WB_rt;
	reg [1:0] MEM_WB_rd;
	assign address2 = EX_MEM_ALUout;
	
	//** MEM STAGE END **//

	//** WB STAGE **//
	
	wire MemtoReg = MEM_WB_sig[7];
	wire RegWrite = MEM_WB_sig[4];
	reg [`WORD_SIZE-1:0] WWD_output;
	assign writeData = MemtoReg ? MEM_WB_data : MEM_WB_ALUout;
	assign regFileWrite = RegWrite;
	assign output_reg = WWD_output;
	assign rd = MEM_WB_rd;
	
	//** WB STAGE END **//

	/* Forwarding unit section */

	wire [1:0] f_A;
	wire [1:0] f_B;


	forwarding_unit FOW (EX_MEM_sig[4], EX_MEM_rd, MEM_WB_sig[4], MEM_WB_rd, ID_EX_rs, ID_EX_rt, f_A, f_B);
	ID_forwarding_unit ID_FOW (EX_MEM_sig[4], EX_MEM_rd, MEM_WB_sig[4], MEM_WB_rd, rs, rt, ID_f_A, ID_f_B);
	assign forwardA = (f_A == 2'b10) ? EX_MEM_ALUout : ((f_A == 2'b01) ? writeData : ID_EX_readData1);
	assign forwardB = (f_B == 2'b10) ? EX_MEM_ALUout : ((f_B == 2'b01) ? writeData : ID_EX_readData2);
	assign forward_readData1 = (ID_f_A == 2'b10) ? EX_MEM_ALUout : ((ID_f_A == 2'b01) ? writeData : readData1);
	assign forward_readData2 = (ID_f_B == 2'b10) ? EX_MEM_ALUout : ((ID_f_B == 2'b01) ? writeData : readData2);
	
	/* Hazard detection unit section */
	wire isJMP = signal[10];

	hazard_detection_unit HAZ(ID_EX_signal, RegDst ? ID_EX_rd : ID_EX_rt, EX_MEM_sig, EX_MEM_rd, rs, rt, signal, stall);

	assign is_halted = (MEM_WB_sig[15:12] == 2);

	/* Branch prediction section */
	wire [`WORD_SIZE-1:0] btb_result;
	wire take;
	wire target = isBR ? br_target : (isJMP ? jmp_target : jmp_target);
	
	btb BTB(PC, IF_ID_PC, btb_result, target, isBR || isJMP, clk, reset_n);
	sat_counter SAT(bcond, (isBR) && !stall, take, clk, reset_n);
	wire prediction_fail = isBR ? (bcond ? PC != br_target : PC != IF_ID_PC + 1) : (isJMP ? PC!=jmp_target : 0);
	wire flush = prediction_fail;
	wire [`WORD_SIZE-1:0] right_br_target = bcond ? br_target : IF_ID_PC + 1;
	wire [`WORD_SIZE-1:0] predict_PC = isJMP ? btb_result : ((take && isBR) ? btb_result : PC + 1);

	assign nextPC = stall ? PC : ((isBR) ? (!prediction_fail ? predict_PC : right_br_target) : (isJMP ? (!prediction_fail ? predict_PC : jmp_target) : predict_PC));
	
	/* Initialization */
	initial begin
		IF_ID_ins <= `NOP;
		IF_ID_nextPC <= 0;
		num_inst_counter <= 0;
		IF_ID_ins <= `NOP;
		ID_EX_ins <= `NOP;
		ID_EX_signal <= `SIG_SIZE'b0;
	end


	// ** IF STAGE ** //
	always @ (posedge clk) begin
		if(!reset_n) begin
			IF_ID_ins <= `NOP;
			IF_ID_nextPC <= 0;
			num_inst_counter <= 0;
			IF_ID_ins <= `NOP;
			ID_EX_ins <= `NOP;
			ID_EX_signal <= `SIG_SIZE'b0;
		end
		else begin
			if(flush && !stall) IF_ID_ins <= `NOP;
			if (!stall && !flush) begin 
				IF_ID_ins <= data1;
				IF_ID_nextPC <= nextPC;
				IF_ID_PC <= PC;
			end
		end
	end
	//** IF STAGE END **//



	// ** ID STAGE ** //
	always @ (posedge clk) begin
		if(reset_n) begin
			if(!stall) begin
				ID_EX_ins <= IF_ID_ins;
				ID_EX_signal <= signal;
				ID_EX_readData1 <= readData1;
				ID_EX_readData2 <= readData2;
				ID_EX_sign_extended <= sign_extended;
				ID_EX_rs <= rs;
				ID_EX_rt <= rt;
				ID_EX_rd <= IF_ID_ins[7:6];
				ID_EX_nextPC <= IF_ID_nextPC;
			end
			if(stall) begin
				ID_EX_ins <= `NOP;
				ID_EX_signal <= `SIG_SIZE'b0;
			end
		end
	end
	// ** ID STAGE END **//


	// ** EX STAGE **//
	always @ (posedge clk) begin
		EX_MEM_rs <= forwardA;
		EX_MEM_rt <= forwardB;
		EX_MEM_rd <= RegDst ? ID_EX_rd : ID_EX_rt;
		EX_MEM_ALUout <= (ID_EX_isJAL || ID_EX_isJRL)  ? ID_EX_nextPC : ALUOut;
		EX_MEM_ins <= ID_EX_ins;
		EX_MEM_sig <= ID_EX_signal;
	end
	// ** EX STAGE END **//

	// ** MEM STAGE **//
	always @ (posedge clk) begin
		MEM_WB_ins <= EX_MEM_ins;
		MEM_WB_sig <= EX_MEM_sig;
		MEM_WB_rs <= EX_MEM_rs;
		MEM_WB_rt <= EX_MEM_rt;
		MEM_WB_rd <= EX_MEM_rd;
		MEM_WB_ALUout <= EX_MEM_ALUout;
		MEM_WB_data <= data2;
	end

	// ** WB STAGE **//
	always @ (posedge clk) begin
		if(MEM_WB_sig) num_inst_counter <= num_inst_counter + 1;
		WWD_output = MEM_WB_rs;
	end
	// ** WB STAGE END **//
	
endmodule				