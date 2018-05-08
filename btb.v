`include "opcodes.v"
`define BTB_ENTRY_SIZE 24
`define BTB_SIZE 256
						 
module btb(IF_PC, IF_ID_PC, btb_result, br_target, update, clk, reset_n);

	input [`WORD_SIZE-1:0] IF_PC;
	input [`WORD_SIZE-1:0] IF_ID_PC;
	output [`WORD_SIZE-1:0] btb_result;
	input [`WORD_SIZE-1:0] br_target;
	input update;
	input clk;
	input reset_n;

	reg [`BTB_ENTRY_SIZE-1:0] target_table [0:`BTB_SIZE];
	reg [`WORD_SIZE-1:0] i;

	wire [7:0] IF_PC_tag = IF_PC[`WORD_SIZE-1:`WORD_SIZE-8];
	wire [7:0] IF_PC_idx = IF_PC[`WORD_SIZE-9:0];

	wire [7:0] IF_ID_PC_tag = IF_ID_PC[`WORD_SIZE-1:`WORD_SIZE-8];
	wire [7:0] IF_ID_PC_idx = IF_ID_PC[`WORD_SIZE-9:0];

	// Check the tag of the PC with the value in the table
	wire hit = (IF_PC_tag == target_table[IF_PC_idx][`BTB_ENTRY_SIZE-1:`BTB_ENTRY_SIZE-8]);

	// Return the PC value in the table when BTB hit.
	assign btb_result = hit ? target_table[IF_PC_idx][15:0] : IF_PC + 1;


	always @ (posedge clk) begin
		if(!reset_n) begin
			for(i = 0; i < `BTB_SIZE; i = i + 1) begin
				target_table[i] = 24'h110000;
			end
		end
		else begin
			if(update) begin
				target_table[IF_ID_PC_idx][`BTB_ENTRY_SIZE-1:`BTB_ENTRY_SIZE-8] <= IF_ID_PC_tag;
				target_table[IF_ID_PC_idx][15:0] <= br_target;
			end
		end
	end
	
endmodule


