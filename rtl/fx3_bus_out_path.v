`timescale 1 ns / 1 ns

`define LATENCY_TIMEOUT 24'h1
`include "project_include.v"

module fx3_bus_out_path #(
parameter           ADDRESS_WIDTH = 8   //256 32-bit values to align with
                                        //largest packet size
)(
input               clk,
input               rst,

//Control
output  reg         o_out_path_ready,   //Status Strobe detected, lock in count
input               i_out_path_enable,  //A buffer is available to write to
output              o_out_path_busy,    //Outpath is busy writing data out
output  reg         o_out_path_finished,//Outpath is finished writing data out

input               i_dma_buf_ready,    //A buffer is ready to write to
output  reg         o_dma_buf_finished, //A buffer has been filled or finished

//Packet size
input       [23:0]  i_packet_size,

input               i_status_rdy_stb,
input       [31:0]  i_read_size,

//FX3 Interface
output  reg         o_write_enable,
output  reg         o_packet_end,
output      [31:0]  o_data,

//FIFO in path
output      [1:0]   o_rpath_ready,
input       [1:0]   i_rpath_activate,
output      [23:0]  o_rpath_size,
input       [31:0]  i_rpath_data,
input               i_rpath_strobe
);

//Local Parameters
localparam IDLE                   = 4'h0;
localparam WAIT_FOR_READY         = 4'h1;
localparam WRITE_TO_HOST          = 4'h2;
localparam LATENCY_HOLD           = 4'h3;

//Registers/Wires
reg         [3:0]   state;
reg         [23:0]  r_packet_count;
reg         [32:0]  r_data_out_size;
reg         [31:0]  r_data_out_count;

//Ping Pong FIFO
reg                 r_out_strobe;
wire                w_out_ready;
reg                 r_out_activate;
wire        [23:0]  w_out_size;
wire        [31:0]  w_out_data;

reg         [23:0]  r_ppfifo_count;
reg         [23:0]  r_latency_count;


//Submodules
ppfifo#(
  .DATA_WIDTH           (32                 ),
  .ADDRESS_WIDTH        (ADDRESS_WIDTH      )
)pp_out(
  .reset                (rst                ),

  //Write Side
  .write_clock          (clk                ),
  .write_ready          (o_rpath_ready      ),
  .write_activate       (i_rpath_activate   ),
  .write_fifo_size      (o_rpath_size       ),
  .write_strobe         (i_rpath_strobe     ),
  .write_data           (i_rpath_data       ),

  //Read Side
  .read_clock           (clk                ),
  .read_strobe          (r_out_strobe       ),
  .read_ready           (w_out_ready        ),
  .read_activate        (r_out_activate     ),
  .read_count           (w_out_size         ),
//  .read_data            (w_out_data         )
  .read_data            (o_data             )

);

//Asynchronous Logic
assign  o_out_path_busy     = ((state != IDLE) && !o_out_path_finished);

//Synchronous Logic
always @ (posedge clk) begin
  if (rst) begin
    state                 <=  IDLE;
    r_ppfifo_count        <=  0;
    r_out_strobe          <=  0;
    r_packet_count        <=  0;

    o_write_enable        <=  0;
    o_packet_end          <=  0;
    r_data_out_count      <=  0;
    r_data_out_size       <=  0;
    r_latency_count       <=  0;
    r_out_activate        <=  0;

    //Controller Interface
    o_out_path_ready      <=  0;
    o_out_path_finished   <=  0;
    o_dma_buf_finished    <=  0;

  end
  else begin
    //Strobes
    r_out_strobe          <=  0;
    o_write_enable        <=  0;
    o_packet_end          <=  0;


    //Controller Interface
    o_out_path_finished   <=  0;
    if (i_out_path_enable) begin
      o_out_path_ready    <=  0;
    end
    if (i_out_path_enable && !o_out_path_busy) begin
      o_out_path_finished <=  1;
    end


    //Ping Pong FIFO Interface
    if (w_out_ready && !r_out_activate) begin
      r_ppfifo_count      <=  0;
      r_out_activate      <=  1;
    end
    else if (r_out_activate && (r_ppfifo_count >= w_out_size)) begin
      //$display ("fx3_bus_out_path: Ping Pong FIFO Finished");
      r_ppfifo_count      <=  0;
      r_out_activate      <=  0;
    end

    //State Machine
    case (state)
      IDLE: begin
        r_packet_count        <=  0;
        r_data_out_size       <=  0;
        o_out_path_ready      <=  0;

        if (i_status_rdy_stb) begin
          o_out_path_ready    <=  1;

          r_data_out_size     <=  i_read_size + `STATUS_LENGTH;
          r_data_out_count    <=  0;
          //data to send
          //Account for 1 clock cycle delay upon write start
          state               <=  WAIT_FOR_READY;
        end
      end
      WAIT_FOR_READY: begin
        if (i_dma_buf_ready   && r_out_activate) begin
          //$display ("fx3_bus_out_path: Write to host");
          r_packet_count      <=  0;
          state               <=  WRITE_TO_HOST;
        end
      end
      WRITE_TO_HOST: begin
        if (r_data_out_count < r_data_out_size) begin
          if (r_packet_count < i_packet_size) begin
            if (r_out_activate && (r_ppfifo_count < w_out_size)) begin

              o_write_enable    <=  1;
              r_out_strobe      <=  1;

              r_data_out_count  <=  r_data_out_count + 1;
              r_packet_count    <=  r_packet_count + 1;
              r_ppfifo_count    <=  r_ppfifo_count  + 1;

              if ((r_packet_count != i_packet_size - 1) && 
                  (r_data_out_count == r_data_out_size - 1)) begin
                o_packet_end    <=  1;
              end
            end
          end
          else begin
            //$display ("fx3_bus_out_path: Packet Sent to FX3");
            r_latency_count     <=  0;
            state               <=  LATENCY_HOLD;
            o_dma_buf_finished  <=  1;
          end
        end
        else begin
          o_out_path_finished   <=  1;
          r_out_activate        <=  0;

          if (!i_out_path_enable) begin
            $display ("fx3_bus_out_path: Sent all data");
            state               <=  IDLE;
          end
        end
        //Don't write a packet larger than the packet size
        //If we reached packet size go to an IDLE state
        //Check if we have reached the end of this FIFO (NOTE: this shouldn't
          //happen, this should be aligned with the output size
      end
      LATENCY_HOLD: begin
        o_dma_buf_finished      <=  1;
        if (r_latency_count < `LATENCY_TIMEOUT) begin
          r_latency_count       <=  r_latency_count + 1;
        end
        else begin
          if (!i_dma_buf_ready) begin
            //Wait for the controller to deassert the dma ready signal to
            //continue
            state               <=  WAIT_FOR_READY;
            o_dma_buf_finished  <=  0;
          end
        end
      end
    endcase
  end
end



endmodule
