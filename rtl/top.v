`timescale 1ns / 1ps

module top(

input             main_clk,
input             n_rst,
output     [3:0]  n_led,
input      [3:0]  n_button,
input      [1:0]  switch

);

//Local Parameters

//Registers/Wires
wire                  rst;
reg     [3:0]         led;
wire    [3:0]         button;
//Submodules

//Asynchronous Logic
assign  rst     =   n_rst;
assign  n_led   =   ~led;
assign  button  =   ~n_button;

//Synchronous Logic
always @ (posedge main_clk) begin
  led[0]        <=  ~led[0];
  if (!rst) begin
    led[1]      <=  0;
    led[2]      <=  0;
    led[3]      <=  0;
  end
  else begin
    led[1] <= ~led[1];
    if (button[1]) begin
      led[1] <= 1;
    end
  end
end
endmodule
