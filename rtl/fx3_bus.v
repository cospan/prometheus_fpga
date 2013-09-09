/*
 * The nice thing about defines that are not possible with parameters is that
 * you can pull defines to an external file and have all the defines in one
 * place. This can be accomplished with parameters and UCF files but that
 * would be vendor specific
 */

`define FX3_READ_START_LATENCY    1
`define FX3_WRITE_FULL_LATENCY    4

`include "project_include.v"



module fx3_bus # (
parameter           ADDRESS_WIDTH = 8   //128 coincides with the maximum DMA
                                        //packet size for USB 2.0
                                        //256 coincides with the maximum DMA
                                        //packet size for USB 3.0 since the 512
                                        //will work for both then the FIFOs will
                                        //be sized for this

)(
input               clk,
input               rst,

//Phy Interface
inout       [31:0]  io_data,

output              o_oe_n,
output              o_we_n,
output              o_re_n,
output              o_pkt_end_n,

input               i_in_ch0_rdy,
input               i_in_ch1_rdy,

input               i_out_ch0_rdy,
input               i_out_ch1_rdy,

output      [1:0]   o_socket_addr,


//Master Interface
input               i_master_ready,

output      [7:0]   o_command,
output      [7:0]   o_flag,
output      [31:0]  o_rw_count,
output      [31:0]  o_address,
output              o_command_rdy_stb,

input       [7:0]   i_status,
input       [31:0]  i_read_size,
input               i_status_rdy_stb,
input       [31:0]  i_address,        //Calculated end address, this can be
                                      //used to verify that the mem was
                                      //calculated correctly

//Write side FIFO interface
output              o_wpath_ready,
input               i_wpath_activate,
output      [23:0]  o_wpath_packet_size,
output      [31:0]  o_wpath_data,
input               i_wpath_strobe,


//Read side FIFO interface
output      [1:0]   o_rpath_ready,
input       [1:0]   i_rpath_activate,
output      [23:0]  o_rpath_size,
input       [31:0]  i_rpath_data,
input               i_rpath_strobe
);

//Local Parameters
//Registers/Wires
wire                w_output_enable;
wire                w_read_enable;
wire                w_write_enable;
wire                w_packet_end;

wire        [31:0]  w_in_data;
wire        [31:0]  w_out_data;
wire                w_data_valid;

wire        [23:0]  w_packet_size;
wire                w_read_flow_cntrl;

//In Path Control
wire                w_in_path_enable;
wire                w_in_path_busy;
wire                w_in_path_finished;

//In Command Path
wire                w_in_path_cmd_enable;
wire                w_in_path_cmd_busy;
wire                w_in_path_cmd_finished;

//Out Path Control
wire                w_out_path_ready;
wire                w_out_path_enable;
wire                w_out_path_busy;
wire                w_out_path_finished;

//Submodules

//Data From FX3 to FPGA
fx3_bus_in_path in_path(
  .clk                    (clk                    ),
  .rst                    (rst                    ),

  //Control Signals
  .i_packet_size          (w_packet_size          ),
  .i_read_flow_cntrl      (w_read_flow_cntrl      ),

  //FX3 Interface
  .o_output_enable        (w_output_enable        ),
  .o_read_enable          (w_read_enable          ),

  //When high w_in_data is valid
  .o_data_valid           (w_data_valid           ),
  .i_in_path_enable       (w_in_path_enable       ),
  .o_in_path_busy         (w_in_path_busy         ),
  .o_in_path_finished     (w_in_path_finished     )
);

//Data from in_path to command reader
fx3_bus_in_command in_cmd(
  .clk                    (clk                    ),
  .rst                    (rst                    ),

  .o_read_flow_cntrl      (w_read_flow_cntrl      ),

  //Control
  .i_in_path_cmd_enable   (w_in_path_cmd_enable   ),
  .o_in_path_cmd_busy     (w_in_path_cmd_busy     ),
  .o_in_path_cmd_finished (w_in_path_cmd_finished ),

  //Data
  .i_data                 (w_in_data              ),
  //Data Valid Flag
  .i_data_valid           (w_data_valid           ),

  //Master Interface
  .o_command              (o_command              ),
  .o_flag                 (o_flag                 ),
  .o_rw_count             (o_rw_count             ),
  .o_address              (o_address              ),
  .o_command_rdy_stb      (o_command_rdy_stb      ),

  //Write side FIFO interface
  .o_in_ready             (o_wpath_ready          ),
  .i_in_activate          (i_wpath_activate       ),
  .o_in_packet_size       (o_wpath_packet_size    ),
  .o_in_data              (o_wpath_data           ),
  .i_in_strobe            (i_wpath_strobe         )
);


//Data from Master to The host
fx3_bus_out_path out_path(
  .clk                    (clk                    ),
  .rst                    (rst                    ),

  //Control
  .o_out_path_ready       (w_out_path_ready       ),
  .i_out_path_enable      (w_out_path_enable      ),
  .o_out_path_busy        (w_out_path_busy        ),
  .o_out_path_finished    (w_out_path_finished    ),

  .i_dma_buf_ready        (w_out_dma_buf_ready    ),
  .o_dma_buf_finished     (w_out_dma_buf_finished ),

  //Packet size
  .i_packet_size          (w_packet_size          ),
  .i_status_rdy_stb       (i_status_rdy_stb       ),
  .i_read_size            (i_read_size            ),

  //FX3 Interface
  .o_write_enable         (w_write_enable         ),
  .o_packet_end           (w_packet_end           ),
  .o_data                 (w_out_data             ),

  //FIFO in path
  .o_rpath_ready          (o_rpath_ready          ),
  .i_rpath_activate       (i_rpath_activate       ),
  .o_rpath_size           (o_rpath_size           ),
  .i_rpath_data           (i_rpath_data           ),
  .i_rpath_strobe         (i_rpath_strobe         )
);

fx3_bus_controller controller(
  .clk                    (clk                    ),
  .rst                    (rst                    ),

  //FX3 Parallel Interface
  .i_in_ch0_rdy           (i_in_ch0_rdy           ),
  .i_in_ch1_rdy           (i_in_ch1_rdy           ),

  .i_out_ch0_rdy          (i_out_ch0_rdy          ),
  .i_out_ch1_rdy          (i_out_ch1_rdy          ),

  .o_socket_addr          (o_socket_addr          ),

  //Incomming Data
  .i_master_rdy           (i_master_ready         ),

  //Outgoing Flags/Feedback
  .o_in_path_enable       (w_in_path_enable       ),
  .i_in_path_busy         (w_in_path_busy         ),
  .i_in_path_finished     (w_in_path_finished     ),

  //Command Path
  .o_in_path_cmd_enable   (w_in_path_cmd_enable   ),
  .i_in_path_cmd_busy     (w_in_path_cmd_busy     ),
  .i_in_path_cmd_finished (w_in_path_cmd_finished ),

  //Master Interface

  //Output Path
  .i_out_path_ready       (w_out_path_ready       ),
  .o_out_path_enable      (w_out_path_enable      ),
  .i_out_path_busy        (w_out_path_busy        ),
  .i_out_path_finished    (w_out_path_finished    ),

  .o_out_dma_buf_ready    (w_out_dma_buf_ready    ),
  .i_out_dma_buf_finished (w_out_dma_buf_finished )

);



//Asynchronous Logic
assign  o_oe_n        = !w_output_enable;
assign  o_re_n        = !w_read_enable;
assign  o_we_n        = !w_write_enable;
assign  o_pkt_end_n   = !w_packet_end;

assign  io_data       = (w_output_enable) ? 32'hZZZZZZZZ : w_out_data;
assign  w_in_data     = (w_data_valid) ? io_data : 32'h00000000;

//XXX: NOTE THIS SHOULD BE ADJUSTABLE FROM THE SPEED DETECT MODULE
assign  w_packet_size = 24'h80;
//Synchronous Logic

endmodule
