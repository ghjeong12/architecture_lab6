`include "opcodes.v"

/* 4 words on each cache line, 2-way set associative */
`define I_CACHE_ENTRY_SIZE 128

/* [31:19]tag [18]valid [17]dirty [16]lru [15:3]tag [2]valid [1]dirty [0]lru */
`define TAG_BANK_ENTRY_SIZE 32 
`define I_CACHE_SIZE 2
						 
module i_cache(IF_PC, i_cache_result, clk, reset_n, outside_hit, readM1, address1, data1);

	input [`WORD_SIZE-1:0] IF_PC;
	input clk;
	input reset_n;

	output outside_hit;
	output [`WORD_SIZE-1:0] i_cache_result;
	output readM1;
	output [`WORD_SIZE-1:0] address1;
	
	input [`LINE_SIZE-1:0] data1;
	
	assign readM1 = 1;

	reg [`I_CACHE_ENTRY_SIZE-1:0] data_bank [0:`I_CACHE_SIZE-1];
	reg [`TAG_BANK_ENTRY_SIZE-1:0] tag_bank [0:`I_CACHE_SIZE-1];

	reg [`WORD_SIZE-1:0] i;

	wire [12:0] IF_PC_tag = IF_PC[`WORD_SIZE-1:`WORD_SIZE-13];
	wire [0:0] IF_PC_idx = IF_PC[`WORD_SIZE-14:`WORD_SIZE-14];
	wire [1:0] IF_PC_bo = IF_PC[`WORD_SIZE-15:0];

	// Check the tag of the PC with the value in the table
	wire hit_1 = (IF_PC_tag == tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13]) && (tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-14] == 1);
	wire hit_2 = (IF_PC_tag == tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-17:`TAG_BANK_ENTRY_SIZE-29]) && (tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-30] == 1);
	wire hit = hit_1 | hit_2;

	/* hit result should be set by set and block offset */	
	wire [`WORD_SIZE-1:0] hit_result = hit ? (hit_1 
		? (IF_PC_bo==0 ? data_bank[IF_PC_idx][127:112] : (IF_PC_bo==1 ? data_bank[IF_PC_idx][111:96]: (IF_PC_bo == 2 ? data_bank[IF_PC_idx][95:80]: data_bank[IF_PC_idx][79:64])))	// First set
		: (IF_PC_bo==0 ? data_bank[IF_PC_idx][63:48] : (IF_PC_bo==1 ? data_bank[IF_PC_idx][47:32]: (IF_PC_bo == 2 ? data_bank[IF_PC_idx][31:16]: data_bank[IF_PC_idx][15:0])))		// Second set
		): 0;	//if miss

	reg [3:0] miss_cnt;
	assign i_cache_result = (hit==1 && miss_cnt==0) ? hit_result :0 ;
	
	/* If miss_cnt is not zero, it means cache is handling cache miss */
	assign outside_hit = (hit==1 && miss_cnt==0) ? 1 :0 ;
	
	assign address1 = (miss_cnt) ? IF_PC - (IF_PC % 4) : 0;

	/* This variable is used for statistics */
	reg [`WORD_SIZE-1:0] i_cache_miss_cnt;

	always @ (posedge clk) begin
		if(!reset_n) begin
			for(i = 0; i < `I_CACHE_SIZE; i = i + 1) begin
				data_bank[i] <= 64'h0000000000000000;
				tag_bank[i] <=  32'h00000000;
				miss_cnt <= 0;
			end
			i_cache_miss_cnt <= 0;
		end
		else begin
			if(miss_cnt==1) begin
				i_cache_miss_cnt = i_cache_miss_cnt+1;
			end
			if(!hit || (miss_cnt != 0)) begin
				begin	// now update cache
					// lru bit 0 is old data!
					if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] == 0) begin
						//evict first one
						if(tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-15] == 1) begin // if this line is dirty
							// Write back is not need for I-cache
						end 
						else if(miss_cnt == 3) begin 
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-1 : `I_CACHE_ENTRY_SIZE-64] <= data1;
						end
						if (miss_cnt==4) begin	//should be checked whether it should be 5 or 6
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
							// Write back is not need for I-Cache
						end 
						else if(miss_cnt == 3) begin 
							// Update data bank
							data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-65 : `I_CACHE_ENTRY_SIZE-128] <= data1;
						end
						if (miss_cnt==4) begin	
							// Update tag bank
							tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-17:3] <= IF_PC_tag;
							tag_bank[IF_PC_idx][2] <= 1;	//valid
							tag_bank[IF_PC_idx][1] <= 0;	//dirty
							tag_bank[IF_PC_idx][0] <= 1;	//lru
							tag_bank[IF_PC_idx][`TAG_BANK_ENTRY_SIZE-16] <= 0;	// lru of the another set
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

