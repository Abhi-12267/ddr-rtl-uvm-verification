module ddr_ctrl_model (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cmd_valid,
    output wire        cmd_ready,
    input  wire [2:0]  cmd,
    input  wire [7:0]  cmd_id,
    input  wire [1:0]  bank,
    input  wire [7:0]  row,
    input  wire [7:0]  col,
    input  wire [31:0] wdata,
    output reg         rsp_valid,
    input  wire        rsp_ready,
    output reg  [2:0]  rsp_status,
    output reg  [7:0]  rsp_id,
    output reg  [31:0] rsp_rdata
);

localparam [2:0] CMD_NOP   = 3'd0;
localparam [2:0] CMD_ACT   = 3'd1;
localparam [2:0] CMD_READ  = 3'd2;
localparam [2:0] CMD_WRITE = 3'd3;
localparam [2:0] CMD_PRE   = 3'd4;
localparam [2:0] CMD_REF   = 3'd5;

localparam [2:0] ST_OK         = 3'd0;
localparam [2:0] ST_ERR_TIMING = 3'd1;
localparam [2:0] ST_ERR_STATE  = 3'd2;
localparam [2:0] ST_ERR_CMD    = 3'd3;

localparam integer T_RCD = 2;
localparam integer T_RAS = 4;
localparam integer T_RP  = 2;
localparam integer T_CCD = 1;
localparam integer T_RFC = 4;

reg        open_valid [0:3];
reg [7:0]  open_row   [0:3];
reg [31:0] mem        [0:262143];

reg [31:0] cycle;
reg [31:0] last_act_cycle [0:3];
reg [31:0] last_pre_cycle [0:3];
reg [31:0] last_rw_cycle;
reg [31:0] refresh_busy_until;

reg        pipe_valid;
reg [2:0]  pipe_status;
reg [7:0]  pipe_id;
reg [31:0] pipe_rdata;

integer i;
reg [17:0] idx;
reg [2:0]  next_status;
reg [31:0] next_rdata;
reg        all_precharged;

assign cmd_ready = rst_n && (cycle >= refresh_busy_until);

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    cycle <= 32'd0;
    last_rw_cycle <= 32'd0;
    refresh_busy_until <= 32'd0;

    rsp_valid  <= 1'b0;
    rsp_status <= ST_OK;
    rsp_id     <= 8'd0;
    rsp_rdata  <= 32'd0;

    pipe_valid  <= 1'b0;
    pipe_status <= ST_OK;
    pipe_id     <= 8'd0;
    pipe_rdata  <= 32'd0;

    for (i = 0; i < 4; i = i + 1) begin
      open_valid[i] <= 1'b0;
      open_row[i] <= 8'd0;
      last_act_cycle[i] <= 32'd0;
      last_pre_cycle[i] <= 32'd0;
    end

    for (i = 0; i < 262144; i = i + 1) begin
      mem[i] <= 32'd0;
    end
  end else begin
    cycle <= cycle + 1'b1;

    if (rsp_valid && rsp_ready) begin
      rsp_valid <= 1'b0;
    end

    if (!rsp_valid && pipe_valid) begin
      rsp_valid  <= 1'b1;
      rsp_status <= pipe_status;
      rsp_id     <= pipe_id;
      rsp_rdata  <= pipe_rdata;
      pipe_valid <= 1'b0;
    end

    if (cmd_valid && cmd_ready && !pipe_valid) begin
      next_status = ST_OK;
      next_rdata  = 32'd0;
      idx = {bank, row, col};

      case (cmd)
        CMD_NOP: begin
          next_status = ST_OK;
        end

        CMD_ACT: begin
          if (open_valid[bank]) begin
            next_status = ST_ERR_STATE;
          end else if ((cycle - last_pre_cycle[bank]) < T_RP) begin
            next_status = ST_ERR_TIMING;
          end else begin
            open_valid[bank] <= 1'b1;
            open_row[bank] <= row;
            last_act_cycle[bank] <= cycle;
          end
        end

        CMD_READ: begin
          if (!open_valid[bank] || (open_row[bank] != row)) begin
            next_status = ST_ERR_STATE;
          end else if ((cycle - last_act_cycle[bank]) < T_RCD) begin
            next_status = ST_ERR_TIMING;
          end else if ((cycle - last_rw_cycle) < T_CCD) begin
            next_status = ST_ERR_TIMING;
          end else begin
            next_status = ST_OK;
            next_rdata = mem[idx];
            last_rw_cycle <= cycle;
          end
        end

        CMD_WRITE: begin
          if (!open_valid[bank] || (open_row[bank] != row)) begin
            next_status = ST_ERR_STATE;
          end else if ((cycle - last_act_cycle[bank]) < T_RCD) begin
            next_status = ST_ERR_TIMING;
          end else if ((cycle - last_rw_cycle) < T_CCD) begin
            next_status = ST_ERR_TIMING;
          end else begin
            mem[idx] <= wdata;
            last_rw_cycle <= cycle;
          end
        end

        CMD_PRE: begin
          if (!open_valid[bank]) begin
            next_status = ST_ERR_STATE;
          end else if ((cycle - last_act_cycle[bank]) < T_RAS) begin
            next_status = ST_ERR_TIMING;
          end else begin
            open_valid[bank] <= 1'b0;
            last_pre_cycle[bank] <= cycle;
          end
        end

        CMD_REF: begin
          all_precharged = !open_valid[0] && !open_valid[1] && !open_valid[2] && !open_valid[3];
          if (!all_precharged) begin
            next_status = ST_ERR_STATE;
          end else begin
            refresh_busy_until <= cycle + T_RFC;
          end
        end

        default: begin
          next_status = ST_ERR_CMD;
        end
      endcase

      pipe_valid  <= 1'b1;
      pipe_status <= next_status;
      pipe_id     <= cmd_id;
      pipe_rdata  <= next_rdata;
    end
  end
end

endmodule
