`ifndef __PROJECT_INCLUDE__
`define __PROJECT_INCLUDE__

`define COMMAND_LENGTH      4

`define COMMAND_DATA_0      0
`define COMMAND_DATA_1      1
`define COMMAND_DATA_2      2
`define COMMAND_DATA_3      3

`define STATUS_LENGTH       3

`define STATUS_DATA_0       0
`define STATUS_DATA_1       1
`define STATUS_DATA_2       2

`define CONFIG_LENGTH       1

`define CONFIG_DATA_0       0

`define PING_COMMAND        8'h0
`define WRITE_COMMAND       8'h1
`define READ_COMMAND        8'h2
`define CONFIG_COMMAND      8'h3

`define IDENTIFICATION      16'hC594
`define IDENTIFICATION_RESP 16'h495C
`define IDENTIFICATION_ERR  16'hAAAA
`define IDENTIFICATION_INT  16'h0441

`define INTERRUPT_STATUS    8'h55


`endif
