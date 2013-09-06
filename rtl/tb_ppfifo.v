//ppfifo testbench
/*
Distributed under the MIT licesnse.
Copyright (c) 2011 Dave McCoy (dave.mccoy@cospandesign.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/


`define DATA_SIZE 16
`define ADDRESS_SIZE 5


//16 ns for write period
`define WRITE_PERIOD 10
//20 ns for read period
`define READ_PERIOD 2

module tb_ppfifo (
);

//test signals
reg			                  rst = 0;
reg   [`DATA_SIZE - 1: 0] output_data;
reg   [23:0]              output_count  = 0;
reg                       data_valid  = 0;
reg   [23:0]              input_count = 0;
integer                   count;


//write side
reg                       write_clock = 0;
always #(`WRITE_PERIOD/2) write_clock = ~write_clock;

wire  [1:0]               write_ready;
reg   [1:0]               write_activate;
wire  [23:0]              write_fifo_size;
reg                       write_strobe;
reg   [`DATA_SIZE - 1: 0] write_data;
wire                      starved;

//read side
reg                       read_clock = 0;
always #(`READ_PERIOD/2)  read_clock = ~read_clock;
reg                       read_strobe;
reg                       read_activate;
wire                      read_ready;
wire  [23:0]              read_count;
wire  [`DATA_SIZE - 1: 0] read_data;


ppfifo #(
  .DATA_WIDTH(`DATA_SIZE),
  .ADDRESS_WIDTH(`ADDRESS_SIZE)
)
pp (
  .reset (rst),

  .write_clock(write_clock),
  .write_ready(write_ready),
  .write_activate(write_activate),
  .write_fifo_size(write_fifo_size),
  .write_strobe(write_strobe),
  .write_data(write_data),
  .starved(starved),

  .read_clock(read_clock),
  .read_strobe(read_strobe),
  .read_ready(read_ready),
  .read_activate(read_activate),
  .read_count(read_count),
  .read_data(read_data)
);

initial begin
//	fd_out			=	0;


	$dumpfile ("design.vcd");
	$dumpvars (0, tb_ppfifo);

	rst				      <= 0;
  count           <=  0;
	#(`WRITE_PERIOD * `READ_PERIOD)
	rst				      <=  1;
  write_strobe    <=  1'h0;
  write_activate  <=  0;
  write_data      <=  0;

  read_strobe     <=  0;


	#(2 * (`WRITE_PERIOD * `READ_PERIOD))
	rst				      <= 0;

	#(2 * (`WRITE_PERIOD * `READ_PERIOD))

  #(`WRITE_PERIOD / 2);

  write_activate[0] <=  1;
  #(`WRITE_PERIOD);
  write_data        <=  16'h0123;
  write_strobe      <=  1;
  #(`WRITE_PERIOD);
  write_data        <=  16'h4567;
  write_strobe      <=  1;
  #(`WRITE_PERIOD);
  write_data        <=  16'h89ab;
  write_strobe      <=  1;
  #(`WRITE_PERIOD);
  write_data        <=  16'hcdef;
  write_strobe      <=  1;
  #(`WRITE_PERIOD);
  write_data        <=  16'haaaa;
  write_strobe      <=  1;

  #(`WRITE_PERIOD);
  write_strobe      <=  0;
  #(`WRITE_PERIOD);
  write_activate[0] <=  0;

  #(4 * `WRITE_PERIOD);
  //see if the other FIFO is free

//TEST WRITING OF THE ENTIRE FIFO
  if (write_ready[0]) begin
    $display("FIFO 0 is ready");
    //activate this FIFO
    write_activate[0] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    write_data        <= 16'hBBBB;
    write_strobe      <=  1;
    #(`WRITE_PERIOD);
    write_strobe        <=  0;
    write_activate[0]   <=  0;
  end
  else if (write_ready[1])begin
    $display("FIFO 1 is ready");
    //activate this FIFO
    write_activate[1] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    write_data        <= 16'hCCCC;
    write_strobe      <=  1;
    #(`WRITE_PERIOD);
    write_strobe        <=  0;
    write_activate[1]   <=  0;
  end


  #(4 * `WRITE_PERIOD);
  //see if the other FIFO is free

//TEST WRITING OF THE ENTIRE FIFO
  if (write_ready[0]) begin
    $display("FIFO 0 is ready");
    //activate this FIFO
    write_activate[0] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    for (count = 0; count < write_fifo_size; count = count + 1) begin
      $display ("Writing %h into the FIFO", count);
      write_data        <= count;
      write_strobe      <=  1;
      #(`WRITE_PERIOD);
    end
    write_strobe        <=  0;
    write_activate[0]   <=  0;
  end
  else if (write_ready[1])begin
    $display("FIFO 1 is ready");
    //activate this FIFO
    write_activate[1] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    for (count = 0; count < write_fifo_size; count = count + 1) begin
      $display ("Writing %h into the FIFO", count);
      write_data        <= count;
      write_strobe      <=  1;
      #(`WRITE_PERIOD);
    end
    write_strobe        <=  0;
    write_activate[1]   <=  0;
  end


  #(4 * `WRITE_PERIOD);
  //see if the other FIFO is free

//TEST WRITING OF THE ENTIRE FIFO
  if (write_ready[0]) begin
    $display("FIFO 0 is ready");
    //activate this FIFO
    write_activate[0] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    for (count = 0; count < write_fifo_size; count = count + 1) begin
      $display ("Writing %h into the FIFO", count);
      write_data        <= count;
      write_strobe      <=  1;
      #(`WRITE_PERIOD);
    end
    write_strobe        <=  0;
    write_activate[0]   <=  0;
  end
  else if (write_ready[1])begin
    $display("FIFO 1 is ready");
    //activate this FIFO
    write_activate[1] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    for (count = 0; count < write_fifo_size; count = count + 1) begin
      $display ("Writing %h into the FIFO", count);
      write_data        <= count;
      write_strobe      <=  1;
      #(`WRITE_PERIOD);
    end
    write_strobe        <=  0;
    write_activate[1]   <=  0;
  end

  //test whether I can start writing stop writing and then start writing again to the same
  //buffer
  #(4 * `WRITE_PERIOD);

  if (write_ready[0]) begin
    $display("FIFO 0 is ready");
    //activate this FIFO
    write_activate[0] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    for (count = 0; count < write_fifo_size; count = count + 1) begin
      $display ("Writing %h into the FIFO", count);
      write_data        <= count;
      write_strobe      <=  1;
      #(`WRITE_PERIOD);
      write_strobe      <=  0;
      #(`WRITE_PERIOD);
    end
    write_strobe        <=  0;
    write_activate[0]   <=  0;
  end
  else if (write_ready[1])begin
    $display("FIFO 1 is ready");
    //activate this FIFO
    write_activate[1] <=  1;
    #(`WRITE_PERIOD);
    //Fill up the FIFO
    for (count = 0; count < write_fifo_size; count = count + 1) begin
      $display ("Writing %h into the FIFO", count);
      write_data        <= count;
      write_strobe      <=  1;
      #(`WRITE_PERIOD);
      write_strobe      <=  0;
      #(`WRITE_PERIOD);

    end
    write_strobe        <=  0;
    write_activate[1]   <=  0;
  end

  #(4 * `WRITE_PERIOD);

//attempt to write twice as much data as is availble in one FIFO
  count = 0;

  while (count < (write_fifo_size << 1)) begin
    if (write_activate == 0) begin
      //we are not currently working on a buffer
      if (write_ready[0] == 1) begin
        //we can activate FIFO 0
        write_activate[0] <=  1;
      end
      else if (write_ready[1] == 1) begin
        write_activate[1] <=  1;
      end
      input_count       <=  write_fifo_size;
      #(`WRITE_PERIOD);
    end
    else begin
      //currently we are writing to  FIFO
      if (input_count > 0) begin
        write_data        <=  write_fifo_size - input_count;
        write_strobe      <=  1;
        count             <=  count + 1;
        input_count       <=  input_count - 1;
      end
      else begin
        //deactivate the current FIFO
        write_activate    <=  0;
        write_strobe      <=  0;
      end
      #(`WRITE_PERIOD);
    end
  end
  write_activate    <=  0;
  write_strobe      <=  0;
  #(`WRITE_PERIOD);


  #( (1 << `ADDRESS_SIZE + 1) * `WRITE_PERIOD);
  #10000
  $finish();

end

always @ (posedge read_clock) begin
  if (rst) begin
    output_data   <=  0;
    output_count  <=  0;
    data_valid    <=  0;
    input_count   <=  0;
    read_activate <=  0;
  end
  else begin
    read_strobe   <=  0;

    if (data_valid) begin
      data_valid  <=  0;
      $display ("READ_SM: Read %t: %h", $time, output_data);
    end

    if (read_strobe) begin
      data_valid    <=  1;
      output_data <=  read_data;
    end


    if (!read_activate && read_ready) begin
      read_activate         <=  1;
      output_count          <=  read_count;
    end
    else if (read_activate && output_count > 0) begin
      read_strobe           <=  1;
      output_count          <=  output_count - 1;
    end
    else if (output_count == 0) begin
      read_activate         <=  0;
    end
  end
end

endmodule
