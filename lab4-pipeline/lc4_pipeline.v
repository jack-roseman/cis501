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
      wire should_flush, should_stall, is_WD_bypass;
      wire [1:0] hazard, D_stall, X_stall, M_stall, W_stall, stall_out;
      wire [2:0] nzp_in, nzp, rd, nzp_out, W_nzp;
      wire [15:0] D_insn, X_insn_in, X_insn, M_insn_in, M_insn, W_insn, insn_out, alu_result;
      wire [15:0] rsdata, rtdata, rddata, X_A, X_B, M_A, M_B, W_alu_result, W_D, alu_result_out, regfile_rsdata_out, regfile_rtdata_out;
      wire [15:0] i_alu_r1data, i_alu_r2data; //inputs to ALU 
      wire [2:0] D_rs, D_rt, D_rd;
      wire [2:0] X_rs, X_rt, X_rd;
      wire [2:0] M_rs, M_rt, M_rd;
      wire [2:0] W_rs, W_rt, W_rd;
      wire D_rs_re, D_rt_re, D_regfile_we, D_nzp_we, D_select_pc_plus_one, D_is_load, D_is_store, D_is_branch, D_is_control_insn;
      wire X_rs_re, X_rt_re, X_regfile_we, X_nzp_we, X_select_pc_plus_one, X_is_load, X_is_store, X_is_branch, X_is_control_insn;
      wire M_rs_re, M_rt_re, M_regfile_we, M_nzp_we, M_select_pc_plus_one, M_is_load, M_is_store, M_is_branch, M_is_control_insn;
      wire W_rs_re, W_rt_re, W_regfile_we, W_nzp_we, W_select_pc_plus_one, W_is_load, W_is_store, W_is_branch, W_is_control_insn;
      wire rs_re, rt_re, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
      wire [8:0] D_rs_rt_rd, X_rs_rt_rd, M_rs_rt_rd, W_rs_rt_rd, rs_rt_rd_out;
      wire [15:0] M_dmem_data, M_dmem_addr, W_dmem_data, W_dmem_addr, dmem_data_out, dmem_addr_out; 
      wire [8:0] D_bus, X_bus, M_bus, W_bus, bus_out;
      wire [15:0] pc, pc_plus_one, D_pc, X_pc, M_pc, W_pc, pc_out, next_pc, M_pc_plus_one;
 
      //rsre (8), rtre (7), regfilewe (6), nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)
      assign X_rs =                 X_rs_rt_rd[8:6];
      assign X_rt =                 X_rs_rt_rd[5:3];
      assign X_rd =                 X_rs_rt_rd[2:0];

      assign M_rs =                 M_rs_rt_rd[8:6];
      assign M_rt =                 M_rs_rt_rd[5:3];
      assign M_rd =                 M_rs_rt_rd[2:0];

      assign W_rs =                 W_rs_rt_rd[8:6];
      assign W_rt =                 W_rs_rt_rd[5:3];
      assign W_rd =                 W_rs_rt_rd[2:0];

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

      assign rs_re =                bus_out[8];
      assign rt_re =                bus_out[7];
      assign regfile_we =           bus_out[6];
      assign nzp_we =               bus_out[5];
      assign select_pc_plus_one  =  bus_out[4];
      assign is_load =              bus_out[3];
      assign is_store =             bus_out[2];
      assign is_branch =            bus_out[1];
      assign is_control_insn =      bus_out[0];

      wire [1:0] stall_in = should_flush ? 2'b10 : 2'b00;
      Nbit_reg #(2, 2'b10)   FD_stall_reg(.in(stall_in),     .out(X_stall),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      wire [1:0] stall_x = X_stall == 2'b10 ? 2'b10 : (should_stall ? 2'b11 : (should_flush ? 2'b10 : 2'b00));
      Nbit_reg #(2, 2'b10)   DX_stall_reg(.in(stall_x),     .out(M_stall),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   XM_stall_reg(.in(M_stall),      .out(W_stall),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   MW_stall_reg(.in(W_stall),     .out(stall_out),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1),   .gwe(gwe), .rst(rst));

      cla16 add_one(.a(pc), .b(16'b0), .cin(1'b1), .sum(pc_plus_one)); //assume the next instruction for the current decoded insn is pc + 1
      
      Nbit_reg #(16, 16'b0)       DX_pc_reg(.in(pc),         .out(X_pc),       .clk(clk), .we(~should_stall), .gwe(gwe), .rst(should_flush || rst));
      Nbit_reg #(16, 16'b0)     DX_insn_reg(.in(i_cur_insn), .out(X_insn),     .clk(clk), .we(~should_stall), .gwe(gwe), .rst(should_flush || rst));
      
      lc4_decoder dec(  .insn(X_insn),
                        .r1sel(X_rs_rt_rd[8:6]), .r1re(X_bus[8]),
                        .r2sel(X_rs_rt_rd[5:3]), .r2re(X_bus[7]), 
                        .wsel (X_rs_rt_rd[2:0]), .regfile_we(X_bus[6]),
                        .nzp_we(X_bus[5]),       .select_pc_plus_one(X_bus[4]), 
                        .is_load(X_bus[3]),      .is_store(X_bus[2]), 
                        .is_branch(X_bus[1]),    .is_control_insn(X_bus[0]));

      lc4_regfile registerfile(  .i_rs(X_rs),                      .i_rt(X_rt),                    .i_rd(rd),
                                 .o_rs_data(regfile_rsdata_out),   .o_rt_data(regfile_rtdata_out), .i_wdata(rddata), .i_rd_we(regfile_we),
                                 .clk(clk), .gwe(gwe), .rst(rst)); 
                        
      Nbit_reg #(16, 16'b0)     XM_pc_reg(.in(X_pc),       .out(M_pc),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall || rst));
      Nbit_reg #(16, 16'b0)   XM_insn_reg(.in(X_insn),     .out(M_insn),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall || rst));
      Nbit_reg #(9, 9'b0) XM_rs_rt_rd_reg(.in(X_rs_rt_rd), .out(M_rs_rt_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || should_stall || rst));
      Nbit_reg #(9, 9'b0)      XM_bus_reg(.in(X_bus),      .out(M_bus),      .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || should_stall || rst));
      Nbit_reg #(16, 16'b0)      XM_A_reg(.in(rsdata),     .out(M_A),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || should_stall || rst)); 
      Nbit_reg #(16, 16'b0)      XM_B_reg(.in(rtdata),     .out(M_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush || should_stall || rst));
     
      lc4_alu alu (.i_insn(M_insn), .i_pc(M_pc), .i_r1data(i_alu_r1data), .i_r2data(i_alu_r2data), .o_result(alu_result)); //ALU

      Nbit_reg #(16, 16'b0)     MW_pc_reg(.in(M_pc),         .out(W_pc),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   MW_insn_reg(.in(M_insn),       .out(W_insn),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) MW_rs_rt_rd_reg(.in(M_rs_rt_rd),   .out(W_rs_rt_rd),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      MW_O_reg(.in(alu_result),   .out(W_alu_result), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data
      Nbit_reg #(9, 9'b0)      MW_bus_reg(.in(M_bus),        .out(W_bus),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(16, 16'b0)     WD_pc_reg(.in(W_pc),         .out(pc_out),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   WD_insn_reg(.in(W_insn),       .out(insn_out),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) WD_rs_rt_rd_reg(.in(W_rs_rt_rd),   .out(rs_rt_rd_out),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      WD_O_reg(.in(W_alu_result), .out(alu_result_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(9, 9'b0)      WD_bus_reg(.in(W_bus),        .out(bus_out),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(3, 3'b0) M_nzp_reg(.in(nzp_in),  .out(W_nzp),  .clk(clk), .we(M_nzp_we), .gwe(gwe), .rst(rst));
	   Nbit_reg #(3, 3'b0) W_nzp_reg(.in(W_nzp),   .out(nzp),    .clk(clk), .we(W_nzp_we), .gwe(gwe), .rst(rst));

      assign M_dmem_addr = M_is_store || M_is_load ? alu_result : 16'b0;
      Nbit_reg #(16, 16'b0) MW_dmem_addr_reg(.in(M_dmem_addr), .out(W_dmem_addr),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(16, 16'b0) WD_dmem_addr_reg(.in(W_dmem_addr), .out(dmem_addr_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address

      wire is_load_to_store = W_is_load && M_is_store && W_rd == M_rt;
      assign M_dmem_data = is_load_to_store ? W_dmem_data : (M_is_load ? i_cur_dmem_data : (M_is_store ? i_alu_r2data: 16'b0));
      Nbit_reg #(16, 16'b0) MW_dmem_data_reg(.in(M_dmem_data), .out(W_dmem_data),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0) WD_dmem_data_reg(.in(W_dmem_data), .out(dmem_data_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data

      wire is_load_to_use = (M_is_load && M_rd == X_rs && X_rs_re) || (M_is_load && ~X_is_store && ~X_is_load && M_rd == X_rt && X_rt_re);
      assign should_stall = is_load_to_use || (M_is_load && X_is_branch);
      assign should_flush = (M_is_branch && |(M_insn[11:9] & W_nzp)) || M_is_control_insn;

      assign rsdata = W_regfile_we && (W_rd == X_rs) ? W_dmem_data :  (regfile_we && (rd == X_rs) ? rddata : regfile_rsdata_out);
      assign rtdata = W_regfile_we && (W_rd == X_rt) ? W_dmem_addr : (regfile_we && (rd == X_rt) ? rddata : regfile_rtdata_out);

      assign i_alu_r1data = W_regfile_we && (W_rd == M_rs) ? W_alu_result : (regfile_we && (rd == M_rs) ? rddata : M_A);
      assign i_alu_r2data = W_regfile_we && (W_rd == M_rt) ? W_alu_result : (regfile_we && (rd == M_rt) ? rddata : M_B);

      wire [15:0] nzp_data = M_is_load ? M_dmem_data : alu_result;
      assign nzp_in[2] = nzp_data[15];
      assign nzp_in[1] = &(~nzp_data);
      assign nzp_in[0] = ~nzp_data[15] && (|nzp_data);

      assign rd        = rs_rt_rd_out[2:0];
      assign rddata    = is_control_insn ? W_pc : (is_load ? dmem_data_out : alu_result_out);

      assign next_pc = should_flush ? alu_result : (should_stall ? pc : pc_plus_one); //assume the next pc is pc+1
      
      //SET OUTPUTS
      assign o_dmem_we = M_is_store;  // Data memory write enable
      assign o_dmem_addr = M_dmem_addr;        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
      assign o_dmem_towrite = M_dmem_data;
      assign o_cur_pc = pc;
      
      //SET TESTING PINS - 
      assign test_regfile_we   = regfile_we;    // Testbench: register file write enable
      assign test_regfile_wsel = rd;  // Testbench: which register to write in the register file
      assign test_regfile_data = rddata;  // Testbench: value to write into the register file
      assign test_nzp_we       = nzp_we;     // Testbench: NZP condition codes write enable
      assign test_nzp_new_bits = nzp;  // Testbench: value to write to NZP bits
      assign test_dmem_we      = is_store;       // Testbench: data memory write enable
      assign test_dmem_addr    = dmem_addr_out;     // Testbench: address to read/write memory
      assign test_dmem_data    = dmem_data_out;     // Testbench: value read/writen from/to memory 
      assign test_stall        = stall_out; // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
      assign test_cur_pc       = pc_out; 
      assign test_cur_insn     = insn_out; 

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
      $display("%d CURR_PC=%h, D_INSN=%h X_INSN=%h, M_INSN=%h, W_INSN=%h, INSN-%h", $time, pc_out, i_cur_insn, X_insn, M_insn, W_insn, insn_out);

      if(W_is_load)
         $display("%d LOAD R%d <= %h from ADDR: %h ", $time, W_rd, W_dmem_data, W_dmem_addr);

         
      if (W_is_store)
        $display("%d STORE %h <= %h", $time, W_dmem_addr, W_dmem_data);


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
