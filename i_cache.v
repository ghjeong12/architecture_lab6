`include "opcodes.v"
`define I_CACHE_ENTRY_SIZE 128
// 8 words
`define TAG_BANK_ENTRY_SIZE 32 
//tag[31:19] valid dirty lru //tag valid dirty lru
`define I_CACHE_SIZE 2
						 
module i_cache(IF_PC, IF_ID_PC, i_cache_result, new_data, write, clk, reset_n, hit);

	input [`WORD_SIZE-1:0] IF_PC;
	input [`WORD_SIZE-1:0] IF_ID_PC;
	output [`WORD_SIZE-1:0] i_cache_result;
	input [`I_CACHE_ENTRY_SIZE-1:0] new_data;
	input write;
	input clk;
	input reset_n;
	output hit;

	reg [`I_CACHE_ENTRY_SIZE-1:0] data_bank [0:`I_CACHE_SIZE-1];
	reg [`TAG_BANK_ENTRY_SIZE-1:0] tag_bank [0:`I_CACHE_SIZE-1];
	reg [`WORD_SIZE-1:0] i;

	wire [12:0] IF_PC_tag = IF_PC[`WORD_SIZE-1:`WORD_SIZE-13];
	wire [0:0] IF_PC_idx = IF_PC[`WORD_SIZE-14:`WORD_SIZE-14];
	wire [1:0] IF_PC_bo = IF_PC[`WORD_SIZE-15:0];

	wire [12:0] IF_ID_PC_tag = IF_ID_PC[`WORD_SIZE-1:`WORD_SIZE-13];
	wire [0:0] IF_ID_PC_idx = IF_ID_PC[`WORD_SIZE-14:`WORD_SIZE-14];
	wire [1:0] IF_ID_PC_bo = IF_ID_PC[`WORD_SIZE-15:0];


	// Check the tag of the PC with the value in the table
	wire hit_1 = (IF_PC_tag == tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13]) && (tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-14] == 1);
	wire hit_2 = (IF_PC_tag == tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-17:`TAG_BANK_ENTRY_SIZE-29]) && (tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-30] == 1);
	wire hit = hit_1 | hit_2;

	//!!!!!! check bo
	assign i_cache_result = hit ? (hit_1 ? data_bank[IF_PC_idx][127- IF_PC_bo*16: 127- (IF_PC_bo+1)*16] : data_bank[IF_PC_idx][63- IF_PC_bo*16: 63-(IF_PC_bo+1)*16]) : 0;
	//For instruction,
	//There is now write, and write back!
	reg miss_cnt;
	always @ (posedge clk) begin
		if(!reset_n) begin
			for(i = 0; i < `I_CACHE_SIZE; i = i + 1) begin
				data_bank[i] = 64'h0000000000000000;
				tag_bank[i] =  32'h00000000;
				miss_cnt = 7;
			end
		end
		else begin
			if(!hit) begin
				if(miss_cnt!=0) begin
					miss_cnt--;
				end
				else begin	// now update cache
					miss_cnt = 7;
					// lru bit 0 is old data!
					if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] == 0) begin
						//evict first one
						if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-15] == 1) begin // if this line is dirty
							// write back
						end 
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13] <= IF_PC_tag;
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-14] <= 1;	//valid
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-15] <= 0;	//dirty
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] <= 1;	//lru
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-32] <= 0;
						data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-1:`I_CACHE_ENTRY_SIZE-64] <= new_data;
					end
					else begin
						//evict second one
						if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-15] == 1) begin // if this line is dirty
							// write back
						end 
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-17:3] <= IF_PC_tag;
						tag_bank[IF_PC_idx][2] <= 1;	//valid
						tag_bank[IF_PC_idx][1] <= 0;	//dirty
						tag_bank[IF_PC_idx][0] <= 1;	//lru
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] <= 0;
						data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-65:0] <= new_data;
					end 

				end
			end
		end
	end
	
endmodule

