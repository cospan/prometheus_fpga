`timescale 1 ns / 1 ns


`define RD_ENABLE_DELAY 2

module fx3_bus_in_path (
input               clk,
input               rst,

//Control From Master
//input               i_read_fx3_packet,
output              o_read_fx3_finished,
input               i_read_flow_cntrl,

input       [23:0]  i_packet_size,

//Incomming Data

//Control Signals
output              o_output_enable,
output              o_read_enable,

//Processed Data
output              o_data_valid,
input               i_in_path_enable,
output              o_in_path_busy,
output              o_in_path_finished
);


//Local Parameters
localparam IDLE                   = 4'h0;
localparam READ                   = 4'h1;
localparam READ_OE_DELAY          = 4'h2;
localparam FINISHED               = 4'h3;

//Registers/Wires
reg         [3:0]   state;
reg         [3:0]   next_state;

reg         [23:0]  r_read_count;
reg         [1:0]   r_pre_re_count;
reg         [1:0]   r_post_re_count;

//Asynchronous logic registers

//Interface to in controller
wire                w_controller_read_request;
wire                o_data_valid;

//Sub Modules
//Asynchronous Logic
assign  o_read_enable       = (state == READ);
assign  o_output_enable     = ((state == READ) |
                               (state == READ_OE_DELAY));
assign  o_data_valid        = (r_pre_re_count == 0) &&
                              (r_post_re_count > 0);
//This will go when a transaction is finished and low when the user de-asserts
//the i_read_enable signal
assign  o_read_fx3_finished = (state == FINISHED);
assign  o_in_path_busy      = ((state != IDLE) && (state != FINISHED));
assign  o_in_path_finished  = (state == FINISHED);

//State Machine
always @ (*) begin
  next_state  = state;
  case (state)
    IDLE: begin
      if (i_in_path_enable && i_read_flow_cntrl) begin
        next_state  = READ;
      end
      else begin
        next_state  = IDLE;
      end
    end
    READ: begin
      if (r_read_count >= i_packet_size - 1) begin
        next_state  = READ_OE_DELAY;
      end
      else begin
        next_state  = READ;
      end
    end
    READ_OE_DELAY: begin
      if (r_post_re_count == 0) begin
        next_state  = FINISHED;
      end
      else begin
        next_state  = READ_OE_DELAY;
      end
    end
    FINISHED: begin
      //if (!i_read_fx3_packet && !i_in_path_enable) begin
      if (!i_in_path_enable) begin
        next_state  = IDLE;
      end
      else begin
        next_state  = FINISHED;
      end
    end
  endcase
end


//Synchronous Logic

//Input Synchronizer
//  Synchronize:
//    data
//    dma flags
//    control signal

//Synchronous Counter

//Data Valid Delay count (Account for the latency from the FX3 before read
//starts
always @ (posedge clk) begin
  if (rst) begin
    r_pre_re_count      <=  `RD_ENABLE_DELAY;
  end
  else begin
    case (state)
      IDLE: begin
        r_pre_re_count    <=  `RD_ENABLE_DELAY;
      end
      READ: begin
        if (r_pre_re_count > 2'h0) begin
          r_pre_re_count  <=  r_pre_re_count - 1'b1;
        end
      end
      default: begin
        r_pre_re_count    <=  r_pre_re_count;
      end
    endcase
  end
end

//Data Valid Delay count (Account for the latency from the FX3 after the read
//is finished
always @ (posedge clk) begin
  if (rst) begin
    r_post_re_count         <=  `RD_ENABLE_DELAY;
  end
  else begin
    case (state)
      READ: begin
        r_post_re_count     <=  `RD_ENABLE_DELAY;
      end
      READ_OE_DELAY: begin
        if (r_post_re_count > 2'h0) begin
          r_post_re_count   <=  r_post_re_count - 1'b1;
        end
        else begin
          r_post_re_count   <=  r_post_re_count;
        end
      end
      default: begin
        r_post_re_count     <=  r_post_re_count;
      end
    endcase
  end
end

//Count the number of reads that user requested
always @ (posedge clk) begin
  if (rst) begin
    r_read_count                  <=  0;
  end
  else begin
    if ((state == READ) | (state == READ_OE_DELAY)) begin
      if (r_read_count < i_packet_size) begin
        r_read_count              <=  r_read_count + 1;
      end
    end
    else begin
      r_read_count                <=  0;
    end
  end
end


always @ (posedge clk) begin
  if (rst) begin
    state <=  IDLE;
  end
  else begin
    state <=  next_state;
  end
end

endmodule
