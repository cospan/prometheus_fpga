`timescale 1ns / 1ps

`define MAX 32'h0A000000

module top(

input               main_clk,
input               rst_n,
output       [3:0]  o_led_n,
input        [3:0]  i_button,
input        [1:0]  i_switch,

//GPIF Signals
inout        [31:0] io_gpif_data,
output              o_gpif_clk,
output              o_gpif_oe_n,
output              o_gpif_re_n,
output              o_gpif_we_n,
output              o_gpif_pkt_end_n,

input               i_gpif_in_ch0_rdy,
input               i_gpif_in_ch1_rdy,

input               i_gpif_out_ch0_rdy,
input               i_gpif_out_ch1_rdy,

output      [1:0]   o_gpif_socket_addr

);

//Local Parameters

//Registers/Wires

wire                rst;
wire                clk;
reg     [3:0]       led;
reg     [31:0]      count;

//Although this is statically declared, in the future this should be be
//dynamically found by measuring the ready signal of a read or write
wire    [31:0]      w_packet_size;

//Master Interface
wire                w_master_ready;

wire        [7:0]   w_command;
wire        [7:0]   w_flag;
wire        [31:0]  w_rw_count;
wire        [31:0]  w_address;
wire                w_command_rdy_stb;

wire        [7:0]   w_status;
wire        [31:0]  w_read_size;
wire                w_status_rdy_stb;
wire        [31:0]  w_status_address;

//Write side FIFO interface
wire                w_wpath_ready;
wire                w_wpath_activate;
wire        [23:0]  w_wpath_packet_size;
wire        [31:0]  w_wpath_data;
wire                w_wpath_strobe;


//Read side FIFO interface
wire        [1:0]   w_rpath_ready;
wire        [1:0]   w_rpath_activate;
wire        [23:0]  w_rpath_size;
wire        [31:0]  w_rpath_data;
wire                w_rpath_strobe;



//Master Interface Signals
fx3_bus bus (
  .clk                    (clk                    ),
  .rst                    (rst                    ),

  .io_data                (io_gpif_data           ),

  .o_oe_n                 (o_gpif_oe_n            ),
  .o_we_n                 (o_gpif_we_n            ),
  .o_re_n                 (o_gpif_re_n            ),
  .o_pkt_end_n            (o_gpif_pkt_end_n       ),

  .i_in_ch0_rdy           (i_gpif_in_ch0_rdy      ),
  .i_in_ch1_rdy           (i_gpif_in_ch1_rdy      ),

  .i_out_ch0_rdy          (i_gpif_out_ch0_rdy     ),
  .i_out_ch1_rdy          (i_gpif_out_ch1_rdy     ),

  .o_socket_addr          (o_gpif_socket_addr     ),

  .i_master_ready         (w_master_ready         ),

  .o_command              (w_command              ),
  .o_flag                 (w_flag                 ),
  .o_rw_count             (w_rw_count             ),
  .o_address              (w_address              ),
  .o_command_rdy_stb      (w_command_rdy_stb      ),

  .i_status               (w_status               ),
  .i_read_size            (w_read_size            ),
  .i_status_rdy_stb       (w_status_rdy_stb       ),
  .i_address              (w_status_address       ),

  .o_wpath_ready          (w_wpath_ready          ),
  .i_wpath_activate       (w_wpath_activate       ),
  .o_wpath_packet_size    (w_wpath_packet_size    ),
  .o_wpath_data           (w_wpath_data           ),
  .i_wpath_strobe         (w_wpath_strobe         ),

  .o_rpath_ready          (w_rpath_ready          ),
  .i_rpath_activate       (w_rpath_activate       ),
  .o_rpath_size           (w_rpath_size           ),
  .i_rpath_data           (w_rpath_data           ),
  .i_rpath_strobe         (w_rpath_strobe         )

);

master m (
  .clk                    (clk                    ),
  .rst                    (rst                    ),

  .o_master_ready         (w_master_ready         ),

  .i_command              (w_command              ),
  .i_flag                 (w_flag                 ),
  .i_rw_count             (w_rw_count             ),
  .i_address              (w_address              ),
  .i_command_rdy_stb      (w_command_rdy_stb      ),

  .o_status               (w_status               ),
  .o_read_size            (w_read_size            ),
  .o_status_rdy_stb       (w_status_rdy_stb       ),
  .o_address              (w_status_address       ),

  .i_wpath_ready          (w_wpath_ready          ),
  .o_wpath_activate       (w_wpath_activate       ),
  .i_wpath_packet_size    (w_wpath_packet_size    ),
  .i_wpath_data           (w_wpath_data           ),
  .o_wpath_strobe         (w_wpath_strobe         ),

  .i_rpath_ready          (w_rpath_ready          ),

  .o_rpath_activate       (w_rpath_activate       ),
  .i_rpath_size           (w_rpath_size           ),
  .o_rpath_data           (w_rpath_data           ),
  .o_rpath_strobe         (w_rpath_strobe         )
);



//Asynchronous Logic
assign  clk       =   main_clk;
assign  rst       =   rst_n;
assign  o_led_n   =   ~led;
assign  o_gpif_clk=   clk;

//A controller should be put in place (within the fx3_bus that will select the
//correct address, this also requires a change of the GPIF

//Guessing 512 per packet (USB 2.0)
assign  w_packet_size       = 128;
//Synchronous Logic
always @ (posedge main_clk) begin
  if (!rst) begin
    led[0]      <=  0;
    led[1]      <=  0;
    led[2]      <=  0;
    led[3]      <=  0;
    count       <=  0;
  end
  else begin
    if (count < `MAX) begin
      count     <= count + 1;
    end
    else begin
      count     <=  0;
      led[0]    <= ~led[0];
    end

    if (i_button[1]) begin
      led[0]    <=  1;
      led[1]    <=  1;
      led[2]    <=  1;
      led[3]    <=  1;
    end
  end
end
endmodule
