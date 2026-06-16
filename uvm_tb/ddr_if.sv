interface ddr_if(input logic clk);
  logic rst_n;

  logic        cmd_valid;
  logic        cmd_ready;
  logic [2:0]  cmd;
  logic [7:0]  cmd_id;
  logic [1:0]  bank;
  logic [7:0]  row;
  logic [7:0]  col;
  logic [31:0] wdata;

  logic        rsp_valid;
  logic        rsp_ready;
  logic [2:0]  rsp_status;
  logic [7:0]  rsp_id;
  logic [31:0] rsp_rdata;

endinterface
