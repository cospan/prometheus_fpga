`include "project_include.v"

module fx3_bus_controller (

input               clk,
input               rst,

//Master Interface
output              o_host_interface_rdy,
input               i_master_rdy,

//Path Interface Signals
output  reg         o_in_path_enable,
input               i_in_path_busy,
input               i_in_path_finished,

//Command Controls
output  reg         o_in_path_cmd_enable,
input               i_in_path_cmd_busy,
input               i_in_path_cmd_finished,

//Master Interface Signals

//Out Path
input               i_out_path_ready,
output  reg         o_out_path_enable,
input               i_out_path_busy,
input               i_out_path_finished,

output  reg         o_out_dma_buf_ready,
input               i_out_dma_buf_finished,

//FX3 Interface
input               i_in_ch0_rdy,
input               i_in_ch1_rdy,

input               i_out_ch0_rdy,
input               i_out_ch1_rdy,

output  reg [1:0]   o_socket_addr
);

//Local Parameters
localparam          IDLE          = 0;
//Registers/Wires
reg         [3:0]   state;
reg         [3:0]   next_state;

//Address Select Registers/Wires
reg                 r_data_direction; //Selects data flow direction
                                      //  0: into the FPGA
                                      //  1: out of the FPGA
reg                 r_in_buf_sel_next;
reg                 r_in_buf_sel;     //Select which of the two incomming
                                      //buffers to use: CH0 or CH1
reg                 r_out_buf_sel_next;
reg                 r_out_buf_sel;    //Select which of the two outgoing
                                      //buffers to use: CH0 or CH1

//Internal Status
wire                w_in_data_avail;
wire                w_out_buf_avail;

wire                w_in_path_idle;
wire                w_in_cmd_path_idle;
wire                w_out_path_idle;

//Submodules
//Asynchronous Logic
assign  w_in_path_idle        = (!w_in_data_avail && !o_in_path_enable);
assign  w_in_cmd_path_idle    = !o_in_path_enable;
assign  w_out_path_idle       = !o_out_path_enable    &&
                                !o_out_path_busy      &&
                                !o_out_path_finished  &&
                                !o_out_path_ready;


assign  o_host_interface_rdy  = w_out_path_idle;
assign  w_in_data_avail       = (i_in_ch0_rdy || i_in_ch1_rdy);
assign  w_out_buf_avail       = (i_out_ch0_rdy || i_out_ch1_rdy);

//State Machine
always @ (*) begin
  if (rst) begin
    next_state        = IDLE;
  end
  else begin
    case (state)
      IDLE: begin
      end
    endcase
  end
end

//Synchronous Logic
//Synchronize the state machine
always @ (posedge clk) begin
  if (rst) begin
    state           <=  IDLE;
  end
  else begin
    state           <=  next_state;
  end
end

//Control input and output paths
always @ (posedge clk) begin
  if (rst) begin
    r_data_direction      <=  0;
    r_in_buf_sel_next     <=  0;
    r_in_buf_sel          <=  0;

    r_out_buf_sel_next    <=  0;
    r_out_buf_sel         <=  0;

    o_in_path_enable      <=  0;
    o_in_path_cmd_enable  <=  0;

    o_out_path_enable     <=  0;
    o_out_dma_buf_ready   <=  0;

    o_socket_addr         <=  0;

  end
  else begin

    //get the next input channel ready
    if (i_in_ch0_rdy && !i_in_ch1_rdy) begin
      r_in_buf_sel_next   <=  0;
    end
    else if (i_in_ch1_rdy && !i_in_ch0_rdy) begin
      r_in_buf_sel_next   <=  1;
    end

    //get the next output channel ready
    if (i_out_ch0_rdy && !i_out_ch1_rdy) begin
      r_out_buf_sel_next  <=  0;
    end
    else if (i_out_ch1_rdy && !i_out_ch0_rdy) begin
      r_out_buf_sel_next  <=  1;
    end

    //Enable Input Path
    if (!o_in_path_enable && w_in_data_avail && i_master_rdy) begin
      //the output path is not working on anything and the master is ready and
      //there is data to process, Let's do this!
      o_socket_addr       <=  {1'b0, r_in_buf_sel_next};
      r_in_buf_sel        <=  r_in_buf_sel_next;
      o_in_path_enable    <=  1;
    end
    else if (i_in_path_finished)begin
      o_in_path_enable    <=  0;
    end


    //In Command Path Controller
    if (i_master_rdy) begin
      o_in_path_cmd_enable  <=  1;
    end
    else if (w_in_path_idle && w_out_path_idle) begin
      o_in_path_cmd_enable  <=  0;
    end



    //Output Path Controller
    if (i_out_path_ready && w_in_path_idle) begin
      o_out_path_enable     <=  1;
      o_out_dma_buf_ready   <=  0;
    end
    else if (i_out_path_busy) begin
      if (w_out_buf_avail && !o_out_dma_buf_ready) begin
        o_socket_addr       <=  {1'b1, r_out_buf_sel_next};
        o_out_dma_buf_ready <=  1;
      end
      if (i_out_dma_buf_finished) begin
        o_out_dma_buf_ready <=  0;
      end

    end
    else if (i_out_path_finished) begin
      o_out_dma_buf_ready   <=  0;
      o_out_path_enable     <=  0;
    end

    /*
    if (i_status_rdy_stb) begin
      //we know a transaction between the FPGA and the user will happen
      r_out_read_count      <=  0;
      //we need to add on the size of the status length here because the
      //master will send the status both throuhg ports and through the PPFIFO
      r_out_read_size       <=  i_status_read_size + `STATUS_LENGTH;
    end
    if (r_out_read_count < r_out_read_size) begin
      //More data to write
      //if the input path is not active setup the next available FIFO
      if (!o_out_path_enable) begin
        o_socket_addr       <=  {1'b1, r_out_buf_sel_next};
        r_out_buf_sel       <=  r_out_buf_sel_next;
        o_out_path_enable   <=  1;
      end
      if (i_out_path_finished) begin
        //the output path is finished with a transaction
        o_out_path_enable   <=  0;
        r_out_read_count    <=  r_out_read_count + i_out_path_words_sent;
      end
    end
    */
  end
end


endmodule
