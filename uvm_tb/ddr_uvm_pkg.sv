package ddr_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `uvm_analysis_imp_decl(_cmd)
  `uvm_analysis_imp_decl(_pred)
  `uvm_analysis_imp_decl(_act)

  typedef enum bit [2:0] {
    CMD_NOP   = 3'd0,
    CMD_ACT   = 3'd1,
    CMD_READ  = 3'd2,
    CMD_WRITE = 3'd3,
    CMD_PRE   = 3'd4,
    CMD_REF   = 3'd5
  } ddr_cmd_e;

  typedef enum bit [2:0] {
    ST_OK         = 3'd0,
    ST_ERR_TIMING = 3'd1,
    ST_ERR_STATE  = 3'd2,
    ST_ERR_CMD    = 3'd3
  } ddr_status_e;

  localparam int T_RCD = 2;
  localparam int T_RAS = 4;
  localparam int T_RP  = 2;
  localparam int T_CCD = 1;

  class ddr_cmd_item extends uvm_sequence_item;
    rand ddr_cmd_e   cmd;
    rand bit [7:0]   id;
    rand bit [1:0]   bank;
    rand bit [7:0]   row;
    rand bit [7:0]   col;
    rand bit [31:0]  wdata;
    longint unsigned issue_cycle;

    `uvm_object_utils_begin(ddr_cmd_item)
      `uvm_field_enum(ddr_cmd_e, cmd, UVM_ALL_ON)
      `uvm_field_int(id, UVM_ALL_ON)
      `uvm_field_int(bank, UVM_ALL_ON)
      `uvm_field_int(row, UVM_ALL_ON)
      `uvm_field_int(col, UVM_ALL_ON)
      `uvm_field_int(wdata, UVM_ALL_ON)
      `uvm_field_int(issue_cycle, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ddr_cmd_item");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("cmd=%0d id=%0h b=%0d r=%0h c=%0h wd=%0h",
        cmd, id, bank, row, col, wdata);
    endfunction
  endclass

  class ddr_rsp_item extends uvm_object;
    ddr_status_e status;
    bit [7:0]    id;
    bit [31:0]   rdata;
    bit          data_valid;

    `uvm_object_utils_begin(ddr_rsp_item)
      `uvm_field_enum(ddr_status_e, status, UVM_ALL_ON)
      `uvm_field_int(id, UVM_ALL_ON)
      `uvm_field_int(rdata, UVM_ALL_ON)
      `uvm_field_int(data_valid, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "ddr_rsp_item");
      super.new(name);
    endfunction
  endclass

  class ddr_sequencer extends uvm_sequencer #(ddr_cmd_item);
    `uvm_component_utils(ddr_sequencer)
    function new(string name = "ddr_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction
  endclass

  class ddr_driver extends uvm_driver #(ddr_cmd_item);
    `uvm_component_utils(ddr_driver)
    virtual ddr_if vif;

    function new(string name = "ddr_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ddr_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "ddr_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      ddr_cmd_item tr;
      vif.cmd_valid <= 1'b0;
      vif.rsp_ready <= 1'b1;
      forever begin
        seq_item_port.get_next_item(tr);
        drive_cmd(tr);
        seq_item_port.item_done();
      end
    endtask

    task drive_cmd(ddr_cmd_item tr);
      @(posedge vif.clk);
      while (vif.cmd_ready !== 1'b1) @(posedge vif.clk);
      vif.cmd_valid <= 1'b1;
      vif.cmd      <= tr.cmd;
      vif.cmd_id   <= tr.id;
      vif.bank     <= tr.bank;
      vif.row      <= tr.row;
      vif.col      <= tr.col;
      vif.wdata    <= tr.wdata;
      `uvm_info("DRV", {"Drive ", tr.convert2string()}, UVM_MEDIUM)
      @(posedge vif.clk);
      vif.cmd_valid <= 1'b0;
    endtask
  endclass

  class ddr_cmd_monitor extends uvm_component;
    `uvm_component_utils(ddr_cmd_monitor)
    virtual ddr_if vif;
    uvm_analysis_port #(ddr_cmd_item) ap;
    longint unsigned mon_cycle;

    function new(string name = "ddr_cmd_monitor", uvm_component parent = null);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ddr_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "ddr_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      mon_cycle = 0;
      forever begin
        @(posedge vif.clk);
        mon_cycle++;
        if (vif.cmd_valid && vif.cmd_ready) begin
          ddr_cmd_item tr = ddr_cmd_item::type_id::create("tr", this);
          tr.cmd = ddr_cmd_e'(vif.cmd);
          tr.id = vif.cmd_id;
          tr.bank = vif.bank;
          tr.row = vif.row;
          tr.col = vif.col;
          tr.wdata = vif.wdata;
          tr.issue_cycle = mon_cycle;
          ap.write(tr);
        end
      end
    endtask
  endclass

  class ddr_rsp_monitor extends uvm_component;
    `uvm_component_utils(ddr_rsp_monitor)
    virtual ddr_if vif;
    uvm_analysis_port #(ddr_rsp_item) ap;

    function new(string name = "ddr_rsp_monitor", uvm_component parent = null);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual ddr_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "ddr_if not set")
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        if (vif.rsp_valid && vif.rsp_ready) begin
          ddr_rsp_item tr = ddr_rsp_item::type_id::create("rsp", this);
          tr.status = ddr_status_e'(vif.rsp_status);
          tr.id = vif.rsp_id;
          tr.rdata = vif.rsp_rdata;
          tr.data_valid = 1'b1;
          ap.write(tr);
        end
      end
    endtask
  endclass

  class ddr_predictor extends uvm_component;
    `uvm_component_utils(ddr_predictor)

    uvm_analysis_imp_cmd #(ddr_cmd_item, ddr_predictor) cmd_imp;
    uvm_analysis_port    #(ddr_rsp_item)                 pred_ap;

    bit       open_valid [4];
    bit [7:0] open_row   [4];
    bit [31:0] mem [int unsigned];

    int last_act_cycle [4];
    int last_pre_cycle [4];
    int last_rw_cycle;

    function new(string name = "ddr_predictor", uvm_component parent = null);
      super.new(name, parent);
      cmd_imp = new("cmd_imp", this);
      pred_ap = new("pred_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      last_rw_cycle = -1000;
      foreach (open_valid[i]) begin
        open_valid[i] = 0;
        open_row[i] = 0;
        last_act_cycle[i] = -1000;
        last_pre_cycle[i] = -1000;
      end
    endfunction

    function void write_cmd(ddr_cmd_item cmd_tr);
      ddr_rsp_item pred;
      int idx;
      int cyc;
      pred = ddr_rsp_item::type_id::create("pred");
      cyc = cmd_tr.issue_cycle;
      pred.id = cmd_tr.id;
      pred.status = ST_OK;
      pred.rdata = 32'd0;
      pred.data_valid = 1'b0;
      idx = {cmd_tr.bank, cmd_tr.row, cmd_tr.col};

      case (cmd_tr.cmd)
        CMD_NOP: pred.status = ST_OK;

        CMD_ACT: begin
          if (open_valid[cmd_tr.bank]) pred.status = ST_ERR_STATE;
          else if ((cyc - last_pre_cycle[cmd_tr.bank]) < T_RP) pred.status = ST_ERR_TIMING;
          else begin
            open_valid[cmd_tr.bank] = 1;
            open_row[cmd_tr.bank] = cmd_tr.row;
            last_act_cycle[cmd_tr.bank] = cyc;
          end
        end

        CMD_READ: begin
          if (!open_valid[cmd_tr.bank] || (open_row[cmd_tr.bank] != cmd_tr.row)) pred.status = ST_ERR_STATE;
          else if ((cyc - last_act_cycle[cmd_tr.bank]) < T_RCD) pred.status = ST_ERR_TIMING;
          else if ((cyc - last_rw_cycle) < T_CCD) pred.status = ST_ERR_TIMING;
          else begin
            pred.status = ST_OK;
            pred.rdata = mem.exists(idx) ? mem[idx] : 32'd0;
            pred.data_valid = 1'b1;
            last_rw_cycle = cyc;
          end
        end

        CMD_WRITE: begin
          if (!open_valid[cmd_tr.bank] || (open_row[cmd_tr.bank] != cmd_tr.row)) pred.status = ST_ERR_STATE;
          else if ((cyc - last_act_cycle[cmd_tr.bank]) < T_RCD) pred.status = ST_ERR_TIMING;
          else if ((cyc - last_rw_cycle) < T_CCD) pred.status = ST_ERR_TIMING;
          else begin
            pred.status = ST_OK;
            mem[idx] = cmd_tr.wdata;
            last_rw_cycle = cyc;
          end
        end

        CMD_PRE: begin
          if (!open_valid[cmd_tr.bank]) pred.status = ST_ERR_STATE;
          else if ((cyc - last_act_cycle[cmd_tr.bank]) < T_RAS) pred.status = ST_ERR_TIMING;
          else begin
            open_valid[cmd_tr.bank] = 0;
            last_pre_cycle[cmd_tr.bank] = cyc;
          end
        end

        CMD_REF: begin
          if (open_valid[0] || open_valid[1] || open_valid[2] || open_valid[3]) pred.status = ST_ERR_STATE;
          else pred.status = ST_OK;
        end

        default: pred.status = ST_ERR_CMD;
      endcase

      pred_ap.write(pred);
    endfunction
  endclass

  class ddr_scoreboard extends uvm_component;
    `uvm_component_utils(ddr_scoreboard)

    uvm_analysis_imp_pred #(ddr_rsp_item, ddr_scoreboard) pred_imp;
    uvm_analysis_imp_act  #(ddr_rsp_item, ddr_scoreboard) act_imp;

    ddr_rsp_item exp_by_id [byte unsigned];
    int pass_cnt;
    int fail_cnt;

    function new(string name = "ddr_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      pred_imp = new("pred_imp", this);
      act_imp = new("act_imp", this);
      pass_cnt = 0;
      fail_cnt = 0;
    endfunction

    function void write_pred(ddr_rsp_item t);
      exp_by_id[t.id] = t;
    endfunction

    function void write_act(ddr_rsp_item t);
      ddr_rsp_item exp;
      if (!exp_by_id.exists(t.id)) begin
        fail_cnt++;
        `uvm_error("SB", $sformatf("Unexpected response id=%0h", t.id))
        return;
      end
      exp = exp_by_id[t.id];
      exp_by_id.delete(t.id);

      if (t.status != exp.status) begin
        fail_cnt++;
        `uvm_error("SB", $sformatf("Status mismatch id=%0h exp=%0d got=%0d", t.id, exp.status, t.status))
      end else if (exp.data_valid && (t.rdata != exp.rdata)) begin
        fail_cnt++;
        `uvm_error("SB", $sformatf("Data mismatch id=%0h exp=%0h got=%0h", t.id, exp.rdata, t.rdata))
      end else begin
        pass_cnt++;
        `uvm_info("SB", $sformatf("PASS id=%0h status=%0d data=%0h", t.id, t.status, t.rdata), UVM_MEDIUM)
      end
    endfunction

    function void report_phase(uvm_phase phase);
      if (exp_by_id.num() != 0) begin
        fail_cnt += exp_by_id.num();
        `uvm_error("SB", $sformatf("%0d predictions unmatched", exp_by_id.num()))
      end
      `uvm_info("SB", $sformatf("Scoreboard PASS=%0d FAIL=%0d", pass_cnt, fail_cnt), UVM_NONE)
      if (fail_cnt > 0)
        `uvm_error("SB", "Scoreboard has failures")
    endfunction
  endclass

  class ddr_cov extends uvm_component;
    `uvm_component_utils(ddr_cov)

    uvm_analysis_imp_cmd #(ddr_cmd_item, ddr_cov) cmd_imp;
    uvm_analysis_imp_act #(ddr_rsp_item, ddr_cov) rsp_imp;

    ddr_cmd_e last_cmd_by_id [byte unsigned];
    bit [1:0] last_bank_by_id [byte unsigned];

    bit [2:0] cov_cmd;
    bit [2:0] cov_status;
    bit [1:0] cov_bank;

    covergroup cg;
      cp_cmd: coverpoint cov_cmd {
        bins nop = {CMD_NOP};
        bins act = {CMD_ACT};
        bins rd  = {CMD_READ};
        bins wr  = {CMD_WRITE};
        bins pre = {CMD_PRE};
        bins ref_cmd = {CMD_REF};
      }
      cp_status: coverpoint cov_status {
        bins ok  = {ST_OK};
        bins tmg = {ST_ERR_TIMING};
        bins st  = {ST_ERR_STATE};
        bins cmd = {ST_ERR_CMD};
      }
      cp_bank: coverpoint cov_bank;
      x_cmd_status: cross cp_cmd, cp_status;
      x_status_bank: cross cp_status, cp_bank;
    endgroup

    function new(string name = "ddr_cov", uvm_component parent = null);
      super.new(name, parent);
      cmd_imp = new("cmd_imp", this);
      rsp_imp = new("rsp_imp", this);
      cg = new();
    endfunction

    function void write_cmd(ddr_cmd_item t);
      last_cmd_by_id[t.id] = t.cmd;
      last_bank_by_id[t.id] = t.bank;
    endfunction

    function void write_act(ddr_rsp_item t);
      if (!last_cmd_by_id.exists(t.id)) return;
      cov_cmd = last_cmd_by_id[t.id];
      cov_status = t.status;
      cov_bank = last_bank_by_id[t.id];
      cg.sample();
      last_cmd_by_id.delete(t.id);
      last_bank_by_id.delete(t.id);
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("COV", $sformatf("Coverage=%0.2f%%", cg.get_coverage()), UVM_NONE)
    endfunction
  endclass

  class ddr_cmd_agent extends uvm_component;
    `uvm_component_utils(ddr_cmd_agent)
    ddr_sequencer sqr;
    ddr_driver drv;
    ddr_cmd_monitor mon;

    function new(string name = "ddr_cmd_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = ddr_sequencer::type_id::create("sqr", this);
      drv = ddr_driver::type_id::create("drv", this);
      mon = ddr_cmd_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  class ddr_rsp_agent extends uvm_component;
    `uvm_component_utils(ddr_rsp_agent)
    ddr_rsp_monitor mon;

    function new(string name = "ddr_rsp_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = ddr_rsp_monitor::type_id::create("mon", this);
    endfunction
  endclass

  class ddr_env extends uvm_env;
    `uvm_component_utils(ddr_env)
    ddr_cmd_agent cmd_agent;
    ddr_rsp_agent rsp_agent;
    ddr_predictor predictor;
    ddr_scoreboard sb;
    ddr_cov cov;

    function new(string name = "ddr_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cmd_agent = ddr_cmd_agent::type_id::create("cmd_agent", this);
      rsp_agent = ddr_rsp_agent::type_id::create("rsp_agent", this);
      predictor = ddr_predictor::type_id::create("predictor", this);
      sb = ddr_scoreboard::type_id::create("sb", this);
      cov = ddr_cov::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      cmd_agent.mon.ap.connect(predictor.cmd_imp);
      predictor.pred_ap.connect(sb.pred_imp);
      rsp_agent.mon.ap.connect(sb.act_imp);

      cmd_agent.mon.ap.connect(cov.cmd_imp);
      rsp_agent.mon.ap.connect(cov.rsp_imp);
    endfunction
  endclass

  class ddr_base_seq extends uvm_sequence #(ddr_cmd_item);
    `uvm_object_utils(ddr_base_seq)
    byte unsigned next_id;

    function new(string name = "ddr_base_seq");
      super.new(name);
      next_id = 8'h01;
    endfunction

    task send(ddr_cmd_e cmd, bit [1:0] bank, bit [7:0] row, bit [7:0] col, bit [31:0] wdata);
      ddr_cmd_item tr;
      tr = ddr_cmd_item::type_id::create("tr");
      start_item(tr);
      tr.cmd = cmd;
      tr.id = next_id;
      tr.bank = bank;
      tr.row = row;
      tr.col = col;
      tr.wdata = wdata;
      next_id++;
      finish_item(tr);
    endtask

    task nop(int n = 1);
      repeat (n) send(CMD_NOP, 0, 0, 0, 0);
    endtask
  endclass

  class smoke_seq extends ddr_base_seq;
    `uvm_object_utils(smoke_seq)
    function new(string name = "smoke_seq"); super.new(name); endfunction

    task body();
      send(CMD_ACT,   2'd0, 8'h10, 8'h00, 32'd0);
      nop(2);
      send(CMD_WRITE, 2'd0, 8'h10, 8'h04, 32'hDEAD_BEEF);
      send(CMD_READ,  2'd0, 8'h10, 8'h04, 32'd0);
      nop(3);
      send(CMD_PRE,   2'd0, 8'h10, 8'h00, 32'd0);
      nop(2);
      send(CMD_REF,   2'd0, 8'h00, 8'h00, 32'd0);
    endtask
  endclass

  class timing_violation_seq extends ddr_base_seq;
    `uvm_object_utils(timing_violation_seq)
    function new(string name = "timing_violation_seq"); super.new(name); endfunction

    task body();
      send(CMD_ACT,   2'd1, 8'h20, 8'h00, 32'd0);
      send(CMD_READ,  2'd1, 8'h20, 8'h01, 32'd0); // tRCD violation
      send(CMD_PRE,   2'd1, 8'h20, 8'h00, 32'd0); // tRAS violation
      nop(4);
      send(CMD_PRE,   2'd1, 8'h20, 8'h00, 32'd0); // legal
      send(CMD_ACT,   2'd1, 8'h21, 8'h00, 32'd0); // tRP violation
      nop(2);
      send(CMD_ACT,   2'd1, 8'h21, 8'h00, 32'd0); // legal
    endtask
  endclass

  class refresh_seq extends ddr_base_seq;
    `uvm_object_utils(refresh_seq)
    function new(string name = "refresh_seq"); super.new(name); endfunction

    task body();
      send(CMD_ACT,   2'd2, 8'h30, 8'h00, 32'd0);
      nop(2);
      send(CMD_REF,   2'd0, 8'h00, 8'h00, 32'd0); // illegal, bank still open
      nop(2);
      send(CMD_WRITE, 2'd2, 8'h30, 8'h02, 32'hA5A5_5A5A);
      nop(3);
      send(CMD_PRE,   2'd2, 8'h30, 8'h00, 32'd0);
      nop(2);
      send(CMD_REF,   2'd0, 8'h00, 8'h00, 32'd0); // legal refresh
      nop(5);
      send(CMD_ACT,   2'd2, 8'h30, 8'h00, 32'd0);
      nop(2);
      send(CMD_READ,  2'd2, 8'h30, 8'h02, 32'd0);
    endtask
  endclass

  class random_legal_seq extends ddr_base_seq;
    `uvm_object_utils(random_legal_seq)
    int unsigned n_ops;
    function new(string name = "random_legal_seq");
      super.new(name);
      n_ops = 20;
    endfunction

    task body();
      bit [1:0] b;
      bit [7:0] r;
      bit [7:0] c;
      repeat (n_ops) begin
        b = $urandom_range(0,3);
        r = $urandom_range(0,255);
        c = $urandom_range(0,255);
        send(CMD_ACT, b, r, 8'h00, 0);
        nop(2);
        send(CMD_WRITE, b, r, c, $urandom());
        send(CMD_READ,  b, r, c, 32'd0);
        nop(3);
        send(CMD_PRE, b, r, 8'h00, 32'd0);
        nop(2);
      end
      send(CMD_REF, 0, 0, 0, 0);
    endtask
  endclass

  class stress_mix_seq extends ddr_base_seq;
    `uvm_object_utils(stress_mix_seq)
    int unsigned n_ops;
    function new(string name = "stress_mix_seq");
      super.new(name);
      n_ops = 40;
    endfunction

    task body();
      bit [1:0] b;
      bit [7:0] r;
      bit [7:0] c;
      repeat (n_ops) begin
        b = $urandom_range(0,3);
        r = $urandom_range(0,255);
        c = $urandom_range(0,255);
        if ($urandom_range(0,9) < 7) begin
          send(CMD_ACT, b, r, 0, 0);
          nop(2);
          if ($urandom_range(0,1)) send(CMD_WRITE, b, r, c, $urandom());
          else send(CMD_READ, b, r, c, 0);
          nop(3);
          send(CMD_PRE, b, r, 0, 0);
          nop(2);
        end else begin
          case ($urandom_range(0,2))
            0: begin
              send(CMD_ACT, b, r, 0, 0);
              send(CMD_READ, b, r, c, 0);
            end
            1: begin
              send(CMD_PRE, b, r, 0, 0);
            end
            2: begin
              send(CMD_REF, 0, 0, 0, 0);
            end
          endcase
          nop(2);
        end
      end
    endtask
  endclass

  class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    ddr_env env;

    function new(string name = "base_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = ddr_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      uvm_top.print_topology();
    endfunction
  endclass

  class smoke_test extends base_test;
    `uvm_component_utils(smoke_test)
    function new(string name = "smoke_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      smoke_seq seq;
      phase.raise_objection(this);
      seq = smoke_seq::type_id::create("seq");
      seq.start(env.cmd_agent.sqr);
      #500ns;
      phase.drop_objection(this);
    endtask
  endclass

  class timing_test extends base_test;
    `uvm_component_utils(timing_test)
    function new(string name = "timing_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      timing_violation_seq seq;
      phase.raise_objection(this);
      seq = timing_violation_seq::type_id::create("seq");
      seq.start(env.cmd_agent.sqr);
      #700ns;
      phase.drop_objection(this);
    endtask
  endclass

  class refresh_test extends base_test;
    `uvm_component_utils(refresh_test)
    function new(string name = "refresh_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      refresh_seq seq;
      phase.raise_objection(this);
      seq = refresh_seq::type_id::create("seq");
      seq.start(env.cmd_agent.sqr);
      #900ns;
      phase.drop_objection(this);
    endtask
  endclass

  class random_test extends base_test;
    `uvm_component_utils(random_test)
    function new(string name = "random_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      random_legal_seq seq;
      phase.raise_objection(this);
      seq = random_legal_seq::type_id::create("seq");
      seq.n_ops = 20;
      seq.start(env.cmd_agent.sqr);
      #2000ns;
      phase.drop_objection(this);
    endtask
  endclass

  class stress_test extends base_test;
    `uvm_component_utils(stress_test)
    function new(string name = "stress_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
      stress_mix_seq seq;
      phase.raise_objection(this);
      seq = stress_mix_seq::type_id::create("seq");
      seq.n_ops = 60;
      seq.start(env.cmd_agent.sqr);
      #2500ns;
      phase.drop_objection(this);
    endtask
  endclass

endpackage
