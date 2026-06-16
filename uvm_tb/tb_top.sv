`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import ddr_uvm_pkg::*;

  logic clk;
  ddr_if dif(clk);

  initial clk = 1'b0;
  always #5 clk = ~clk;

  ddr_ctrl_model dut (
    .clk(clk),
    .rst_n(dif.rst_n),
    .cmd_valid(dif.cmd_valid),
    .cmd_ready(dif.cmd_ready),
    .cmd(dif.cmd),
    .cmd_id(dif.cmd_id),
    .bank(dif.bank),
    .row(dif.row),
    .col(dif.col),
    .wdata(dif.wdata),
    .rsp_valid(dif.rsp_valid),
    .rsp_ready(dif.rsp_ready),
    .rsp_status(dif.rsp_status),
    .rsp_id(dif.rsp_id),
    .rsp_rdata(dif.rsp_rdata)
  );

  initial begin
    dif.rst_n = 1'b0;
    dif.cmd_valid = 1'b0;
    dif.cmd = 3'd0;
    dif.cmd_id = 8'd0;
    dif.bank = 2'd0;
    dif.row = 8'd0;
    dif.col = 8'd0;
    dif.wdata = 32'd0;
    dif.rsp_ready = 1'b1;
    repeat (6) @(posedge clk);
    dif.rst_n = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual ddr_if)::set(null, "*", "vif", dif);
    run_test();
  end

endmodule
