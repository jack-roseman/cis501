`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );

   /***  YOUR CODE HERE ***/

   // By default, assign LEDs to display switch inputs to avoid warnings about
      // disconnected ports. Feel free to use this for debugging input/output if
      // you desire.
      assign led_data = switch_data;
      wire superscalar = 1'b0;
      wire should_flush_B, should_stall_B;
      wire [1:0] X_stall_B, M_stall_B, W_stall_B, stall_out_B;
      wire [2:0] nzp_in_B, nzp_B, rd_B, nzp_out_B, W_nzp_B;
      wire [15:0] D_insn_B, X_insn_in_B, X_insn_B, M_insn_in_B, M_insn_B, W_insn_B, insn_out_B, alu_result_B;
      wire [15:0] rsdata_B, rtdata_B, rddata_B, X_A_B, X_B_B, M_A_B, M_B_B, W_alu_result_B, W_D_B, alu_result_out_B, regfile_rsdata_out_B, regfile_rtdata_out_B;
      wire [15:0] i_alu_r1data_B, i_alu_r2data_B; //inputs to ALU 
      wire [2:0] D_rs_B, D_rt_B, D_rd_B;
      wire [2:0] X_rs_B, X_rt_B, X_rd_B;
      wire [2:0] M_rs_B, M_rt_B, M_rd_B;
      wire [2:0] W_rs_B, W_rt_B, W_rd_B;
      wire D_rs_re_B, D_rt_re_B, D_regfile_we_B, D_nzp_we_B, D_select_pc_plus_one_B, D_is_load_B, D_is_store_B, D_is_branch_B, D_is_control_insn_B;
      wire X_rs_re_B, X_rt_re_B, X_regfile_we_B, X_nzp_we_B, X_select_pc_plus_one_B, X_is_load_B, X_is_store_B, X_is_branch_B, X_is_control_insn_B;
      wire M_rs_re_B, M_rt_re_B, M_regfile_we_B, M_nzp_we_B, M_select_pc_plus_one_B, M_is_load_B, M_is_store_B, M_is_branch_B, M_is_control_insn_B;
      wire W_rs_re_B, W_rt_re_B, W_regfile_we_B, W_nzp_we_B, W_select_pc_plus_one_B, W_is_load_B, W_is_store_B, W_is_branch_B, W_is_control_insn_B;
      wire rs_re_B, rt_re_B, regfile_we_B, nzp_we_B, select_pc_plus_one_B, is_load_B, is_store_B, is_branch_B, is_control_insn_B;
      wire [8:0] D_rs_rt_rd_B, X_rs_rt_rd_B, M_rs_rt_rd_B, W_rs_rt_rd_B, rs_rt_rd_out_B;
      wire [15:0] M_dmem_data_B, M_dmem_addr_B, W_dmem_data_B, W_dmem_addr_B, dmem_data_out_B, dmem_addr_out_B; 
      wire [8:0] D_bus_B, X_bus_B, M_bus_B, W_bus_B, bus_out_B;
      wire [15:0] pc_B, pc_plus_one, D_pc_B, X_pc_B, M_pc_B, W_pc_B, pc_out_B, next_pc, M_pc_plus_one_B;
 
      //rsre (8), rtre (7), regfilewe (6), nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)
      assign X_rs_B =                 X_rs_rt_rd_B[8:6];
      assign X_rt_B =                 X_rs_rt_rd_B[5:3];
      assign X_rd_B =                 X_rs_rt_rd_B[2:0];

      assign M_rs_B =                 M_rs_rt_rd_B[8:6];
      assign M_rt_B =                 M_rs_rt_rd_B[5:3];
      assign M_rd_B =                 M_rs_rt_rd_B[2:0];

      assign W_rs_B =                 W_rs_rt_rd_B[8:6];
      assign W_rt_B =                 W_rs_rt_rd_B[5:3];
      assign W_rd_B =                 W_rs_rt_rd_B[2:0];

      assign X_rs_re_B =              X_bus_B[8];
      assign X_rt_re_B =              X_bus_B[7];
      assign X_regfile_we_B =         X_bus_B[6];
      assign X_nzp_we_B =             X_bus_B[5];
      assign X_select_pc_plus_one_B = X_bus_B[4];
      assign X_is_load_B =            X_bus_B[3];
      assign X_is_store_B =           X_bus_B[2];
      assign X_is_branch_B =          X_bus_B[1];
      assign X_is_control_insn_B =    X_bus_B[0];

      assign M_rs_re_B =              M_bus_B[8];
      assign M_rt_re_B =              M_bus_B[7];
      assign M_regfile_we_B =         M_bus_B[6];
      assign M_nzp_we_B =             M_bus_B[5];
      assign M_select_pc_plus_one_B = M_bus_B[4];
      assign M_is_load_B =            M_bus_B[3];
      assign M_is_store_B =           M_bus_B[2];
      assign M_is_branch_B =          M_bus_B[1];
      assign M_is_control_insn_B =    M_bus_B[0];

      assign W_rs_re_B =              W_bus_B[8];
      assign W_rt_re_B =              W_bus_B[7];
      assign W_regfile_we_B =         W_bus_B[6];
      assign W_nzp_we_B =             W_bus_B[5];
      assign W_select_pc_plus_one_B = W_bus_B[4];
      assign W_is_load_B =            W_bus_B[3];
      assign W_is_store_B =           W_bus_B[2];
      assign W_is_branch_B =          W_bus_B[1];
      assign W_is_control_insn_B =    W_bus_B[0];

      assign rs_re_B =                bus_out_B[8];
      assign rt_re_B =                bus_out_B[7];
      assign regfile_we_B =           bus_out_B[6];
      assign nzp_we_B =               bus_out_B[5];
      assign select_pc_plus_one_B  =  bus_out_B[4];
      assign is_load_B =              bus_out_B[3];
      assign is_store_B =             bus_out_B[2];
      assign is_branch_B =            bus_out_B[1];
      assign is_control_insn_B =      bus_out_B[0];


      Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1),   .gwe(gwe), .rst(rst));

      cla16 add_one(.a(pc), .b(16'b0), .cin(1'b1), .sum(pc_plus_one)); //assume the next instruction for the current decoded insn is pc + 1
      
      Nbit_reg #(16, 16'b0)       DX_pc_reg(.in(pc),         .out(X_pc_B),       .clk(clk), .we(~should_stall_B), .gwe(gwe), .rst(should_flush_B || rst));
      Nbit_reg #(16, 16'b0)     DX_insn_reg(.in(i_cur_insn), .out(X_insn_B),     .clk(clk), .we(~should_stall_B), .gwe(gwe), .rst(should_flush_B || rst));
      
      lc4_decoder dec(  .insn(X_insn_B),
                        .r1sel(X_rs_rt_rd_B[8:6]), .r1re(X_bus_B[8]),
                        .r2sel(X_rs_rt_rd_B[5:3]), .r2re(X_bus_B[7]), 
                        .wsel (X_rs_rt_rd_B[2:0]), .regfile_we(X_bus_B[6]),
                        .nzp_we(X_bus_B[5]),       .select_pc_plus_one(X_bus_B[4]), 
                        .is_load(X_bus_B[3]),      .is_store(X_bus_B[2]), 
                        .is_branch(X_bus_B[1]),    .is_control_insn(X_bus_B[0]));

      lc4_regfile_ss registerfile(  .i_rs_A(X_rs_A),                      .i_rt_A(X_rt_A),                    .i_rd_A(rd_A),
                                    .i_rs_B(X_rs_B),                      .i_rt_B(X_rt_B),                    .i_rd_B(rd_B),
                                    .o_rs_data_A(regfile_rsdata_out_A),   .o_rt_data_A(regfile_rtdata_out_A), .i_wdata_A(rddata_A), .i_rd_we_A(regfile_we_A),
                                    .o_rs_data_B(regfile_rsdata_out_B),   .o_rt_data_B(regfile_rtdata_out_B), .i_wdata_A(rddata_B), .i_rd_we_B(regfile_we_B),
                                    .clk(clk), .gwe(gwe), .rst(rst)); 
                        
      Nbit_reg #(16, 16'b0)     XM_pc_regB(.in(X_pc_B),       .out(M_pc_B),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall_B || rst));
      Nbit_reg #(16, 16'b0)   XM_insn_regB(.in(X_insn_B),     .out(M_insn_B),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall_B || rst));
      Nbit_reg #(9, 9'b0) XM_rs_rt_rd_regB(.in(X_rs_rt_rd_B), .out(M_rs_rt_rd_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));
      Nbit_reg #(9, 9'b0)      XM_bus_regB(.in(X_bus_B),      .out(M_bus_B),      .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));
      Nbit_reg #(16, 16'b0)      XM_A_regB(.in(rsdata_B),     .out(M_A_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst)); 
      Nbit_reg #(16, 16'b0)      XM_B_regB(.in(rtdata_B),     .out(M_B_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));
     
      lc4_alu alu (.i_insn(M_insn_B), .i_pc(M_pc_B), .i_r1data(i_alu_r1data_B), .i_r2data(i_alu_r2data_B), .o_result(alu_result_B)); //ALU

      Nbit_reg #(16, 16'b0)     MW_pc_regB(.in(M_pc_B),         .out(W_pc_B),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   MW_insn_regB(.in(M_insn_B),       .out(W_insn_B),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) MW_rs_rt_rd_regB(.in(M_rs_rt_rd_B),   .out(W_rs_rt_rd_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      MW_O_regB(.in(alu_result_B),   .out(W_alu_result_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data
      Nbit_reg #(9, 9'b0)      MW_bus_regB(.in(M_bus_B),        .out(W_bus_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(16, 16'b0)     WD_pc_regB(.in(W_pc_B),         .out(pc_out_B),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   WD_insn_regB(.in(W_insn_B),       .out(insn_out_B),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) WD_rs_rt_rd_regB(.in(W_rs_rt_rd_B),   .out(rs_rt_rd_out_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      WD_O_regB(.in(W_alu_result_B), .out(alu_result_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(9, 9'b0)      WD_bus_regB(.in(W_bus_B),        .out(bus_out_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(3, 3'b0) M_nzp_reg_B(.in(nzp_in_B),  .out(W_nzp_B),  .clk(clk), .we(M_nzp_we_B), .gwe(gwe), .rst(rst));
	   Nbit_reg #(3, 3'b0) W_nzp_reg_B(.in(W_nzp_B),   .out(nzp_B),    .clk(clk), .we(W_nzp_we_B), .gwe(gwe), .rst(rst));

      assign M_dmem_addr_B = M_is_store_B || M_is_load_B ? alu_result_B : 16'b0;
      Nbit_reg #(16, 16'b0) MW_dmem_addr_regB(.in(M_dmem_addr_B), .out(W_dmem_addr_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(16, 16'b0) WD_dmem_addr_regB(.in(W_dmem_addr_B), .out(dmem_addr_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address

      wire is_load_to_store_B = W_is_load_B && M_is_store_B && W_rd_B == M_rt_B;
      assign M_dmem_data_B = is_load_to_store_B ? W_dmem_data_B : (M_is_load_B ? i_cur_dmem_data : (M_is_store_B ? i_alu_r2data_B: 16'b0));
      Nbit_reg #(16, 16'b0) MW_dmem_data_regB(.in(M_dmem_data_B), .out(W_dmem_data_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0) WD_dmem_data_regB(.in(W_dmem_data_B), .out(dmem_data_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data
   
      wire is_load_to_use_B = (M_is_load_B && M_rd_B == X_rs_B && X_rs_re_B) || (M_is_load_B && ~X_is_store_B && ~X_is_load_B && M_rd_B == X_rt_B && X_rt_re_B);
      assign should_stall_B = is_load_to_use_B || (M_is_load_B && X_is_branch_B);
      assign should_flush_B = (M_is_branch_B && |(M_insn_B[11:9] & W_nzp_B)) || M_is_control_insn_B;

      assign rsdata_B = W_regfile_we_B && (W_rd_B == X_rs_B) ? W_dmem_data_B : regfile_rsdata_out_B;
      assign rtdata_B = W_regfile_we_B && (W_rd_B == X_rt_B) ? W_dmem_addr_B : regfile_rtdata_out_B;

      assign i_alu_r1data_B = W_regfile_we_B && (W_rd_B == M_rs_B) ? W_alu_result_B : (regfile_we_B && (rd_B == M_rs_B) ? rddata_B : M_A_B);
      assign i_alu_r2data_B = W_regfile_we_B && (W_rd_B == M_rt_B) ? W_alu_result_B : (regfile_we_B && (rd_B == M_rt_B) ? rddata_B : M_B_B);

      wire [15:0] nzp_data_B = M_is_control_insn_B ? X_pc_B : (M_is_load_B ? M_dmem_data_B : alu_result_B);
      assign nzp_in_B[2] = nzp_data_B[15];
      assign nzp_in_B[1] = &(~nzp_data_B);
      assign nzp_in_B[0] = ~nzp_data_B[15] && (|nzp_data_B);

      assign rd_B        = rs_rt_rd_out_B[2:0];
      assign rddata_B    = is_control_insn_B ? W_pc_B : (is_load_B ? dmem_data_out_B : alu_result_out_B);

      assign next_pc = should_flush_B ? alu_result_B : (should_stall_B ? pc_B : pc_plus_one_B); //assume the next pc is pc+1

      
      
      
      //SET OUTPUTS
      assign o_dmem_we = M_is_store_B;  // Data memory write enable
      assign o_dmem_addr = M_dmem_addr_B;        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
      assign o_dmem_towrite = M_dmem_data_B;
      assign o_cur_pc = pc;
      


      //SET TESTING PINS - 
      assign test_regfile_we_B   = regfile_we_B;    // Testbench: register file write enable
      assign test_regfile_wsel_B = rd_B;  // Testbench: which register to write in the register file
      assign test_regfile_data_B = rddata_B;  // Testbench: value to write into the register file
      assign test_nzp_we_B       = nzp_we_B;     // Testbench: NZP condition codes write enable
      assign test_nzp_new_bits_B = nzp_B;  // Testbench: value to write to NZP bits
      assign test_dmem_we_B      = is_store_B;       // Testbench: data memory write enable
      assign test_dmem_addr_B    = dmem_addr_out_B;     // Testbench: address to read/write memory
      assign test_dmem_data_B    = dmem_data_out_B;     // Testbench: value read/writen from/to memory 
      assign test_stall_B        = stall_out_B; // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
      assign test_cur_pc_B       = pc_out_B; 
      assign test_cur_insn_B     = insn_out_B; 

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





   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
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
      // run it for that many nanoseconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
endmodule
