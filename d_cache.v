`include "opcodes.v"
`define D_CACHE_ENTRY_SIZE 128
// 8 words
`define TAG_BANK_ENTRY_SIZE 32 
//tag[31:19] valid dirty lru //tag valid dirty lru
`define D_CACHE_SIZE 2
						 
module d_cache(d_cache_result, clk, reset_n, outside_hit, 
	DP_readM2, DP_writeM2, DP_address2, DP_data2, readM2, writeM2, address2, data2);

	output [`WORD_SIZE-1:0] d_cache_result;	// Returns the result of read
	input clk;
	input reset_n;
	output outside_hit;

	input DP_readM2;
	input DP_writeM2;
	input [`WORD_SIZE-1:0] DP_address2;
	inout [`WORD_SIZE-1:0] DP_data2;

	output readM2;
	output writeM2;
	output [`WORD_SIZE-1:0] address2;
	inout [`LINE_SIZE-1:0] data2;
	
	//wire [`WORD_SIZE-1:0] data1;
	//assign readM1 = 1;
	//assign address1 = PC;

	reg [`D_CACHE_ENTRY_SIZE-1:0] data_bank [0:`D_CACHE_SIZE-1];
	reg [`TAG_BANK_ENTRY_SIZE-1:0] tag_bank [0:`D_CACHE_SIZE-1];
	reg [`WORD_SIZE-1:0] i;

	wire [12:0] addr_tag = DP_address2[`WORD_SIZE-1:`WORD_SIZE-13];
	wire [0:0] addr_idx = DP_address2[`WORD_SIZE-14:`WORD_SIZE-14];
	wire [1:0] addr_bo = DP_address2[`WORD_SIZE-15:0];

	//wire [12:0] IF_ID_PC_tag = IF_ID_PC[`WORD_SIZE-1:`WORD_SIZE-13];
	//wire [0:0] IF_ID_PC_idx = IF_ID_PC[`WORD_SIZE-14:`WORD_SIZE-14];
	//wire [1:0] IF_ID_PC_bo = IF_ID_PC[`WORD_SIZE-15:0];


	// Check the tag of the PC with the value in the table
	wire hit_1 = (addr_tag == tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13]) && (tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-14] == 1);
	wire hit_2 = (addr_tag == tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-17:`TAG_BANK_ENTRY_SIZE-29]) && (tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-30] == 1);
	wire hit = (!DP_readM2 && !DP_writeM2) ? 1 : (hit_1 | hit_2);

	//!!!!!! check bo
	//wire [7:0] fst_set_bo_start = 127 - { 6'b000000, IF_PC_bo[1:0] }*16;
	//wire [7:0] fst_set_bo_end = 127 - ({ 6'b000000, IF_PC_bo[1:0] }+1)*16;
	//wire [7:0] snd_set_bo_start = 63 - { 6'b000000, IF_PC_bo[1:0] }*16;
	//wire [7:0] snd_set_bo_end =  63 - ({ 6'b000000, IF_PC_bo[1:0] }+1)*16;
	// bo can be 0 1 2 3 
	reg [3:0] miss_cnt;
	//wire [`WORD_SIZE-1:0] miss_result;
	wire [`WORD_SIZE-1:0] hit_result = hit ? (hit_1 
		? (addr_bo==0 ? data_bank[addr_idx][127:112] : (addr_bo==1 ? data_bank[addr_idx][111:96]: (addr_bo == 2 ? data_bank[addr_idx][95:80]: data_bank[addr_idx][79:64])))	// First set
		: (addr_bo==0 ? data_bank[addr_idx][63:48] : (addr_bo==1 ? data_bank[addr_idx][47:32]: (addr_bo == 2 ? data_bank[addr_idx][31:16]: data_bank[addr_idx][15:0])))		// Second set
		): 0;	//if miss

	assign d_cache_result = (hit==1 && miss_cnt==0) ? hit_result :0 ;
	assign DP_data2 = DP_readM2 ? d_cache_result : `LINE_SIZE'bz;
	//if(writeM2)memory[address2] <= data2;															  

	/* For cache write */
	reg [12:0] prev_addr_tag;
	reg [0:0]  prev_addr_idx;
	reg [15:0] prev_addr;
	reg [0:0] set;
	reg evicted;

	//wire outside_hit;
	assign outside_hit = (hit==1 && miss_cnt==0) ? 1 :0 ;
	
	assign address2 = (miss_cnt) ? ((evicted && miss_cnt==1)?prev_addr :DP_address2 - (DP_address2 % 4)) : 0;
	assign writeM2 = (miss_cnt==1) ? ((evicted==1) ? 1 : 0) : 0;	// To be implemented
	assign readM2 = (miss_cnt==2) ? 1 : 0;
	
	assign data2 = DP_writeM2 ? 
		((miss_cnt==1 && evicted) 
			? ( (set==0)?data_bank[prev_addr_idx][`D_CACHE_ENTRY_SIZE-1 : `D_CACHE_ENTRY_SIZE-64] 
			:data_bank[prev_addr_idx][`D_CACHE_ENTRY_SIZE-65 : `D_CACHE_ENTRY_SIZE-128]) : `LINE_SIZE'bz) 
		: `LINE_SIZE'bz;

	
	//For instruction,
	//There is now write, and write back!
	always @ (posedge clk) begin
		if(!reset_n) begin
			for(i = 0; i < `D_CACHE_SIZE; i = i + 1) begin
				data_bank[i] = 64'h0000000000000000;
				tag_bank[i] =  32'h00000000;
				miss_cnt = 0;
				evicted=0;
			end
		end
		else begin
			if(!hit || (miss_cnt != 0)) begin
				begin	// now update cache
					// lru bit 0 is old data!
					if(tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-16] == 0) begin
						//evict first one						
						if(miss_cnt == 0) begin 
							
							//data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-1:`I_CACHE_ENTRY_SIZE-16] <= data1;

							//readM1 = 1;
							//address1 = IF_PC;
						end
						else if(miss_cnt == 1) begin 
							if(tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] == 1) begin // if this line is dirty, write back!
								prev_addr_tag = tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13];
								prev_addr_idx = addr_idx;
								prev_addr = {prev_addr_tag,prev_addr_idx,2'b00};
								set = 0;
								evicted = 1;
							end 
							//data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-17:`I_CACHE_ENTRY_SIZE-32] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+1;
						end
						else if(miss_cnt == 2) begin 
							evicted = 0;
							//data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-33:`I_CACHE_ENTRY_SIZE-48] <= data1;
							//readM1 = 1;
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-1 : `D_CACHE_ENTRY_SIZE-64] <= data2;
						end
						else if(miss_cnt == 3) begin	/* Cache update for write */
							if(DP_writeM2) begin
								if(addr_bo==0) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-1:`D_CACHE_ENTRY_SIZE-16] <= DP_data2;
								end
								if(addr_bo==1) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-17:`D_CACHE_ENTRY_SIZE-32] <= DP_data2;
								end
								if(addr_bo==2) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-33:`D_CACHE_ENTRY_SIZE-48] <= DP_data2;
								end
								if(addr_bo==2) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-49:`D_CACHE_ENTRY_SIZE-64] <= DP_data2;
								end
							end
						end
						/*
						else if(miss_cnt == 4) begin 
							///readM1 = 0;
							//address1 = 0;
						end
						*/
						if (miss_cnt==4) begin	//should be checked whether it should be 5 or 6
							tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13] <= addr_tag;
							tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-14] <= 1;	//valid
							
							tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-16] <= 1;	//lru
							tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-32] <= 0;
							
							if(DP_writeM2) begin
								tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] <= 1;	//dirty
							end // if(DP_writeM2)
							else begin
								tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] <= 0;	//dirty
							end // else

							miss_cnt <= 0;
						end
						else begin
							miss_cnt <= miss_cnt +1;
						end
					end
					else begin
						//evict second one
						if(miss_cnt == 0) begin 
							//data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-65:`I_CACHE_ENTRY_SIZE-80] <= data1;
							//readM1 = 1;
							//address1 = IF_PC;
						end
						else if(miss_cnt == 1) begin 
							if(tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] == 1) begin // if this line is dirty, write back!
								prev_addr_tag = tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13];
								prev_addr_idx = addr_idx;
								prev_addr = {prev_addr_tag,prev_addr_idx,2'b00};
								set = 1;
								evicted = 1;

							end 
						end
						else if(miss_cnt == 2) begin 
							evicted = 0;
							//data_bank[IF_PC_idx][`I_CACHE_ENTRY_SIZE-97:`I_CACHE_ENTRY_SIZE-2] <= data1;
							//readM1 = 1;
							//address1 = IF_PC+2;
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-65 : `D_CACHE_ENTRY_SIZE-128] <= data2;

						end
						else if(miss_cnt == 3) begin
							if(DP_writeM2) begin
								if(addr_bo==0) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-65:`D_CACHE_ENTRY_SIZE-80] <= DP_data2;
								end
								if(addr_bo==1) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-81:`D_CACHE_ENTRY_SIZE-96] <= DP_data2;
								end
								if(addr_bo==2) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-97:`D_CACHE_ENTRY_SIZE-112] <= DP_data2;
								end
								if(addr_bo==2) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-113:`D_CACHE_ENTRY_SIZE-128] <= DP_data2;
								end
							end
						end
						/*
						else if(miss_cnt == 4) begin 
							//readM1 = 0;
							//address1 = 0;
						end

						*/
						if (miss_cnt==4) begin	//should be checked whether it should be 5 or 6
							tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-17:3] <= addr_tag;
							tag_bank[addr_idx][2] <= 1;	//valid
							tag_bank[addr_idx][0] <= 1;	//lru
							tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-16] <= 0;
							
							if(DP_writeM2) begin	/* dirty bit setting */
								tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] <= 1;
							end // if(DP_writeM2)
							else begin
								tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] <= 0;
							end // else

							miss_cnt <= 0;
						end
						else begin
							miss_cnt <= miss_cnt +1;
						end
					end 
				end
			end // if(!hit || (miss_cnt != 0))
			else if(hit) begin
				if(DP_writeM2) begin
					if(hit_1) begin
						if(addr_bo==0) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-1:`D_CACHE_ENTRY_SIZE-16] <= DP_data2;
						end
						if(addr_bo==1) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-17:`D_CACHE_ENTRY_SIZE-32] <= DP_data2;
						end
						if(addr_bo==2) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-33:`D_CACHE_ENTRY_SIZE-48] <= DP_data2;
						end
						if(addr_bo==2) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-49:`D_CACHE_ENTRY_SIZE-64] <= DP_data2;
						end
					end
					else if(hit_2) begin
						if(addr_bo==0) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-65:`D_CACHE_ENTRY_SIZE-80] <= DP_data2;
						end
						if(addr_bo==1) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-81:`D_CACHE_ENTRY_SIZE-96] <= DP_data2;
						end
						if(addr_bo==2) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-97:`D_CACHE_ENTRY_SIZE-112] <= DP_data2;
						end
						if(addr_bo==2) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-113:`D_CACHE_ENTRY_SIZE-128] <= DP_data2;
						end
					end
					tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] <= 1;
				end
			end
		end // else
	end
	
endmodule

