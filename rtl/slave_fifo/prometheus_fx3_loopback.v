module prometheus_fx3_loopback(
	input  rst_n,
	input  clk_100,
	input  loopback_mode_selected,
	input  i_gpif_in_ch0_rdy_d,
	input  i_gpif_out_ch0_rdy_d,
	input  i_gpif_in_ch1_rdy_d,
	input  i_gpif_out_ch1_rdy_d,
	input  [31:0]data_in_loopback,
	output o_gpif_re_n_loopback_,
	output o_gpif_oe_n_loopback_,
	output o_gpif_we_n_loopback_,
	output loopback_rd_select_slavefifo_addr,
	output [31:0] data_out_loopback
	
);

//internal fifo control signal

reg [1:0] oe_delay_cnt;	
reg rd_oe_delay_cnt; 
wire [31:0] fifo_data_in;

reg o_gpif_re_n_loopback_d1_;
reg o_gpif_re_n_loopback_d2_;
reg o_gpif_re_n_loopback_d3_;
reg o_gpif_re_n_loopback_d4_;

reg [3:0]current_loop_back_state;
reg [3:0]next_loop_back_state;
//parameters for LoopBack mode state machine
parameter [3:0] loop_back_idle                    = 4'd0;
parameter [3:0] loop_back_flagc_rcvd              = 4'd1;
parameter [3:0] loop_back_wait_flagd              = 4'd2;
parameter [3:0] loop_back_read                    = 4'd3;
parameter [3:0] loop_back_read_rd_and_oe_delay    = 4'd4;
parameter [3:0] loop_back_read_oe_delay           = 4'd5;
parameter [3:0] loop_back_wait_flaga              = 4'd6;
parameter [3:0] loop_back_wait_flagb              = 4'd7;
parameter [3:0] loop_back_write                   = 4'd8;
parameter [3:0] loop_back_write_wr_delay          = 4'd9;
parameter [3:0] loop_back_flush_fifo              = 4'd10;



assign o_gpif_re_n_loopback_      = ((current_loop_back_state == loop_back_read) | (current_loop_back_state == loop_back_read_rd_and_oe_delay)) ? 1'b0 : 1'b1;

assign o_gpif_oe_n_loopback_      = ((current_loop_back_state == loop_back_read) | (current_loop_back_state == loop_back_read_rd_and_oe_delay) | (current_loop_back_state == loop_back_read_oe_delay)) ? 1'b0 : 1'b1; 

assign o_gpif_we_n_loopback_      = ((current_loop_back_state == loop_back_write)/* | (current_loop_back_state == loop_back_write_wr_delay)*/) ? 1'b0 : 1'b1;


//delay for reading from slave fifo(data will be available after two clk cycle) 
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		o_gpif_re_n_loopback_d1_ <= 1'b1;
		o_gpif_re_n_loopback_d2_ <= 1'b1;  
		o_gpif_re_n_loopback_d3_ <= 1'b1;
		o_gpif_re_n_loopback_d4_ <= 1'b1;
 	end else begin
 		o_gpif_re_n_loopback_d1_ <= o_gpif_re_n_loopback_;
		o_gpif_re_n_loopback_d2_ <= o_gpif_re_n_loopback_d1_; 
		o_gpif_re_n_loopback_d3_ <= o_gpif_re_n_loopback_d2_;
		o_gpif_re_n_loopback_d4_ <= o_gpif_re_n_loopback_d3_;
	end	
end


//Control signal of fifo for LoopBack mode 
assign fifo_push  = (o_gpif_re_n_loopback_d4_ == 1'b0) & loopback_mode_selected;
assign fifo_pop   = (current_loop_back_state == loop_back_write);
assign fifo_flush = (current_loop_back_state == loop_back_flush_fifo); 

assign fifo_data_in = (o_gpif_re_n_loopback_d4_ == 1'b0) ? data_in_loopback : 32'd0;


assign loopback_rd_select_slavefifo_addr = ((current_loop_back_state == loop_back_flagc_rcvd) | (current_loop_back_state == loop_back_wait_flagd) | (current_loop_back_state == loop_back_read) | (current_loop_back_state == loop_back_read_rd_and_oe_delay) | (current_loop_back_state == loop_back_read_oe_delay));



//assign loopback_wr_select_fifo_addr = 

//counter to delay the read and output enable signal
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		rd_oe_delay_cnt <= 1'b0;
	end else if(current_loop_back_state == loop_back_read) begin
		rd_oe_delay_cnt <= 1'b1;
        end else if((current_loop_back_state == loop_back_read_rd_and_oe_delay) & (rd_oe_delay_cnt > 1'b0))begin
		rd_oe_delay_cnt <= rd_oe_delay_cnt - 1'b1;
	end else begin
		rd_oe_delay_cnt <= rd_oe_delay_cnt;
	end	
end

//Counter to delay the OUTPUT Enable(oe) signal
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		oe_delay_cnt <= 2'd0;
	end else if(current_loop_back_state == loop_back_read_rd_and_oe_delay) begin
		oe_delay_cnt <= 2'd2;
        end else if((current_loop_back_state == loop_back_read_oe_delay) & (oe_delay_cnt > 1'b0))begin
		oe_delay_cnt <= oe_delay_cnt - 1'b1;
	end else begin
		oe_delay_cnt <= oe_delay_cnt;
	end	
end


//LoopBack state machine
always @(posedge clk_100, negedge rst_n)begin
	if(!rst_n)begin 
		current_loop_back_state <= loop_back_idle;
	end else begin
		current_loop_back_state <= next_loop_back_state;
	end	
end

//LoopBack mode state machine combo
always @(*)begin
	next_loop_back_state = current_loop_back_state;
	case(current_loop_back_state)
	loop_back_idle:begin
		if(loopback_mode_selected & (i_gpif_in_ch1_rdy_d == 1'b1))begin
			next_loop_back_state = loop_back_flagc_rcvd;
		end else begin
			next_loop_back_state = loop_back_idle;
		end
	end	
        loop_back_flagc_rcvd:begin
		next_loop_back_state = loop_back_wait_flagd;
	end	
	loop_back_wait_flagd:begin
		if(i_gpif_out_ch1_rdy_d == 1'b1)begin
			next_loop_back_state = loop_back_read;
		end else begin
			next_loop_back_state = loop_back_wait_flagd;
		end
	end	
        loop_back_read :begin
                if(i_gpif_out_ch1_rdy_d == 1'b0)begin
			next_loop_back_state = loop_back_read_rd_and_oe_delay;
		end else begin
			next_loop_back_state = loop_back_read;
		end
	end
	loop_back_read_rd_and_oe_delay : begin
		if(rd_oe_delay_cnt == 0)begin
			next_loop_back_state = loop_back_read_oe_delay;
		end else begin
			next_loop_back_state = loop_back_read_rd_and_oe_delay;
		end
	end
        loop_back_read_oe_delay : begin
		if(oe_delay_cnt == 0)begin
			next_loop_back_state = loop_back_wait_flaga;
		end else begin
			next_loop_back_state = loop_back_read_oe_delay;
		end
	end
	loop_back_wait_flaga :begin
		if (i_gpif_in_ch0_rdy_d == 1'b1)begin
			next_loop_back_state = loop_back_wait_flagb; 
		end else begin
			next_loop_back_state = loop_back_wait_flaga; 
		end
	end
	loop_back_wait_flagb :begin
		if (i_gpif_out_ch0_rdy_d == 1'b1)begin
			next_loop_back_state = loop_back_write; 
		end else begin
			next_loop_back_state = loop_back_wait_flagb; 
		end
	end
	loop_back_write:begin
		if(i_gpif_out_ch0_rdy_d == 1'b0)begin
			next_loop_back_state = loop_back_write_wr_delay;
		end else begin
		 	next_loop_back_state = loop_back_write;
		end
	end
        loop_back_write_wr_delay:begin
			next_loop_back_state = loop_back_flush_fifo;
	end
	loop_back_flush_fifo:begin
		next_loop_back_state = loop_back_idle;
	end
	endcase
end




///fifo instantiation for loop back mode
fifo fifo_inst(
	.din(fifo_data_in)
        ,.write_busy(fifo_push)
	,.fifo_full()
	,.dout(data_out_loopback)
	,.read_busy(fifo_pop)
	,.fifo_empty()
	,.fifo_clk(clk_100)
	,.rst_n(rst_n)
	,.fifo_flush(fifo_flush)
);


endmodule
