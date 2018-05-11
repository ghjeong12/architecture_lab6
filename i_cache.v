`include "opcodes.v"
`define I_CACHE_ENTRY_SIZE 128
// 8 words
`define TAG_BANK_ENTRY_SIZE 32 
//tag[31:19] valid dirty lru //tag valid dirty lru
`define I_CACHE_SIZE 2
						 
module i_cache(IF_PC, i_cache_result, write, clk, reset_n, outside_hit, readM1, address1, data1);

	input [`WORD_SIZE-1:0] IF_PC;
	//input [`WORD_SIZE-1:0] IF_ID_PC;
	//input [`I_CACHE_ENTRY_SIZE-1:0] new_data;
	input write;	// UNUSED
	input clk;
	input reset_n;
	output outside_hit;
	output [`WORD_SIZE-1:0] i_cache_result;

	output readM1;
	output [`WORD_SIZE-1:0] address1;
	input [`WORD_SIZE-1:0] data1;
	wire [`WORD_SIZE-1:0] data1;
	
	assign readM1 = 1;
	//assign address1 = PC;

	reg [`I_CACHE_ENTRY_SIZE-1:0] data_bank [0:`I_CACHE_SIZE-1];
	reg [`TAG_BANK_ENTRY_SIZE-1:0] tag_bank [0:`I_CACHE_SIZE-1];
	reg [`WORD_SIZE-1:0] i;

	wire [12:0] IF_PC_tag = IF_PC[`WORD_SIZE-1:`WORD_SIZE-13];
	wire [0:0] IF_PC_idx = IF_PC[`WORD_SIZE-14:`WORD_SIZE-14];
	wire [1:0] IF_PC_bo = IF_PC[`WORD_SIZE-15:0];

	//wire [12:0] IF_ID_PC_tag = IF_ID_PC[`WORD_SIZE-1:`WORD_SIZE-13];
	//wire [0:0] IF_ID_PC_idx = IF_ID_PC[`WORD_SIZE-14:`WORD_SIZE-14];
	//wire [1:0] IF_ID_PC_bo = IF_ID_PC[`WORD_SIZE-15:0];


	// Check the tag of the PC with the value in the table
	wire hit_1 = (IF_PC_tag == tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13]) && (tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-14] == 1);
	wire hit_2 = (IF_PC_tag == tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-17:`TAG_BANK_ENTRY_SIZE-29]) && (tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-30] == 1);
	wire hit = hit_1 | hit_2;

	//!!!!!! check bo
	//wire [7:0] fst_set_bo_start = 127 - { 6'b000000, IF_PC_bo[1:0] }*16;
	//wire [7:0] fst_set_bo_end = 127 - ({ 6'b000000, IF_PC_bo[1:0] }+1)*16;
	//wire [7:0] snd_set_bo_start = 63 - { 6'b000000, IF_PC_bo[1:0] }*16;
	//wire [7:0] snd_set_bo_end =  63 - ({ 6'b000000, IF_PC_bo[1:0] }+1)*16;
	// bo can be 0 1 2 3 
	reg [3:0] miss_cnt;
	//wire [`WORD_SIZE-1:0] miss_result;
	wire [`WORD_SIZE-1:0] hit_result = hit ? (hit_1 
		? (IF_PC_bo==0 ? data_bank[IF_PC_idx][127:112] : (IF_PC_bo==1 ? data_bank[IF_PC_idx][111:96]: (IF_PC_bo == 2 ? data_bank[IF_PC_idx][95:80]: data_bank[IF_PC_idx][79:64])))	// First set
		: (IF_PC_bo==0 ? data_bank[IF_PC_idx][63:48] : (IF_PC_bo==1 ? data_bank[IF_PC_idx][47:32]: (IF_PC_bo == 2 ? data_bank[IF_PC_idx][31:16]: data_bank[IF_PC_idx][15:0])))		// Second set
		): 0;	//if miss

	assign i_cache_result = (hit==1 && miss_cnt==0) ? hit_result :0 ;
	
	//wire outside_hit;
	assign outside_hit = (hit==1 && miss_cnt==0) ? 1 :0 ;
	
	assign address1 = (miss_cnt == 0) ? IF_PC - (IF_PC%4) :
							(miss_cnt == 1) ? IF_PC - (IF_PC%4) +1 :
							(miss_cnt == 2) ? IF_PC - (IF_PC%4) +2 :
							(miss_cnt == 3) ? IF_PC - (IF_PC%4) +3 :
							0;
	//For instruction,
	//There is now write, and write back!
	always @ (posedge clk) begin
		if(!reset_n) begin
			for(i = 0; i < `I_CACHE_SIZE; i = i + 1) begin
				data_bank[i] = 64'h0000000000000000;
				tag_bank[i] =  32'h00000000;
				miss_cnt = 0;
			end
		end
		else begin
			if(!hit || (miss_cnt != 0)) begin
				begin	// now update cache
					// lru bit 0 is old data!
					if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] == 0) begin
						//evict first one
						if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-15] == 1) begin // if this line is dirty
							// write back
						end 
						
						
						if(miss_cnt == 0) begin 
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-1:`I_CACHE_ENTRY_SIZE-16] <= data1;

							//readM1 = 1;
							//address1 = IF_PC;
						end
						else if(miss_cnt == 1) begin 
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-17:`I_CACHE_ENTRY_SIZE-32] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+1;
						end
						else if(miss_cnt == 2) begin 
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-33:`I_CACHE_ENTRY_SIZE-48] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+2;
						end
						else if(miss_cnt == 3) begin
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-49:`I_CACHE_ENTRY_SIZE-64] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+3;
						end
						else if(miss_cnt == 4) begin 
							///readM1 = 0;
							//address1 = 0;
						end
						
						if (miss_cnt==5) begin	//should be checked whether it should be 5 or 6
							tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13] <= IF_PC_tag;
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-14] <= 1;	//valid
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-15] <= 0;	//dirty
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] <= 1;	//lru
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-32] <= 0;
							miss_cnt <= 0;
						end
						else begin
							miss_cnt <= miss_cnt +1;
						end
					end
					else begin
						//evict second one
						if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-15] == 1) begin // if this line is dirty
							// write back
						end 

						
						
						if(miss_cnt == 0) begin 
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-65:`I_CACHE_ENTRY_SIZE-80] <= data1;

							//readM1 = 1;
							//address1 = IF_PC;
						end
						else if(miss_cnt == 1) begin 
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-81:`I_CACHE_ENTRY_SIZE-96] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+1;
						end
						else if(miss_cnt == 2) begin 
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-97:`I_CACHE_ENTRY_SIZE-112] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+2;
						end
						else if(miss_cnt == 3) begin
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-113:`I_CACHE_ENTRY_SIZE-128] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+3;
						end
						else if(miss_cnt == 4) begin 
							//readM1 = 0;
							//address1 = 0;
						end
						if (miss_cnt==5) begin	//should be checked whether it should be 5 or 6
							tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-17:3] <= IF_PC_tag;
						tag_bank[IF_PC_idx][2] <= 1;	//valid
						tag_bank[IF_PC_idx][1] <= 0;	//dirty
						tag_bank[IF_PC_idx][0] <= 1;	//lru
						tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] <= 0;
							miss_cnt <= 0;
						end
						else begin
							miss_cnt <= miss_cnt +1;
						end
					end 
				end
			end

		end
	end
	
endmodule

