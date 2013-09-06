`include "project_include.v"

module master(
input               clk,
input               rst,

output              o_master_ready,

//Master Interface
input       [7:0]   i_command,
input       [7:0]   i_flag,
input       [31:0]  i_rw_count,
input       [31:0]  i_address,
input               i_command_rdy_stb,

output  reg [7:0]   o_status,
output      [7:0]   o_status_flags,
output  reg [31:0]  o_read_size,
output  reg         o_status_rdy_stb,
output  reg [31:0]  o_address,        //Calculated end address, this can be
                                      //used to verify that the mem was
                                      //calculated correctly
//Write side FIFO interface
input               i_wpath_ready,
output  reg         o_wpath_activate,
input       [23:0]  i_wpath_packet_size,
input       [31:0]  i_wpath_data,
output  reg         o_wpath_strobe,


//Read side FIFO interface
input       [1:0]   i_rpath_ready,
output  reg [1:0]   o_rpath_activate,
input       [23:0]  i_rpath_size,
output  reg [31:0]  o_rpath_data,
output  reg         o_rpath_strobe
);

//Local Parameters
localparam  IDLE            = 4'h0;
localparam  PING            = 4'h1;
localparam  WRITE           = 4'h2;
localparam  READ            = 4'h3;
localparam  CONFIG          = 4'h4;

//Registers/Wires
reg         [3:0]   state;
reg         [3:0]   next_state;

reg         [23:0]  r_wdata_count;
reg         [23:0]  r_rdata_count;
reg         [31:0]  r_write_count;
reg         [31:0]  r_read_count;

reg         [23:0]  r_status_index;
reg                 r_status_strobe;

reg                 r_process_command;

reg         [31:0]  r_status;
wire        [7:0]   w_status_flags;

wire                w_error;                //Indicate that some error occured
wire                w_error_bus_timeout;    //Timeout with axi bus
wire                w_error_comm_timeout;   //Timeout with communication

wire                w_interrupt;

reg                 r_send_status;
reg                 r_status_sent;
wire                w_status_send_finished;

reg         [23:0]  r_rpath_fifo_count;
wire                w_out_path_ready;



//Trigger Declaration
reg                 r_trig_send_status;
reg                 r_trig_send_finished;

//Submodules

//Asynchronous Logic
assign  o_master_ready      = (state == IDLE);
assign  w_out_path_ready    = ((o_rpath_activate > 0) && (r_rpath_fifo_count < i_rpath_size));
assign  w_status_send_finished  = (!r_send_status && !r_status_sent);

assign  w_error_bus_timeout = 0;
assign  w_error_comm_timeout= 0;

assign  w_error             = (w_error_bus_timeout  ||
                               w_error_comm_timeout);

assign  w_interrupt         = 0;

assign  o_status_flags      = 8'h0;

//Triggers

//Send Status Trigger
always @ (posedge clk) begin
  if (rst) begin
    r_trig_send_status          <= 0;
    r_trig_send_finished        <= 0;
  end
  else begin
    r_trig_send_status          <= 0;

    case (state)
      IDLE: begin
        r_trig_send_finished    <=  0;
      end
      PING: begin
        if (!r_trig_send_finished) begin
          r_trig_send_status    <=  1;
        end
        r_trig_send_finished    <=  1;
      end
      WRITE: begin
        if (r_write_count >= i_rw_count) begin
          if (!r_trig_send_finished) begin
            r_trig_send_status    <=  1;
          end
          r_trig_send_finished    <=  1;
        end
      end
      READ: begin
        if (!r_trig_send_finished) begin
          r_trig_send_status    <=  1;
        end
        r_trig_send_finished    <=  1;
      end
      CONFIG: begin
        if (!r_trig_send_finished) begin
          r_trig_send_status    <=  1;
        end
        r_trig_send_finished    <=  1;
      end
    endcase
  end
end

always @ (*) begin
  if (rst) begin
    r_status            = 0;
  end
  else begin
    if (w_error) begin
      //Error Occured :(
      r_status          = {`IDENTIFICATION_ERR,
                           o_status_flags,
                           ~i_command};
    end
    else if (w_interrupt) begin
      //Send OH HI!
      r_status          = {`IDENTIFICATION_INT,
                           o_status_flags,
                           `INTERRUPT_STATUS};
    end
    else begin
      //Normal Response

      //Check if there is an error condition here
      r_status          = {`IDENTIFICATION_RESP,
                           o_status_flags,
                           ~i_command};
    end
  end
end

//strobe (i_command_rdy_stb) to enable (r_process_command)
always @ (*) begin
  if (rst) begin
    r_process_command   = 0;
  end
  else begin
    if (i_command_rdy_stb && (state == IDLE)) begin
      r_process_command = 1;
    end
    else if (state != IDLE) begin
      r_process_command = 0;
    end
    else begin
      r_process_command = r_process_command;
    end
  end
end

//State Machine
always @ (*) begin
  if (rst) begin
    next_state  = IDLE;
  end
  else begin
    next_state  = state;
    case (state)
      IDLE: begin
        if (r_process_command) begin
          case (i_command)
            `PING_COMMAND: begin
              next_state    =  PING;
            end
            `WRITE_COMMAND: begin
              next_state    =  WRITE;
            end
            `READ_COMMAND: begin
              $display ("master: Detected Read Request");
              next_state    =  READ;
            end
            `CONFIG_COMMAND: begin
              next_state    =  CONFIG;
            end
          endcase
        end
        else begin
          next_state        =  IDLE;
        end
      end
      PING: begin
        //Just Send a response
        if (!r_trig_send_finished) begin
          next_state        = IDLE;
        end
        else begin
          next_state        = PING;
        end
      end
      WRITE: begin
        //Data comes in from the host and writes to the FPGA
        if (!r_trig_send_finished && (r_write_count >= i_rw_count)) begin
          next_state        = IDLE;
        end
        else begin
          next_state        = WRITE;
        end
      end
      READ: begin
        //Read Data from the i_address
        if (r_read_count >= o_read_size) begin
          next_state        = IDLE;
        end
        else begin
          next_state        = READ;
        end
      end
      CONFIG: begin
        //Write and read configuration data
      end
    endcase
  end
end

//Synchronous Logic

//Synchronize state
always @ (posedge clk) begin
  if (rst) begin
    state       <=  IDLE;
  end
  else begin
    state       <=  next_state;
  end
end

//Set up the out read size and the out address
always @ (posedge clk) begin
  if (rst) begin
    o_read_size       <=  0;
    o_address         <=  0;
  end
  else begin
    if (i_command_rdy_stb) begin
      case (i_command)
        `PING_COMMAND: begin
          o_read_size <=  0;
          o_address   <=  i_address;
        end
        `WRITE_COMMAND: begin
          o_read_size <=  0;
          o_address   <=  i_address;
        end
        `READ_COMMAND: begin
          o_read_size <=  i_rw_count;
          o_address   <=  i_address;
        end
        `CONFIG_COMMAND: begin
          o_read_size <=  `CONFIG_LENGTH;
          o_address   <=  i_address;
        end
      endcase
    end
  end
end

//Input Path (All incomming data goes through here)
always @ (posedge clk) begin
  if (rst) begin
    o_wpath_activate        <=  0;
    o_wpath_strobe          <=  0;
    r_wdata_count           <=  0;  //Count for packet

    r_write_count           <=  0;  //Count for the total data (independent of packet size)
  end
  else begin
    o_wpath_strobe          <=  0;
    //Write Path (Incomming)
    if (i_wpath_ready && !o_wpath_activate) begin
      r_wdata_count         <=  0;
      o_wpath_activate      <=  1;
    end
    else if (o_wpath_activate) begin
      if (r_wdata_count >= i_wpath_packet_size) begin
        o_wpath_activate    <=  0;
      end
    end

    if (o_wpath_strobe) begin
      r_write_count         <=  r_write_count + 1;
    end

    if (state == WRITE) begin
      if ((o_wpath_activate > 0) && (r_wdata_count < i_wpath_packet_size)) begin
        o_wpath_strobe      <=  1;
        r_wdata_count     <=  r_wdata_count + 1;
      end

      //for now just suck all the data out of the incomming ping pong FIFO
      //whenever it's available. In the future this will interface with the
      //Axi Out Path
    end
    else if (state == IDLE) begin
      r_write_count         <=  0;
    end
  end
end

//Output Path (All outgoing data goes through here)
always @ (posedge clk) begin
  if (rst) begin

    o_status                    <=  0;
    o_status_rdy_stb            <=  0;

    r_status_index              <=  0;
    r_status_strobe             <=  0;
    r_send_status               <=  0;
    r_status_sent               <=  0;

    o_rpath_activate            <=  0;
    o_rpath_data                <=  0;
    o_rpath_strobe              <=  0;

    r_rpath_fifo_count          <=  0;

  end
  else begin
    //Strobe
    o_rpath_strobe              <=  0;
    o_status_rdy_stb            <=  0;
    r_status_strobe             <=  0;

    //Ping Pong FIFO Read Path (Outgoing)
    if ((i_rpath_ready > 0) && (o_rpath_activate == 0)) begin
      r_rpath_fifo_count        <=  0;
      if (i_rpath_ready[0]) begin
        o_rpath_activate[0]     <=  1;
      end
      else begin
        o_rpath_activate[1]     <=  1;
      end
    end
//    else if (o_rpath_activate > 0)begin
//      if (r_rpath_fifo_count < i_rpath_size) begin
//        if (o_rpath_strobe) begin
//          r_rpath_fifo_count    <=  r_rpath_fifo_count + 1;
//        end
//      end
//      else begin
//        o_rpath_activate        <=  0;
//      end
//    end

    //Take care of the send status trigger setup so we don't send multiple
    //status packets
    if (r_trig_send_status) begin
      r_send_status             <=  1;
    end
    else if (r_status_sent) begin
      r_send_status             <=  0;
      r_status_sent             <=  0;
    end

    //Conditions to disable the current Ping Pong FIFO
    if ((state == IDLE) && (r_rpath_fifo_count > 0) && !o_rpath_strobe) begin
      //Condition to flush the FIFO
      o_rpath_activate        <=  0;
    end

    //Condition to reset the read count
    if (state == IDLE) begin
      r_read_count            <=  0;
      r_status_index          <=  0;
    end

    //Send Status
    if (o_rpath_activate && r_send_status) begin
      case (r_status_index)
        `STATUS_DATA_0: begin
          o_status                <=  r_status;
          o_rpath_data            <=  r_status;

          r_status_index          <=  r_status_index + 1;
          o_rpath_strobe          <=  1;
          r_rpath_fifo_count      <=  r_rpath_fifo_count + 1;
        end
        `STATUS_DATA_1: begin
          o_rpath_data            <=  o_read_size;
          r_status_index          <=  r_status_index + 1;
          o_rpath_strobe          <=  1;
          r_rpath_fifo_count      <=  r_rpath_fifo_count + 1;
        end
        `STATUS_DATA_2: begin
          o_rpath_data            <=  o_address;
          o_status_rdy_stb        <=  1;
          o_rpath_strobe          <=  1;

          r_status_index          <=  r_status_index + 1;
          r_rpath_fifo_count      <=  r_rpath_fifo_count + 1;

          if (i_command != `READ_COMMAND) begin
            r_status_sent         <=  1;
          end
        end
        default: begin
          if (r_read_count < o_read_size ) begin
            if (o_rpath_activate > 0) begin
              if (r_rpath_fifo_count < i_rpath_size) begin
                o_rpath_strobe    <=  1;
                o_rpath_data      <=  r_read_count;
                r_read_count      <=  r_read_count + 1;
                r_rpath_fifo_count<=  r_rpath_fifo_count + 1;
              end
              else begin
                o_rpath_activate  <=  0;
              end
            end
          end
          else begin
            r_status_sent     <=  1;
          end
        end
      endcase
    end
  end
end

endmodule
