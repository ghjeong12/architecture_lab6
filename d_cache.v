`include "opcodes.v"

/* 4 words on each cache line, 2-way set associative */
`define D_CACHE_ENTRY_SIZE 128

/* [31:19]tag [18]valid [17]dirty [16]lru [15:3]tag [2]valid [1]dirty [0]lru */
`define TAG_BANK_ENTRY_SIZE 32 
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

	reg [`D_CACHE_ENTRY_SIZE-1:0] data_bank [0:`D_CACHE_SIZE-1];
	reg [`TAG_BANK_ENTRY_SIZE-1:0] tag_bank [0:`D_CACHE_SIZE-1];
	reg [`WORD_SIZE-1:0] i;

	wire [12:0] addr_tag = DP_address2[`WORD_SIZE-1:`WORD_SIZE-13];
	wire [0:0] addr_idx = DP_address2[`WORD_SIZE-14:`WORD_SIZE-14];
	wire [1:0] addr_bo = DP_address2[`WORD_SIZE-15:0];

	// Check the tag of the PC with the value in the table
	wire hit_1 = (addr_tag == tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13]) && (tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-14] == 1);
	wire hit_2 = (addr_tag == tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-17:`TAG_BANK_ENTRY_SIZE-29]) && (tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-30] == 1);
	wire hit = (!DP_readM2 && !DP_writeM2) ? 1 : (hit_1 | hit_2);

	reg [3:0] miss_cnt;
	//wire [`WORD_SIZE-1:0] miss_result;
	wire [`WORD_SIZE-1:0] hit_result = hit ? (hit_1 
		? (addr_bo==0 ? data_bank[addr_idx][127:112] : (addr_bo==1 ? data_bank[addr_idx][111:96]: (addr_bo == 2 ? data_bank[addr_idx][95:80]: data_bank[addr_idx][79:64])))	// First set
		: (addr_bo==0 ? data_bank[addr_idx][63:48] : (addr_bo==1 ? data_bank[addr_idx][47:32]: (addr_bo == 2 ? data_bank[addr_idx][31:16]: data_bank[addr_idx][15:0])))		// Second set
		): 0;	//if miss

	assign d_cache_result = (hit==1 && miss_cnt==0) ? hit_result :0 ;
	assign DP_data2 = DP_readM2 ? d_cache_result : `LINE_SIZE'bz;


	assign outside_hit = (hit==1 && miss_cnt==0) ? 1 :0 ;
	wire addr_dirty_bit = tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15];
	
	/* For cache write */
	assign address2 = (miss_cnt) ? ((addr_dirty_bit == 1 && miss_cnt==1)?{tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-1:`TAG_BANK_ENTRY_SIZE-13],addr_idx,2'b00} :DP_address2 - (DP_address2 % 4)) : 0;
	assign writeM2 = (miss_cnt==1) ? ((addr_dirty_bit == 1) ? 1 : 0) : 0;	// To be implemented
	assign readM2 = (miss_cnt==2) ? 1 : 0;
	
	assign data2 = DP_writeM2 ? 
		((miss_cnt==1 && (tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] == 1)) 
			? ( (tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-16] == 0)?data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-1 : `D_CACHE_ENTRY_SIZE-64] 
			:data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-65 : `D_CACHE_ENTRY_SIZE-128]) : `LINE_SIZE'bz) 
		: `LINE_SIZE'bz;

	reg [`WORD_SIZE-1:0] d_cache_access_cnt;
	reg [`WORD_SIZE-1:0] d_cache_miss_cnt;
	reg count_check;
	always @ (posedge clk) begin
		if(count_check == 0 && (DP_readM2 || DP_writeM2)) begin
			count_check <= 1;
			d_cache_access_cnt <= d_cache_access_cnt + 1;
		end
		else if(!(DP_readM2 || DP_writeM2)) count_check <= 0;

		if(miss_cnt == 2) d_cache_miss_cnt <= d_cache_miss_cnt + 1;
	end // always @ (posedge DP_writeM2)
	
	always @ (posedge clk) begin
		if(!reset_n) begin
			for(i = 0; i < `D_CACHE_SIZE; i = i + 1) begin
				data_bank[i] = 64'h0000000000000000;
				tag_bank[i] =  32'h00000000;
				miss_cnt = 0;
			end
			d_cache_access_cnt <= 0;
			d_cache_miss_cnt <= 0;
			count_check <= 0;
		end
		else begin
			if(!hit || (miss_cnt != 0)) begin
				begin	// now update cache
					// lru bit 0 is old data!
					if(tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-16] == 0) begin
						//evict first one						
						if(miss_cnt == 2) begin 
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
								if(addr_bo==3) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-49:`D_CACHE_ENTRY_SIZE-64] <= DP_data2;
								end
							end
						end
						if (miss_cnt==4) begin	
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
						if(miss_cnt == 2) begin 
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
								if(addr_bo==3) begin
									data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-113:`D_CACHE_ENTRY_SIZE-128] <= DP_data2;
								end
							end
						end
						if (miss_cnt==4) begin
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
			else if(hit) begin /* Handling write operation when cache hit*/ 
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
						if(addr_bo==3) begin
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
						if(addr_bo==3) begin
							data_bank[addr_idx][`D_CACHE_ENTRY_SIZE-113:`D_CACHE_ENTRY_SIZE-128] <= DP_data2;
						end
					end
					tag_bank[addr_idx][`TAG_BANK_ENTRY_SIZE-15] <= 1;
				end
			end
		end // else
	end
	
endmodule

