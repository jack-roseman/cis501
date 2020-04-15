/* Ryan Telesca - ryashnic
* Jack Roseman - jackrose
 *
 * lc4_single.v
 * Implements a single-cycle data path
 *
 */

`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor (input  wire        clk,                // Main clock
                      input  wire        rst,                // Global reset
                      input  wire        gwe,                // Global we for single-step clock
   
                      output wire [15:0] o_cur_pc,           // Address to read from instruction memory
                      input  wire [15:0] i_cur_insn,         // Output of instruction memory
                      output wire [15:0] o_dmem_addr,        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
                      input  wire [15:0] i_cur_dmem_data,    // Output of data memory
                      output wire        o_dmem_we,          // Data memory write enable
                      output wire [15:0] o_dmem_towrite,     // Value to write to data memory

                      // Testbench signals are used by the testbench to verify the correctness of your datapath.
                      // Many of these signals simply export internal processor state for verification (such as the PC).
                      // Some signals are duplicate output signals for clarity of purpose.
                      //
                      // Don't forget to include these in your schematic!

                      output wire [1:0]  test_stall,         // Testbench: is this a stall cycle? (don't compare the test values)
                      output wire [15:0] test_cur_pc,        // Testbench: program counter
                      output wire [15:0] test_cur_insn,      // Testbench: instruction bits
                      output wire        test_regfile_we,    // Testbench: register file write enable
                      output wire [2:0]  test_regfile_wsel,  // Testbench: which register to write in the register file 
                      output wire [15:0] test_regfile_data,  // Testbench: value to write into the register file
                      output wire        test_nzp_we,        // Testbench: NZP condition codes write enable
                      output wire [2:0]  test_nzp_new_bits,  // Testbench: value to write to NZP bits
                      output wire        test_dmem_we,       // Testbench: data memory write enable
                      output wire [15:0] test_dmem_addr,     // Testbench: address to read/write memory
                      output wire [15:0] test_dmem_data,     // Testbench: value read/writen from/to memory
                
                      input  wire [7:0]  switch_data,        // Current settings of the Zedboard switches
                      output wire [7:0]  led_data            // Which Zedboard LEDs should be turned on?
                     );

      // By default, assign LEDs to display switch inputs to avoid warnings about
      // disconnected ports. Feel free to use this for debugging input/output if
      // you desire.
      assign led_data = switch_data;
      wire superscalar = 1'b0;
      wire [1:0] D_stall, X_stall, M_stall, W_stall;
      wire [2:0] nzp_in, nzp;
      wire [2:0] rd;
      wire [15:0] D_insn, X_insn_in, X_insn, M_insn_in, M_insn, W_insn, alu_result;
      wire [15:0] rsdata, rtdata, rddata, X_A, X_B, M_O, M_B, W_O, W_D_in, W_D;
      wire [15:0] i_alu_r1data, i_alu_r2data; //inputs to ALU 
      wire [1:0] A_bypass_sel, B_bypass_sel; //assigned by bypass logic module
      wire [2:0] F_rs, F_rt, F_rd;
      wire [2:0] D_rs, D_rt, D_rd;
      wire [2:0] X_rs, X_rt, X_rd;
      wire [2:0] M_rs, M_rt, M_rd;
      wire [2:0] W_rs, W_rt, W_rd;
      //wire F_rs_re, F_rt_re, F_regfile_we, F_nzp_we, F_select_pc_plus_one, F_is_load, F_is_store, F_is_branch, F_is_control_insn;
      wire D_rs_re, D_rt_re, D_regfile_we, D_nzp_we, D_select_pc_plus_one, D_is_load, D_is_store, D_is_branch, D_is_control_insn;
      wire X_rs_re, X_rt_re, X_regfile_we, X_nzp_we, X_select_pc_plus_one, X_is_load, X_is_store, X_is_branch, X_is_control_insn;
      wire M_rs_re, M_rt_re, M_regfile_we, M_nzp_we, M_select_pc_plus_one, M_is_load, M_is_store, M_is_branch, M_is_control_insn;
      wire W_rs_re, W_rt_re, W_regfile_we, W_nzp_we, W_select_pc_plus_one, W_is_load, W_is_store, W_is_branch, W_is_control_insn;
      wire [15:0] D_data, X_data, M_data, W_data; 
      wire [8:0] F_bus, D_bus, X_bus, M_bus, W_bus;
      wire [15:0] pc, pc_plus_one, D_pc, X_pc, M_pc, W_pc, next_pc;

      //rsre (8), rtre (7), regfilewe (6), nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)
      assign D_rs_re =              D_bus[8];
      assign D_rt_re =              D_bus[7];
      assign D_regfile_we =         D_bus[6];
      assign D_nzp_we =             D_bus[5];
      assign D_select_pc_plus_one = D_bus[4];
      assign D_is_load =            D_bus[3];
      assign D_is_store =           D_bus[2];
      assign D_is_branch =          D_bus[1];
      assign D_is_control_insn =    D_bus[0];

      assign X_rs_re =              X_bus[8];
      assign X_rt_re =              X_bus[7];
      assign X_regfile_we =         X_bus[6];
      assign X_nzp_we =             X_bus[5];
      assign X_select_pc_plus_one = X_bus[4];
      assign X_is_load =            X_bus[3];
      assign X_is_store =           X_bus[2];
      assign X_is_branch =          X_bus[1];
      assign X_is_control_insn =    X_bus[0];

      assign M_rs_re =              M_bus[8];
      assign M_rt_re =              M_bus[7];
      assign M_regfile_we =         M_bus[6];
      assign M_nzp_we =             M_bus[5];
      assign M_select_pc_plus_one = M_bus[4];
      assign M_is_load =            M_bus[3];
      assign M_is_store =           M_bus[2];
      assign M_is_branch =          M_bus[1];
      assign M_is_control_insn =    M_bus[0];

      assign W_rs_re =              W_bus[8];
      assign W_rt_re =              W_bus[7];
      assign W_regfile_we =         W_bus[6];
      assign W_nzp_we =             W_bus[5];
      assign W_select_pc_plus_one = W_bus[4];
      assign W_is_load =            W_bus[3];
      assign W_is_store =           W_bus[2];
      assign W_is_branch =          W_bus[1];
      assign W_is_control_insn =    W_bus[0];

      
      wire should_stall = X_is_load && (D_rd == D_rs || (D_rd == D_rt && ~D_is_store));	
      wire should_flush = (X_is_branch && ~(alu_result == next_pc)); //case in which we flush
      wire [1:0] hazard = should_stall ? 2'b11 : (superscalar ? 2'b01 : (should_flush ? 2'b10 : 2'b00));
      wire is_const_hiconst = (X_insn[15:12] == 4'b1101) && (M_insn[15:12] == 4'b1001);
      wire [1:0] is_MX = 2'b00;//((M_rd == X_rs) || is_const_hiconst) ? 2'b01 : (M_rd == X_rt ? 2'b10 : 2'b00); 
      wire [1:0] is_WX = 2'b00;//W_rd == X_rs ? 2'b01 : (W_rd == X_rt ? 2'b10 : 2'b00);

      //BEGIN PIPELINE
      // Program counter register, starts at 8200h at bootup
      Nbit_reg #(16, 16'h8200) pc_reg   (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst || W_stall == 2'b10));
      Nbit_reg #(16, 16'b0)     D_pc_reg (.in(pc),      .out(D_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)    X_pc_reg (.in(D_pc),    .out(X_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(16, 16'b0)    M_pc_reg (.in(X_pc),    .out(M_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)    W_pc_reg (.in(M_pc),    .out(W_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      cla16 add_one(.a(pc), .b(16'b0), .cin(1'b1), .sum(pc_plus_one)); //assume the next instruction for the current decoded insn is pc + 1

      Nbit_reg #(16, 16'b0) D_insn_reg(.in(i_cur_insn), .out(D_insn), .clk(clk), .we(~should_stall), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0) X_insn_reg(.in(D_insn),     .out(X_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || should_stall || rst));
      Nbit_reg #(16, 16'b0) M_insn_reg(.in(X_insn),     .out(M_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(16, 16'b0) W_insn_reg(.in(M_insn),     .out(W_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(3) nzpreg(.in(nzp_in), .out(nzp), .clk(clk), .we(W_nzp_we), .gwe(gwe), .rst(rst)); //TODO - is we correct?
      
      lc4_decoder dec(  .insn(D_insn), 
                        .r1sel(D_rs), .r1re(D_bus[8]),
                        .r2sel(D_rt), .r2re(D_bus[7]), 
                        .wsel(D_rd), .regfile_we(D_bus[6]),
                        .nzp_we(D_bus[5]), .select_pc_plus_one(D_bus[4]), 
                        .is_load(D_bus[3]), .is_store(D_bus[2]), 
                        .is_branch(D_bus[1]), .is_control_insn(D_bus[0]));

      //Nbit_reg #(3, 3'b0) D_rs_reg(.in(F_rs), .out(D_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(3, 3'b0) X_rs_reg(.in(D_rs), .out(X_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(3, 3'b0) M_rs_reg(.in(X_rs), .out(M_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(3, 3'b0) W_rs_reg(.in(M_rs), .out(W_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      //Nbit_reg #(3, 3'b0) D_rt_reg(.in(F_rt), .out(D_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(3, 3'b0) X_rt_reg(.in(D_rt), .out(X_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(3, 3'b0) M_rt_reg(.in(X_rt), .out(M_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(3, 3'b0) W_rt_reg(.in(M_rt), .out(W_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      
      //Nbit_reg #(3, 3'b0) D_rd_reg(.in(F_rd), .out(D_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(3, 3'b0) X_rd_reg(.in(D_rd), .out(X_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(3, 3'b0) M_rd_reg(.in(X_rd), .out(M_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(3, 3'b0) W_rd_reg(.in(M_rd), .out(W_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      //REGISTER FILE
      lc4_regfile registerfile(  .i_rs(W_rs),        .i_rt(W_rt),        .i_rd(rd),
                                 .o_rs_data(rsdata), .o_rt_data(rtdata), .i_wdata(rddata), .i_rd_we(W_regfile_we),
                                 .clk(clk), .gwe(gwe), .rst(rst));  

      Nbit_reg #(16, 16'b0) X_A_reg(     .in(rsdata),     .out(X_A), .clk(clk), .we(X_rs_re), .gwe(gwe), .rst(should_flush || rst)); //Holds rsdata that comes out of register file
      Nbit_reg #(16, 16'b0) M_O_reg(     .in(alu_result), .out(M_O), .clk(clk), .we(1'b1),    .gwe(gwe), .rst(should_flush || rst)); //Holds dmem data
      Nbit_reg #(16, 16'b0) W_O_register(.in(M_O),        .out(W_O), .clk(clk), .we(1'b1),    .gwe(gwe), .rst(rst));
      
      Nbit_reg #(16, 16'b0) X_B_reg(     .in(rtdata),       .out(X_B), .clk(clk), .we(X_rt_re), .gwe(gwe), .rst(should_flush || rst)); //Holds rtdata that comes out of register file
      Nbit_reg #(16, 16'b0) M_B_reg(     .in(i_alu_r2data), .out(M_B), .clk(clk), .we(1'b1),    .gwe(gwe), .rst(should_flush || rst)); //Holds dmem address
      Nbit_reg #(16, 16'b0) W_D_register(.in(M_data),       .out(W_D), .clk(clk), .we(1'b1),    .gwe(gwe), .rst(rst));

      assign i_alu_r1data = is_MX == 2'b01 ? M_O : (is_WX == 2'b01 ? rddata : X_A);
      assign i_alu_r2data = is_MX == 2'b10 ? M_O : (is_WX == 2'b10 ? rddata : X_B);
      lc4_alu alu (.i_insn(X_insn), .i_pc(X_pc), .i_r1data(i_alu_r1data), .i_r2data(i_alu_r2data), .o_result(alu_result)); //ALU

      //Nbit_reg #(9, 9'b0) D_bus_reg(.in(F_bus), .out(D_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //WE don't need this
      Nbit_reg #(9, 9'b0) X_bus_reg(.in(D_bus), .out(X_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(9, 9'b0) M_bus_reg(.in(X_bus), .out(M_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(9, 9'b0) W_bus_reg(.in(M_bus), .out(W_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(16, 16'b0) D_data_reg(.in(i_cur_dmem_data), .out(D_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0) X_data_reg(.in(D_data),          .out(X_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(16, 16'b0) M_data_reg(.in(X_data),          .out(M_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(16, 16'b0) W_data_reg(.in(M_data),          .out(W_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(2, 2'b10) D_stall_reg(.in(hazard),  .out(D_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10) X_stall_reg(.in(D_stall), .out(X_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10) M_stall_reg(.in(X_stall), .out(M_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10) W_stall_reg(.in(M_stall), .out(W_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      //END PIPELINE

      assign nzp_in[2] = rddata[15];
      assign nzp_in[1] = &(~rddata);
      assign nzp_in[0] = ~rddata[15] && (|rddata);

      assign rddata = W_is_load ? W_D : W_O; //where WO_WD_sel is found based on bypass control logic
      assign rd = W_rd; //TODO - this is most likely incorrect
      assign next_pc = should_flush ? alu_result : pc_plus_one; //TODO - assume the next pc is pc+1

      //SET OUTPUTS
      assign o_dmem_we = M_is_store; //if store instruction is in M stage is the only time we write to memory;          // Data memory write enable
      assign o_dmem_addr = M_is_store || M_is_load ? M_O : 16'b0;        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
      assign o_dmem_towrite = M_data; //(W_is_load && M_is_store) && (W_rd == M_rt) ? M_B : rddata; 
      assign o_cur_pc = pc;

      //SET TESTING PINS - 
      assign test_regfile_we = W_regfile_we;    // Testbench: register file write enable
      assign test_regfile_wsel = W_rd;  // Testbench: which register to write in the register file
      assign test_regfile_data = rddata;  // Testbench: value to write into the register file
      assign test_nzp_we = W_nzp_we;     // Testbench: NZP condition codes write enable
      assign test_nzp_new_bits = nzp_in;  // Testbench: value to write to NZP bits
      assign test_dmem_we = o_dmem_we;       // Testbench: data memory write enable
      assign test_dmem_addr = o_dmem_addr;     // Testbench: address to read/write memory
      assign test_dmem_data = o_dmem_towrite;     // Testbench: value read/writen from/to memory 
      assign test_stall = W_stall; // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
      assign test_cur_pc = o_cur_pc; 
      assign test_cur_insn = i_cur_insn; 

    /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    * 
    * To disable the entire block add the statement
    * `define NDEBUG
    * to the top of your file.  We also define this symbol
    * when we run the grading scripts.
    */

`ifndef NDEBUG
   always @(posedge gwe) begin
      $display("%d CURR_PC=%h, D_INSN=%h X_INSN=%h, M_INSN=%h, W_INSN=%h", $time, pc, D_insn, X_insn, M_insn, W_insn);

      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecial.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      $display();
   end
`endif

endmodule //end of single cycle