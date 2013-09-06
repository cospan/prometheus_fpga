
`include "project_include.v"


module fx3_bus_in_control #(
parameter           ADDRESS_WIDTH = 8   //256 coincides with the maximum DMA
                                        //size for USB 3.0
)(
input               clk,
input               rst,

input               i_master_ready,
output              o_read_fx3_packet,
output              o_read_flow_cntrl,
input               i_read_fx3_finished,

//Data
input       [31:0]  i_data,
//Data Valid Flag
input               i_data_valid,

//Master Interface
output  reg [7:0]   o_command,
output  reg [7:0]   o_flag,
output  reg [31:0]  o_rw_count,
output  reg [31:0]  o_address,
output  reg         o_command_rdy_stb,

//Write side FIFO interface
output              o_in_ready,
input               i_in_activate,
output      [23:0]  o_in_packet_size,
output      [31:0]  o_in_data,
input               i_in_strobe

);

//Local Parameters
localparam  IDLE            = 4'h0;
localparam  READ_COMMAND    = 4'h1;
localparam  READ_COUNT      = 4'h2;
localparam  READ_ADDRESS    = 4'h3;
localparam  READ_CHECKSUM   = 4'h4;
localparam  READ_DATA       = 4'h5;
localparam  READ_DATA_WAIT  = 4'h6;
localparam  FINISHED        = 4'h7;

//Registers/Wires
reg         [3:0]   state;

reg         [15:0]  r_id_word;
wire                w_read_in_data;
reg         [31:0]  r_checksum;
reg         [31:0]  r_cmd_checksum;
wire                w_finished;

reg         [31:0]  r_read_data_count;

//PPFIFO
wire        [1:0]   w_write_ready;
reg         [1:0]   r_write_activate;
wire        [23:0]  w_write_fifo_size;
reg                 r_write_strobe;
reg         [31:0]  r_write_data;

reg         [23:0]  r_write_count;



//Submodules
ppfifo#(
  .DATA_WIDTH           (32                 ),
  .ADDRESS_WIDTH        (ADDRESS_WIDTH      )

)pp_in(
  .reset                (rst                ),

  //Write Side
  .write_clock          (clk                ),
  .write_ready          (w_write_ready      ),
  .write_activate       (r_write_activate   ),
  .write_fifo_size      (w_write_fifo_size  ),
  .write_strobe         (r_write_strobe     ),
  .write_data           (r_write_data       ),

  //Read Side
  .read_clock           (clk                ),
  .read_strobe          (i_in_strobe        ),
  .read_ready           (o_in_ready         ),
  .read_activate        (i_in_activate      ),
  .read_count           (o_in_packet_size   ),
  .read_data            (o_in_data          )

);
//Asynchronous Logic
assign  o_read_flow_cntrl         = (r_write_activate > 0);

assign  o_read_fx3_packet         = ((state != IDLE) && 
                                     !i_read_fx3_finished);

assign  w_finished                = (((r_read_data_count == o_rw_count) || 
                                      (w_write_ready == 2'b11)) &&
                                     i_read_fx3_finished);

//Synchronous Logic
always @ (posedge clk) begin
  if (rst) begin
    state             <=  IDLE;

    r_id_word         <=  0;
    o_flag            <=  0;
    o_command         <=  0;

    o_rw_count        <=  0;
    o_address         <=  0;
    r_checksum        <=  0;
    r_cmd_checksum    <=  0;
    o_command_rdy_stb <=  0;

    r_write_activate  <=  0;
    r_write_strobe    <=  0;
    r_write_data      <=  0;
    r_write_count     <=  0;

    r_read_data_count <=  0;
  end
  else begin
    //Strobes
    o_command_rdy_stb <=  0;
    r_write_strobe    <=  0;

    //Grab a ppfifo if available
    if ((w_write_ready > 0) && (r_write_activate == 0)) begin
      r_write_count   <=  0;
      if (w_write_ready[0]) begin
        r_write_activate[0] <=  1;
      end
      else begin
        r_write_activate[1] <=  1;
      end
    end
    else begin
      //a FIFO is activated
      if (r_write_count < w_write_fifo_size) begin
        if (r_write_strobe) begin
          r_write_count     <= r_write_count + 1;
        end
      end
      else begin
        //Release the current FIFO it's full
        r_write_activate    <=  0;
      end
    end

    case (state)
      IDLE: begin
        r_read_data_count   <=  0;
        if (i_master_ready) begin
          state             <=  READ_COMMAND;
        end
      end
      READ_COMMAND: begin
        if (i_data_valid) begin
          r_id_word         <=  i_data[31:16];
          o_flag            <=  i_data[15:8];
          o_command         <=  i_data[7:0];
          state             <=  READ_COUNT;
        end
      end
      READ_COUNT: begin
        if (i_data_valid) begin
          o_rw_count        <=  i_data;
          state             <=  READ_ADDRESS;
        end
      end
      READ_ADDRESS: begin
        if (i_data_valid) begin
          o_address         <=  i_data;
          state             <=  READ_CHECKSUM;
        end
      end
      READ_CHECKSUM: begin
        if (i_data_valid) begin
          r_checksum        <=  i_data;
          o_command_rdy_stb <=  1;

          if (o_command == `WRITE_COMMAND) begin
            r_write_count   <=  `COMMAND_LENGTH;
            state           <=  READ_DATA;
            $display("Reading data from the host");
          end
          else begin
            //Don't need to put anything in the PPFIFO
            state           <=  FINISHED;
          end
        end
      end
      READ_DATA: begin
        if (r_read_data_count < o_rw_count) begin
          if (i_data_valid) begin
            r_write_strobe  <=  1;
            r_write_data    <=  i_data; 
            r_read_data_count <=  r_read_data_count + 1;
          end
        end
        else begin
          if (r_write_activate > 0) begin
            r_write_activate  <=  0;
          end
          state             <=  FINISHED;
        end
      end
      READ_DATA_WAIT: begin
        if (i_read_fx3_finished) begin
          if (w_read_in_data) begin
            state           <=  READ_DATA;
          end
          else begin
            state           <=  IDLE;
          end
        end
      end
      FINISHED: begin
        if (!i_master_ready && w_finished) begin
          state             <=  IDLE;
        end
      end
    endcase
  end
end

endmodule
