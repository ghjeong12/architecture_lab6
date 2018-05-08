`include "opcodes.v"

//saturation counter for BTB
						 
module sat_counter(taken, update, prediction, clk, reset_n);

	input taken;
	input update;
	output prediction;
	input clk;
	input reset_n;

	reg [1:0] counter;

	/* 	If counter value is 2 or 3, predict to take.
		Otherwise, predict to not take.					*/
	assign prediction = (counter >= 2) ? 1 : 0;

	always @ (posedge clk) begin
		if(!reset_n) begin
			counter <= 0;
		end
		else begin
			if(update) begin
				if(taken) begin                // if branch is taken, increment counter
					if(counter != 2'b11)
						counter = counter + 1;
				end
				else begin
					if(counter != 2'b00)       // if branch is not taken, decrement counter
						counter = counter - 1;
				end
			end
		end
	end
	
endmodule


