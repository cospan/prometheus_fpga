module prometheus_fx3_partial(
	input  rst_n,
        input  clk_100,
        input  partial_mode_selected,
        input  i_gpif_in_ch0_rdy_d,
        input  i_gpif_out_ch0_rdy_d,
        output o_gpif_we_n_partial_,
	output o_gpif_pkt_end_n_partial_,
        output [31:0] data_out_partial
);

reg [2:0]current_partial_state;
reg [2:0]next_partial_state;
//parameters for PARTIAL mode state machine
parameter [2:0] partial_idle                      = 3'd0;
parameter [2:0] partial_wait_flagb                = 3'd1;
parameter [2:0] partial_write                     = 3'd2;
parameter [2:0] partial_write_wr_delay            = 3'd3;
parameter [2:0] partial_wait		          = 3'd4;


reg [3:0] strob_cnt;
reg       strob; 
reg [3:0] short_pkt_cnt;
reg [31:0]data_gen_partial;
reg o_gpif_pkt_end_n_prtl_;

assign o_gpif_we_n_partial_ = ((current_partial_state == partial_write) && (i_gpif_out_ch0_rdy_d == 1'b1)) ? 1'b0 : 1'b1;

//counters for short pkt
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		short_pkt_cnt <= 4'd0;
	end else if(current_partial_state == partial_idle)begin
		short_pkt_cnt <= 4'd0;
	end else if((current_partial_state == partial_write))begin
		short_pkt_cnt <= short_pkt_cnt + 1'b1;
	end	
end

//counter to generate the strob for PARTIAL
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		strob_cnt <= 4'd0;
	end else if(current_partial_state == partial_idle)begin
		strob_cnt <= 4'd0;
	end else if(current_partial_state == partial_wait)begin
		strob_cnt <= strob_cnt + 1'b1;
	end	
end

//Strob logic
always@(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin
		strob <= 1'b0;
	end else if((current_partial_state == partial_wait) && (strob_cnt == 4'b0111)) begin
		strob <= !strob;
	end
end

always@(*)begin
	if((partial_mode_selected) & (strob == 1'b1) & (short_pkt_cnt == 4'b1111))begin
		o_gpif_pkt_end_n_prtl_ = 1'b0;
	end else begin
		o_gpif_pkt_end_n_prtl_ = 1'b1;
	end
end	

assign o_gpif_pkt_end_n_partial_ = o_gpif_pkt_end_n_prtl_;


//PARTIAL mode state machine
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		current_partial_state <= partial_idle;
	end else begin
		current_partial_state <= next_partial_state;
	end	
end

//PARTIAL mode state machine combo
always @(*)begin
	next_partial_state = current_partial_state;
	case(current_partial_state)
	partial_idle:begin
		if((partial_mode_selected) & (i_gpif_in_ch0_rdy_d == 1'b1))begin
			next_partial_state = partial_wait_flagb; 
		end else begin
			next_partial_state = partial_idle;
		end	
	end
	partial_wait_flagb :begin
		if (i_gpif_out_ch0_rdy_d == 1'b1)begin
			next_partial_state = partial_write; 
		end else begin
			next_partial_state = partial_wait_flagb; 
		end
	end
	partial_write:begin
		if((i_gpif_out_ch0_rdy_d == 1'b0) | ((strob == 1'b1) & (short_pkt_cnt == 4'b1111)))begin
			next_partial_state = partial_write_wr_delay;
		end else begin
		 	next_partial_state = partial_write;
		end
	end
        partial_write_wr_delay:begin
		next_partial_state = partial_wait;
	end
	partial_wait:begin
		if(strob_cnt == 4'b0111)begin
			next_partial_state = partial_idle;
		end else begin
			next_partial_state = partial_wait;
		end
	end	
	endcase
end


//data generator counter for Partial mode
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		data_gen_partial <= 32'd0;
	end else if((o_gpif_we_n_partial_ == 1'b0) & (partial_mode_selected)) begin
		data_gen_partial <= data_gen_partial + 1;
	end else if (!partial_mode_selected) begin
		data_gen_partial <= 32'd0;
	end	
end

assign data_out_partial = data_gen_partial;

endmodule

