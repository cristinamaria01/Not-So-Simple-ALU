// DESIGN SPECIFIC
`define ALU_BUS_WITH 		16
`define ALU_AMM_ADDR_WITH 	8
`define ALU_AMM_DATA_WITH	8   

/**

== Input packets ==

Header beat
+-----------------+--------------+---------------+------------------+
| reserved[15:12] | opcode[11:8] | reserved[7:6] | nof_operands[5:0]|
+-----------------+--------------+---------------+------------------+

Payload beat
+-----------------+----------+----------------------+
| reserved[15:10] | mod[9:8] | operands/address[7:0]|
+-----------------+----------+----------------------+

== Output packets ==

Header beat

+----------------+----------+-------------+
| reserved[15:5] | error[4] | opcode[3:0] |
+----------------+----------+-------------+

Payload beat

+-----------------+--------------+
| reserved[15:12] | result[11:0] |
+-----------------+--------------+

*/

module alu(
	 // Output interface
    output[`ALU_BUS_WITH - 1:0] data_out,
	 output 							  valid_out,
	 output 							  cmd_out,

	 //Input interface
	 input [`ALU_BUS_WITH - 1:0] data_in,
	 input 							  valid_in,
	 input 							  cmd_in,
	 
	 // AMM interface
	 output 									 amm_read,
	 output[`ALU_AMM_ADDR_WITH - 1:0] amm_address,
	 input [`ALU_AMM_DATA_WITH - 1:0] amm_readdata,
	 input 									 amm_waitrequest,
	 input[1:0] 							 amm_response,
	 
	 
	 //clock and reset interface
	 input clk,
	 input rst_n
    ); 
	
	// TODO: Implement Not-so-simple ALU
	`define GET_HEADER     'h00
	`define GET_PAYLOAD    'h10
	`define DECODE         'h20
	`define OPERATION      'h30
	`define GET_OPERAND    'h40
	`define RESULT_HEADER  'h50
	`define RESULT_PAYLOAD 'h60
	
	`define ADD 4'd0
	`define AND 4'd1
	`define OR  4'd2
	`define XOR 4'd3
	`define NOT 4'd4
	`define INC 4'd5
	`define DEC 4'd6
	`define NEG 4'd7 
	`define SHR 4'd8
	`define SHL 4'd9
	
	parameter state_width = 16;
	reg [state_width-1 : 0] state = `GET_HEADER, next_state;
									
	reg[5:0] count, count_reg;
	
	reg[`ALU_BUS_WITH - 1:0] header_reg;
	reg[9:0] payload_reg[62:0],
				payload[62:0];
	reg[7:0] op[62:0], in1, in2;
	reg[5:0] i,j;
	reg[3:0] opcode;
	reg[5:0] nof_operands;
	reg[1:0] mod[62:0];
	reg[7:0] in;
	reg      err,
				semn;
	reg[11:0] result;
	reg[3:0] size_of_result;
	
	reg[`ALU_BUS_WITH - 1:0] data_out_reg;
	reg 							 valid_out_reg;
	reg                      cmd_out_reg;
	
	reg 									amm_read_reg;
	reg[`ALU_AMM_ADDR_WITH - 1:0] amm_address_reg;
	
	assign amm_read    = amm_read_reg;
	assign amm_address = amm_address_reg;
	
	
	
	always@(posedge clk) begin
		if(rst_n != 0) begin
			state <= next_state;
		end
			
				//count <= count_reg;
	end
	
	always@(*) begin
		next_state = `GET_HEADER;
		
		
		case(state)
			
			`GET_HEADER: begin
				
				if(valid_in == 1 && cmd_in == 1) begin
					header_reg = data_in;
					count = 0;
				end
				
				nof_operands = header_reg[5:0];
				opcode       = header_reg[11:8];
				
				if( nof_operands != 0) begin
					next_state = `GET_PAYLOAD;
				end
					else if(nof_operands == 0) begin
						next_state = `RESULT_HEADER;
					end
				
			end
			
			`GET_PAYLOAD: begin
				
				if(valid_in == 1 && cmd_in == 0) begin
					payload_reg[count] = data_in[9:0];
					count = count + 1;
				end
				
				next_state = `DECODE;
			
			end
			
			`DECODE: begin
			
				for(i=0; i < nof_operands; i = i+1) begin
					if(payload_reg[i][9:8] == 2'b00) begin
						op[i] = payload_reg[i][7:0];
						next_state = `OPERATION;
					end
					else if(payload_reg[i][9:8] == 2'b01) begin
						amm_read_reg = 1;
						amm_address_reg = payload_reg[i][7:0];
						next_state = `GET_OPERAND;
					end
				end
		
			end
			
			`GET_OPERAND: begin
				
				if(amm_waitrequest == 1) begin
					next_state = `GET_OPERAND;
				end
					else if(amm_waitrequest != 1) begin
						if(amm_response == 2'b00) begin			// OK
							op[i] = amm_readdata;
						   next_state = `OPERATION;
						end
							else if(amm_response == 2'b00) begin
								err = 1;
								next_state = `RESULT_HEADER;
							end
					end
				
			end
			
			`OPERATION: begin
			
				case(opcode)
					`ADD:begin
						result = 0;
						for(i=0; i < nof_operands; i = i+1) begin
							result = result + op[i];
						end
						size_of_result = 'd12;
						
					end
					
					`AND: begin
						for(i = 0; i < nof_operands; i = i+1)begin
							if(i == 0) begin
								result = op[i];
							end
								else if(i != 0) begin
									result = result && op[i];
								end	
						end
						size_of_result = 'd8;
					end
					
					`OR: begin
						for(i = 0; i < nof_operands; i = i+1)begin
							if(i == 0) begin
								result = op[i];
							end
								else if(i != 0) begin
									result = result && op[i];
								end
						end
						size_of_result = 'd8;
					end
					
					`XOR: begin
						for(i = 0; i < nof_operands; i = i+1)begin
							if(i == 0) begin
								result = op[i];
							end
								else if(i != 0) begin
									result = result && op[i];
								end
						end
						size_of_result = 'd8;
					end
					
					`NOT: begin
						
						if(nof_operands != 1) begin
							err = 1;
						end
							else if(nof_operands == 1) begin
								in     = op[0];
								result = ~in;
							end
						size_of_result = 'd8;
					end
					
					`INC: begin
						if(nof_operands != 1) begin
							err = 1;
						end
							else if(nof_operands == 1) begin	
								in     = op[0];
								result = in + 1'b1;
							end
						size_of_result = 'd8;
					end
					
					`DEC: begin
						if(nof_operands != 1) begin
							err = 1;
						end
							else if(nof_operands == 1) begin	
								in     = op[0];
								result = in - 1'b1;
							end
						size_of_result = 'd8;
					end
					
					`NEG: begin
						if(nof_operands != 1) begin
							err = 1;
						end
							else if(nof_operands == 1) begin	
								in     = op[0][6:0];
								semn   = op[0][7];
								
								if(semn == 1) begin
									result[7] = 0;
									result[6:0] = in;
								end
									else if(semn == 0) begin
										result[7] = 1;
									   result[6:0] = in;
									end
								
							end
						size_of_result = 'd8;
					end
					
					`SHR: begin
						if(nof_operands != 2) begin
							err = 1;
						end
							else if(nof_operands == 2) begin
								in1 = op[0];
								in2 = op[1];
								
								result = in1 >> in2;
							end
						size_of_result = 'd8;
					end
					
					`SHL: begin
						if(nof_operands != 2) begin
							err = 1;
						end
							else if(nof_operands == 2) begin
								in1 = op[0];
								in2 = op[1];
								
								result = in1 << in2;
							end
						size_of_result = 'd8;
					end
					
					endcase
			
				next_state = `RESULT_HEADER;
			end
			
			`RESULT_HEADER: begin
				valid_out_reg = 1;
				cmd_out_reg   = 1;
				if(err == 1) begin
					data_out_reg[4]   = 1;
					data_out_reg[3:0] = opcode;
				end
					else begin
						data_out_reg[4] = 0;
						data_out_reg[3:0] = opcode;
					end
				
				next_state = `RESULT_PAYLOAD;
			
			end
			
			`RESULT_PAYLOAD : begin
				valid_out_reg = 1;
				cmd_out_reg   = 0;
				if(err == 1) begin
					data_out_reg = 16'hbad;
				end
					else begin
						if(size_of_result == 12) begin
							data_out_reg[15:12] = 4'h0;
							data_out_reg[11:0]  = result;
						end
							else if(size_of_result == 8) begin
								data_out_reg[15:8] = 8'h0;
								data_out_reg[7:0]   = result;
							end
					end
				next_state = `GET_HEADER;
			end
		endcase
	end
	
	assign valid_out = valid_out_reg;
	assign cmd_out   = cmd_out_reg;
	assign data_out  = data_out_reg;
	
endmodule
