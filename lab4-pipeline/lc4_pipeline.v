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

        wire [2:0] nzp_in, nzp;
        wire [2:0] rd;
        wire [1:0] hazard;
        wire should_stall;
        wire should_flush;

        wire[15:0] D_insn_in, D_insn_out, X_insn_in, X_insn_out, M_insn_in, M_insn_out, W_insn_in, W_insn_out, X_insn_sext, alu_result;
        wire[15:0] rsdata, X_A_out, rtdata, X_B_out, M_O_out, M_B_out, W_O_out, W_D_in, W_D_out, rddata;
        wire [15:0] i_alu_r1data, i_alu_r2data; //inputs to ALU 
        wire[1:0] A_bypass_sel, B_bypass_sel; //assigned by bypass logic module
        wire rddata_MB_sel, SX_B_sel; //assigned by bypass logic module

        wire[2:0] F_rs, F_rt, F_rd;
        wire[2:0] D_rs, D_rt, D_rd;
        wire[2:0] X_rs, X_rt, X_rd;
        wire[2:0] M_rs, M_rt, M_rd;
        wire[2:0] W_rs, W_rt, W_rd;

        wire F_rs_re, F_rt_re, F_regfile_we, F_nzp_we, F_select_pc_plus_one, F_is_load, F_is_store, F_is_branch, F_is_control_insn;
        wire D_rs_re, D_rt_re, D_regfile_we, D_nzp_we, D_select_pc_plus_one, D_is_load, D_is_store, D_is_branch, D_is_control_insn;
        wire X_rs_re, X_rt_re, X_regfile_we, X_nzp_we, X_select_pc_plus_one, X_is_load, X_is_store, X_is_branch, X_is_control_insn;
        wire M_rs_re, M_rt_re, M_regfile_we, M_nzp_we, M_select_pc_plus_one, M_is_load, M_is_store, M_is_branch, M_is_control_insn;
        wire W_rs_re, W_rt_re, W_regfile_we, W_nzp_we, W_select_pc_plus_one, W_is_load, W_is_store, W_is_branch, W_is_control_insn;
        //rsre (8), rtre (7), regfilewe (6), nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)

        wire [8:0] F_bus, D_bus, X_bus, M_bus, W_bus;

        assign F_rs_re =              F_bus[8];
        assign F_rt_re =              F_bus[7];
        assign F_regfile_we =         F_bus[6];
        assign F_nzp_we =             F_bus[5];
        assign F_select_pc_plus_one = F_bus[4];
        assign F_is_load =            F_bus[3];
        assign F_is_store =           F_bus[2];
        assign F_is_branch =          F_bus[1];
        assign F_is_control_insn =    F_bus[0];

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

        // pc wires attached to the PC register's ports
        wire [15:0] F_pc, F_pc_plus_one, D_pc, X_pc, X_pc_plus_one, next_pc; //defaults to pc+1

        wire[15:0] F_data, D_data, X_data, M_data, W_data;
   
        wire[1:0] dd_stall, xx_stall, mm_stall, ww_stall;

        // Program counter register, starts at 8200h at bootup
        Nbit_reg #(16, 16'h8200) F_pc_reg (.in(next_pc), .out(F_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst || ww_stall == 2'b10));
        Nbit_reg #(16, 16'b0)    D_pc_reg (.in(F_pc), .out(D_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
        Nbit_reg #(16, 16'b0)    X_pc_reg (.in(D_pc), .out(X_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));

        cla16 f_pc_plus_one(.a(F_pc), .b(16'b0), .cin(1'b1), .sum(F_pc_plus_one)); //assume the next instruction for the current decoded insn is pc + 1

        cla16 x_pc_plus_one(.a(X_pc), .b(16'b0), .cin(1'b1), .sum(X_pc_plus_one)); //assume the next instruction for the current decoded insn is X_pc + 1
        
        wire is_load_to_use = X_is_load && (D_rs == D_rd || (~D_is_store && D_rt == D_rd));	
	wire superscalar = 1'b0;
	wire flush = (X_is_branch && ~(X_pc_plus_one == alu_result)); //case in which we flush
	assign hazard = is_load_to_use ? 2'b11 : (superscalar ? 2'b01 : (flush ? 2'b10 : 2'b00));


        assign A_bypass_sel = M_rd == X_rs ? 2'b10 : (W_rd == X_rs ? 2'b01 : 2'b00);
        assign B_bypass_sel = M_rd == X_rt ? 2'b10 : (W_rd == X_rt ? 2'b01 : 2'b00);
        assign rddata_MB_sel = (W_is_load && M_is_store) && (W_rd == M_rt);
        assign SX_B_sel = 1'b0;

        assign should_flush = hazard == 2'b10;
        assign should_stall = xx_stall;

        assign D_insn_in = should_stall ? D_insn_out : i_cur_insn;
        assign X_insn_in = should_stall ? 16'b0  : D_insn_out; //if data_hazard module returns 2'b11 then we pass nop to execute in order to stall

        Nbit_reg #(16, 16'b0) D_insn_reg(.in(D_insn_in),  .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst),                 .out(D_insn_out));
        Nbit_reg #(16, 16'b0) X_insn_reg(.in(X_insn_in),  .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), .out(X_insn_out));
        Nbit_reg #(16, 16'b0) M_insn_reg(.in(X_insn_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), .out(M_insn_out));
        Nbit_reg #(16, 16'b0) W_insn_reg(.in(M_insn_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst),                 .out(W_insn_out));

        Nbit_reg #(3) nzpreg(.in(nzp_in), .out(nzp), .clk(clk), .we(X_nzp_we), .gwe(gwe), .rst(rst)); //TODO - is we correct?
        
        lc4_decoder dec(.insn(D_insn_in), 
                        .r1sel(F_rs), .r1re(F_bus[8]),
                        .r2sel(F_rt), .r2re(F_bus[7]), 
                        .wsel(F_rd), .regfile_we(F_bus[6]),
                        .nzp_we(F_bus[5]), .select_pc_plus_one(F_bus[4]), 
                        .is_load(F_bus[3]), .is_store(F_bus[2]), 
                        .is_branch(F_bus[1]), .is_control_insn(F_bus[0]));

        Nbit_reg #(3, 3'b0) D_rs_reg(.in(F_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                     .out(D_rs));
        Nbit_reg #(3, 3'b0) X_rs_reg(.in(D_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                     .out(X_rs));
        Nbit_reg #(3, 3'b0) M_rs_reg(.in(X_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), 
                                     .out(M_rs));
        Nbit_reg #(3, 3'b0) W_rs_reg(.in(M_rs), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), 
                                     .out(W_rs));

        Nbit_reg #(3, 3'b0) D_rt_reg(.in(F_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                     .out(D_rt));
        Nbit_reg #(3, 3'b0) X_rt_reg(.in(D_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                     .out(X_rt));
        Nbit_reg #(3, 3'b0) M_rt_reg(.in(X_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), 
                                     .out(M_rt));
        Nbit_reg #(3, 3'b0) W_rt_reg(.in(M_rt), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), 
                                     .out(W_rt));
        
        Nbit_reg #(3, 3'b0) D_rd_reg(.in(F_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                     .out(D_rd));
        Nbit_reg #(3, 3'b0) X_rd_reg(.in(D_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                     .out(X_rd));
        Nbit_reg #(3, 3'b0) M_rd_reg(.in(X_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst),                 
                                     .out(M_rd));
        Nbit_reg #(3, 3'b0) W_rd_reg(.in(M_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst),                 
                                     .out(W_rd));

        //REGISTER FILE
        lc4_regfile registerfile(.clk(clk), .gwe(gwe), .rst(rst),
                                 .i_rs(W_rs),        .i_rt(W_rt),        .i_rd(rd),
                                 .o_rs_data(rsdata), .o_rt_data(rtdata), .i_wdata(rddata), .i_rd_we(W_regfile_we));  

        Nbit_reg #(16, 16'b0) X_A_reg(.in(rsdata), .clk(clk), .we(X_rs_re), .gwe(gwe), .rst(should_flush || rst), .out(X_A_out)); //Holds rsdata that comes out of register file
        Nbit_reg #(16, 16'b0) M_O_reg(.in(alu_result), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), .out(M_O_out)); //Holds dmem data
        Nbit_reg #(16, 16'b0) W_O_register(.in(M_O_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(W_O_out));
        
        Nbit_reg #(16, 16'b0) X_B_reg(.in(rtdata), .clk(clk), .we(X_rt_re), .gwe(gwe), .rst(should_flush || rst), .out(X_B_out)); //Holds rtdata that comes out of register file
        Nbit_reg #(16, 16'b0) M_B_reg(.in(i_alu_r2data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), .out(M_B_out)); //Holds dmem address
        Nbit_reg #(16, 16'b0) W_D_register(.in(M_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(W_D_out));

        //A_bypass_sel values: 0 -> MX bypass, 1 -> WX bypass, otherwise no bypass (comes straight from X_A_reg)
        //B_bypass_sel values: 0 -> MX bypass, 1 -> WX bypass, otherwise no bypass (comes straight from X_B_reg)
        assign i_alu_r1data = A_bypass_sel == 2'b00 ? M_O_out : (A_bypass_sel == 2'b01 ? rddata : X_A_out);
        assign i_alu_r2data = B_bypass_sel == 2'b00 ? M_O_out : (B_bypass_sel == 2'b01 ? rddata : X_B_out);
        lc4_alu alu (.i_insn(X_insn_out), .i_pc(X_pc), .i_r1data(i_alu_r1data), .i_r2data(i_alu_r2data), .o_result(alu_result)); //ALU

        Nbit_reg #(9, 9'b0) D_bus_reg(.in(F_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst),
                                      .out(D_bus));
        Nbit_reg #(9, 9'b0) X_bus_reg(.in(D_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                      .out(X_bus));
        Nbit_reg #(9, 9'b0) M_bus_reg(.in(X_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst), 
                                      .out(M_bus));
        Nbit_reg #(9, 9'b0) W_bus_reg(.in(M_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst),             
                                      .out(W_bus));

        Nbit_reg #(16, 16'b0) F_data_reg(.in(i_cur_dmem_data), .out(F_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
        Nbit_reg #(16, 16'b0) D_data_reg(.in(F_data),          .out(D_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
        Nbit_reg #(16, 16'b0) X_data_reg(.in(D_data),          .out(X_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
        Nbit_reg #(16, 16'b0) M_data_reg(.in(X_data),          .out(M_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || rst));
        Nbit_reg #(16, 16'b0) W_data_reg(.in(M_data),          .out(W_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

        Nbit_reg #(2, 2'b10) D_stall(.in(hazard),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(dd_stall));
        Nbit_reg #(2, 2'b10) X_stall(.in(dd_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(xx_stall));
        Nbit_reg #(2, 2'b10) M_stall(.in(xx_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(mm_stall));
        Nbit_reg #(2, 2'b10) W_stall(.in(mm_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(ww_stall));

   
   //BEGIN WRITE STAGE

   
        assign nzp_in[2] = rddata[15];
        assign nzp_in[1] = &(~rddata);
        assign nzp_in[0] = ~rddata[15] && (|rddata);

        assign rddata = W_is_load ? W_D_out : W_O_out; //where WO_WD_sel is found based on bypass control logic
        assign rd = W_rd; //TODO - this is most likely incorrect
        assign next_pc = F_pc_plus_one; //assume the next pc is pc+1
   

   //END WRITE STAGE
   
   //PIPELINE ENDS HERE


   //SET OUTPUTS
   assign o_dmem_we = M_is_store; //if store instruction is in M stage is the only time we write to memory;          // Data memory write enable
   assign o_dmem_addr = M_is_store || M_is_load ? M_O_out : 16'b0;        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
   assign o_dmem_towrite = (W_is_load && M_is_store) && (W_rd == M_rt) ? M_B_out : rddata; 
   assign o_cur_pc = should_flush ? alu_result : F_pc;

   //SET TESTING PINS - 
   //for reference rsre (8), rtre (7), regfilewe (6),
   //nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)
   //rs in [2:0], rt in [5:3], rd in [8:6]
   assign test_regfile_we = W_regfile_we;    // Testbench: register file write enable
   assign test_regfile_wsel = W_rd;  // Testbench: which register to write in the register file
   assign test_regfile_data = rddata;  // Testbench: value to write into the register file
   assign test_nzp_we = W_nzp_we;     // Testbench: NZP condition codes write enable
   assign test_nzp_new_bits = nzp_in;  // Testbench: value to write to NZP bits
   assign test_dmem_we = o_dmem_we;       // Testbench: data memory write enable
   assign test_dmem_addr = o_dmem_addr;     // Testbench: address to read/write memory
   assign test_dmem_data = o_dmem_towrite;     // Testbench: value read/writen from/to memory 
   assign test_stall = ww_stall; // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
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
      $display("%d CURR_PC=%h, D_INSN=%h X_INSN=%h, M_INSN=%h, W_INSN=%h", $time, F_pc, D_insn_out, X_insn_out, M_insn_out, W_insn_out);

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