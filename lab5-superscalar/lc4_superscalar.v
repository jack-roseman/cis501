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
      wire superscalar_stall;
      wire should_flush_A, should_stall_A;
      wire should_flush_B, should_stall_B;

      wire [1:0] X_stall_A, M_stall_A, W_stall_A, stall_out_A;
      wire [1:0] X_stall_B, M_stall_B, W_stall_B, stall_out_B;

      wire [2:0] nzp_in_A, nzp_A, rd_A, nzp_out_A, W_nzp_A;
      wire [2:0] nzp_in_B, nzp_B, rd_B, nzp_out_B, W_nzp_B;
      
      wire [15:0] D_insn_A, X_insn_in_A, X_insn_A, M_insn_in_A, M_insn_A, W_insn_A, insn_out_A, alu_result_A, X_insn_A_tmp, D_insn_A_tmp;
      wire [15:0] D_insn_B, X_insn_in_B, X_insn_B, M_insn_in_B, M_insn_B, W_insn_B, insn_out_B, alu_result_B, X_insn_B_tmp, D_insn_B_tmp;

      wire [15:0] rsdata_A, rtdata_A, rddata_A, X_A_A, X_B_A, M_A_A, M_B_A, W_alu_result_A, W_D_A, alu_result_out_A, regfile_rsdata_out_A, regfile_rtdata_out_A;
      wire [15:0] rsdata_B, rtdata_B, rddata_B, X_A_B, X_B_B, M_A_B, M_B_B, W_alu_result_B, W_D_B, alu_result_out_B, regfile_rsdata_out_B, regfile_rtdata_out_B;

      wire [15:0] i_alu_r1data_A, i_alu_r2data_A; //inputs to ALU 
      wire [15:0] i_alu_r1data_B, i_alu_r2data_B; //inputs to ALU 

      wire [2:0] D_rs_A, D_rt_A, D_rd_A;
      wire [2:0] D_rs_B, D_rt_B, D_rd_B;

      wire [2:0] X_rs_A, X_rt_A, X_rd_A;
      wire [2:0] X_rs_B, X_rt_B, X_rd_B;

      wire [2:0] M_rs_A, M_rt_A, M_rd_A;
      wire [2:0] M_rs_B, M_rt_B, M_rd_B;

      wire [2:0] W_rs_A, W_rt_A, W_rd_A;
      wire [2:0] W_rs_B, W_rt_B, W_rd_B;

      wire D_rs_re_A, D_rt_re_A, D_regfile_we_A, D_nzp_we_A, D_select_pc_plus_one_A, D_is_load_A, D_is_store_A, D_is_branch_A, D_is_control_insn_A;
      wire D_rs_re_B, D_rt_re_B, D_regfile_we_B, D_nzp_we_B, D_select_pc_plus_one_B, D_is_load_B, D_is_store_B, D_is_branch_B, D_is_control_insn_B;

      wire X_rs_re_A, X_rt_re_A, X_regfile_we_A, X_nzp_we_A, X_select_pc_plus_one_A, X_is_load_A, X_is_store_A, X_is_branch_A, X_is_control_insn_A;
      wire X_rs_re_B, X_rt_re_B, X_regfile_we_B, X_nzp_we_B, X_select_pc_plus_one_B, X_is_load_B, X_is_store_B, X_is_branch_B, X_is_control_insn_B;

      wire M_rs_re_A, M_rt_re_A, M_regfile_we_A, M_nzp_we_A, M_select_pc_plus_one_A, M_is_load_A, M_is_store_A, M_is_branch_A, M_is_control_insn_A;
      wire M_rs_re_B, M_rt_re_B, M_regfile_we_B, M_nzp_we_B, M_select_pc_plus_one_B, M_is_load_B, M_is_store_B, M_is_branch_B, M_is_control_insn_B;

      wire W_rs_re_A, W_rt_re_A, W_regfile_we_A, W_nzp_we_A, W_select_pc_plus_one_A, W_is_load_A, W_is_store_A, W_is_branch_A, W_is_control_insn_A;
      wire W_rs_re_B, W_rt_re_B, W_regfile_we_B, W_nzp_we_B, W_select_pc_plus_one_B, W_is_load_B, W_is_store_B, W_is_branch_B, W_is_control_insn_B;

      wire rs_re_A, rt_re_A, regfile_we_A, nzp_we_A, select_pc_plus_one_A, is_load_A, is_store_A, is_branch_A, is_control_insn_A;
      wire rs_re_B, rt_re_B, regfile_we_B, nzp_we_B, select_pc_plus_one_B, is_load_B, is_store_B, is_branch_B, is_control_insn_B;

      wire [8:0] D_rs_rt_rd_A, X_rs_rt_rd_A, M_rs_rt_rd_A, W_rs_rt_rd_A, rs_rt_rd_out_A;
      wire [8:0] D_rs_rt_rd_B, X_rs_rt_rd_B, M_rs_rt_rd_B, W_rs_rt_rd_B, rs_rt_rd_out_B;

      wire [15:0] M_dmem_data_A, M_dmem_addr_A, W_dmem_data_A, W_dmem_addr_A, dmem_data_out_A, dmem_addr_out_A;
      wire [15:0] M_dmem_data_B, M_dmem_addr_B, W_dmem_data_B, W_dmem_addr_B, dmem_data_out_B, dmem_addr_out_B; 

      wire [8:0] D_bus_A, X_bus_A, M_bus_A, W_bus_A, bus_out_A;
      wire [8:0] D_bus_B, X_bus_B, M_bus_B, W_bus_B, bus_out_B;

      wire [15:0] pc_A, pc_plus_one_A, D_pc_A, X_pc_A, M_pc_A, W_pc_A, pc_out_A, next_pc_A, M_pc_plus_one_A, X_pc_A_tmp, pc_A_tmp, pc_plus_two_A;
      wire [15:0] pc_B, pc_plus_one_B, D_pc_B, X_pc_B, M_pc_B, W_pc_B, pc_out_B, next_pc_B, M_pc_plus_one_B, X_pc_B_tmp, pc_B_tmp, pc_plus_two_B;
 
      //rsre (8), rtre (7), regfilewe (6), nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)

      assign D_rs_A =                 D_rs_rt_rd_A[8:6];
      assign D_rt_A =                 D_rs_rt_rd_A[5:3];
      assign D_rd_A =                 D_rs_rt_rd_A[2:0];

      assign D_rs_B =                 D_rs_rt_rd_B[8:6];
      assign D_rt_B =                 D_rs_rt_rd_B[5:3];
      assign D_rd_B =                 D_rs_rt_rd_B[2:0];

      assign X_rs_A =                 X_rs_rt_rd_A[8:6];
      assign X_rt_A =                 X_rs_rt_rd_A[5:3];
      assign X_rd_A =                 X_rs_rt_rd_A[2:0];

      assign X_rs_B =                 X_rs_rt_rd_B[8:6];
      assign X_rt_B =                 X_rs_rt_rd_B[5:3];
      assign X_rd_B =                 X_rs_rt_rd_B[2:0];

      assign M_rs_A =                 M_rs_rt_rd_A[8:6];
      assign M_rt_A =                 M_rs_rt_rd_A[5:3];
      assign M_rd_A =                 M_rs_rt_rd_A[2:0];

      assign M_rs_B =                 M_rs_rt_rd_B[8:6];
      assign M_rt_B =                 M_rs_rt_rd_B[5:3];
      assign M_rd_B =                 M_rs_rt_rd_B[2:0];

      assign W_rs_A =                 W_rs_rt_rd_A[8:6];
      assign W_rt_A =                 W_rs_rt_rd_A[5:3];
      assign W_rd_A =                 W_rs_rt_rd_A[2:0];

      assign W_rs_B =                 W_rs_rt_rd_B[8:6];
      assign W_rt_B =                 W_rs_rt_rd_B[5:3];
      assign W_rd_B =                 W_rs_rt_rd_B[2:0];

      assign D_rs_re_A =              D_bus_A[8];
      assign D_rt_re_A =              D_bus_A[7];
      assign D_regfile_we_A =         D_bus_A[6];
      assign D_nzp_we_A =             D_bus_A[5];
      assign D_select_pc_plus_one_A = D_bus_A[4];
      assign D_is_load_A =            D_bus_A[3];
      assign D_is_store_A =           D_bus_A[2];
      assign D_is_branch_A =          D_bus_A[1];
      assign D_is_control_insn_A =    D_bus_A[0];

      assign D_rs_re_B =              D_bus_B[8];
      assign D_rt_re_B =              D_bus_B[7];
      assign D_regfile_we_B =         D_bus_B[6];
      assign D_nzp_we_B =             D_bus_B[5];
      assign D_select_pc_plus_one_B = D_bus_B[4];
      assign D_is_load_B =            D_bus_B[3];
      assign D_is_store_B =           D_bus_B[2];
      assign D_is_branch_B =          D_bus_B[1];
      assign D_is_control_insn_B =    D_bus_B[0];

      assign X_rs_re_A =              X_bus_A[8];
      assign X_rt_re_A =              X_bus_A[7];
      assign X_regfile_we_A =         X_bus_A[6];
      assign X_nzp_we_A =             X_bus_A[5];
      assign X_select_pc_plus_one_A = X_bus_A[4];
      assign X_is_load_A =            X_bus_A[3];
      assign X_is_store_A =           X_bus_A[2];
      assign X_is_branch_A =          X_bus_A[1];
      assign X_is_control_insn_A =    X_bus_A[0];

      assign X_rs_re_B =              X_bus_B[8];
      assign X_rt_re_B =              X_bus_B[7];
      assign X_regfile_we_B =         X_bus_B[6];
      assign X_nzp_we_B =             X_bus_B[5];
      assign X_select_pc_plus_one_B = X_bus_B[4];
      assign X_is_load_B =            X_bus_B[3];
      assign X_is_store_B =           X_bus_B[2];
      assign X_is_branch_B =          X_bus_B[1];
      assign X_is_control_insn_B =    X_bus_B[0];

      assign M_rs_re_A =              M_bus_A[8];
      assign M_rt_re_A =              M_bus_A[7];
      assign M_regfile_we_A =         M_bus_A[6];
      assign M_nzp_we_A =             M_bus_A[5];
      assign M_select_pc_plus_one_A = M_bus_A[4];
      assign M_is_load_A =            M_bus_A[3];
      assign M_is_store_A =           M_bus_A[2];
      assign M_is_branch_A =          M_bus_A[1];
      assign M_is_control_insn_A =    M_bus_A[0];

      assign M_rs_re_B =              M_bus_B[8];
      assign M_rt_re_B =              M_bus_B[7];
      assign M_regfile_we_B =         M_bus_B[6];
      assign M_nzp_we_B =             M_bus_B[5];
      assign M_select_pc_plus_one_B = M_bus_B[4];
      assign M_is_load_B =            M_bus_B[3];
      assign M_is_store_B =           M_bus_B[2];
      assign M_is_branch_B =          M_bus_B[1];
      assign M_is_control_insn_B =    M_bus_B[0];

      assign W_rs_re_A =              W_bus_A[8];
      assign W_rt_re_A =              W_bus_A[7];
      assign W_regfile_we_A =         W_bus_A[6];
      assign W_nzp_we_A =             W_bus_A[5];
      assign W_select_pc_plus_one_A = W_bus_A[4];
      assign W_is_load_A =            W_bus_A[3];
      assign W_is_store_A =           W_bus_A[2];
      assign W_is_branch_A =          W_bus_A[1];
      assign W_is_control_insn_A =    W_bus_A[0];

      assign W_rs_re_B =              W_bus_B[8];
      assign W_rt_re_B =              W_bus_B[7];
      assign W_regfile_we_B =         W_bus_B[6];
      assign W_nzp_we_B =             W_bus_B[5];
      assign W_select_pc_plus_one_B = W_bus_B[4];
      assign W_is_load_B =            W_bus_B[3];
      assign W_is_store_B =           W_bus_B[2];
      assign W_is_branch_B =          W_bus_B[1];
      assign W_is_control_insn_B =    W_bus_B[0];

      assign rs_re_A =                bus_out_A[8];
      assign rt_re_A =                bus_out_A[7];
      assign regfile_we_A =           bus_out_A[6];
      assign nzp_we_A =               bus_out_A[5];
      assign select_pc_plus_one_A  =  bus_out_A[4];
      assign is_load_A =              bus_out_A[3];
      assign is_store_A =             bus_out_A[2];
      assign is_branch_A =            bus_out_A[1];
      assign is_control_insn_A =      bus_out_A[0];

      assign rs_re_B =                bus_out_B[8];
      assign rt_re_B =                bus_out_B[7];
      assign regfile_we_B =           bus_out_B[6];
      assign nzp_we_B =               bus_out_B[5];
      assign select_pc_plus_one_B  =  bus_out_B[4];
      assign is_load_B =              bus_out_B[3];
      assign is_store_B =             bus_out_B[2];
      assign is_branch_B =            bus_out_B[1];
      assign is_control_insn_B =      bus_out_B[0];


      cla16 add_oneA(.a(pc_A), .b(16'b0), .cin(1'b1), .sum(pc_plus_one_A)); //assume the next instruction for the current decoded insn is pc + 1
      cla16 add_oneB(.a(pc_B), .b(16'b0), .cin(1'b1), .sum(pc_plus_one_B)); //assume the next instruction for the current decoded insn is pc + 1
      
      cla16 add_oneA1(.a(pc_plus_one_A), .b(16'b0), .cin(1'b1), .sum(pc_plus_two_A)); //assume the next instruction for the current decoded insn is pc + 1
      cla16 add_oneB2(.a(pc_plus_one_B), .b(16'b0), .cin(1'b1), .sum(pc_plus_two_B)); //assume the next instruction for the current decoded insn is pc + 1


      Nbit_reg #(16, 16'h8200)  pc_reg (.in(next_pc_A), .out(pc_A_tmp), .clk(clk), .we(1'b1),   .gwe(gwe), .rst(rst));

      Nbit_reg #(16, 16'b0)     FD_insn_regA(.in(i_cur_insn_A), .out(D_insn_A_tmp),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)     FD_insn_regB(.in(i_cur_insn_B), .out(D_insn_B_tmp),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      // D.insn_A advances to X.insn_A
      // D.insn_B advances to D.insn_A so that it will be the "first" instruction advancing out of decode on the next cycle.
      // F.insn_A advances to D.insn_B.
      // o_cur_pc increases by one since only one instruction advanced out of decode.
      // Execute, Memory, and Writeback instructions advance normally.   

      wire should_switch_pipes = superscalar_stall && ~should_stall_A;
      assign D_insn_A = should_switch_pipes ? D_insn_B_tmp : D_insn_A_tmp;
      assign pc_A = should_switch_pipes ? pc_plus_one_A : pc_A_tmp;

      assign D_insn_B = should_switch_pipes ? i_cur_insn_A : D_insn_B_tmp;
      assign pc_B = should_switch_pipes ? pc_plus_one_B : pc_plus_one_A;
      

      lc4_decoder decA(  .insn(D_insn_A),
                        .r1sel(D_rs_rt_rd_A[8:6]), .r1re(D_bus_A[8]),
                        .r2sel(D_rs_rt_rd_A[5:3]), .r2re(D_bus_A[7]), 
                        .wsel (D_rs_rt_rd_A[2:0]), .regfile_we(D_bus_A[6]),
                        .nzp_we(D_bus_A[5]),       .select_pc_plus_one(D_bus_A[4]), 
                        .is_load(D_bus_A[3]),      .is_store(D_bus_A[2]), 
                        .is_branch(D_bus_A[1]),    .is_control_insn(D_bus_A[0]));

      lc4_decoder decB(  .insn(D_insn_B),
                        .r1sel(D_rs_rt_rd_B[8:6]), .r1re(D_bus_B[8]),
                        .r2sel(D_rs_rt_rd_B[5:3]), .r2re(D_bus_B[7]), 
                        .wsel (D_rs_rt_rd_B[2:0]), .regfile_we(D_bus_B[6]),
                        .nzp_we(D_bus_B[5]),       .select_pc_plus_one(D_bus_B[4]), 
                        .is_load(D_bus_B[3]),      .is_store(D_bus_B[2]), 
                        .is_branch(D_bus_B[1]),    .is_control_insn(D_bus_B[0]));

      
      Nbit_reg #(16, 16'b0)     DX_pc_regA(.in(pc_A),         .out(X_pc_A),   .clk(clk), .we(~should_stall_A), .gwe(gwe), .rst(should_flush_A || rst));
      Nbit_reg #(16, 16'b0)     DX_insn_regA(.in(D_insn_A),   .out(X_insn_A), .clk(clk), .we(~should_stall_A), .gwe(gwe), .rst(should_flush_A || rst));
      Nbit_reg #(9, 9'b0) DX_rs_rt_rd_regA(.in(D_rs_rt_rd_A), .out(X_rs_rt_rd_A), .clk(clk), .we(~should_stall_A), .gwe(gwe), .rst(should_flush_A || should_stall_A || rst));
      Nbit_reg #(9, 9'b0)      DX_bus_regA(.in(D_bus_A),      .out(X_bus_A),      .clk(clk), .we(~should_stall_A), .gwe(gwe), .rst(should_flush_A || should_stall_A || rst));

      Nbit_reg #(16, 16'b0)     DX_pc_regB(.in(pc_B),         .out(X_pc_B),   .clk(clk), .we(~should_stall_B), .gwe(gwe), .rst(should_flush_B || rst));
      Nbit_reg #(16, 16'b0)     DX_insn_regB(.in(D_insn_B),   .out(X_insn_B), .clk(clk), .we(~should_stall_B), .gwe(gwe), .rst(should_flush_B || rst));
      Nbit_reg #(9, 9'b0) DX_rs_rt_rd_regB(.in(D_rs_rt_rd_B), .out(X_rs_rt_rd_B), .clk(clk), .we(~should_stall_B), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));
      Nbit_reg #(9, 9'b0)      DX_bus_regB(.in(D_bus_B),      .out(X_bus_B),      .clk(clk), .we(~should_stall_B), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));



      lc4_regfile_ss registerfile(  .i_rs_A(X_rs_A),                      .i_rt_A(X_rt_A),                    .i_rd_A(rd_A),
                                    .i_rs_B(X_rs_B),                      .i_rt_B(X_rt_B),                    .i_rd_B(rd_B),
                                    .o_rs_data_A(regfile_rsdata_out_A),   .o_rt_data_A(regfile_rtdata_out_A), .i_wdata_A(rddata_A), .i_rd_we_A(regfile_we_A),
                                    .o_rs_data_B(regfile_rsdata_out_B),   .o_rt_data_B(regfile_rtdata_out_B), .i_wdata_B(rddata_B), .i_rd_we_B(regfile_we_B),
                                    .clk(clk), .gwe(gwe), .rst(rst)); 


      Nbit_reg #(16, 16'b0)     XM_pc_regA(.in(X_pc_A),       .out(M_pc_A),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall_A || rst));
      Nbit_reg #(16, 16'b0)   XM_insn_regA(.in(X_insn_A),     .out(M_insn_A),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall_A || rst));
      Nbit_reg #(9, 9'b0) XM_rs_rt_rd_regA(.in(X_rs_rt_rd_A), .out(M_rs_rt_rd_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_A || should_stall_A || rst));
      Nbit_reg #(9, 9'b0)      XM_bus_regA(.in(X_bus_A),      .out(M_bus_A),      .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_A || should_stall_A || rst));
      Nbit_reg #(16, 16'b0)      XM_A_regA(.in(rsdata_A),     .out(M_A_A),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_A || should_stall_A || rst)); 
      Nbit_reg #(16, 16'b0)      XM_B_regA(.in(rtdata_A),     .out(M_B_A),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_A || should_stall_A || rst));

      Nbit_reg #(16, 16'b0)     XM_pc_regB(.in(X_pc_B),       .out(M_pc_B),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall_B || rst));
      Nbit_reg #(16, 16'b0)   XM_insn_regB(.in(X_insn_B),     .out(M_insn_B),     .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_stall_B || rst));
      Nbit_reg #(9, 9'b0) XM_rs_rt_rd_regB(.in(X_rs_rt_rd_B), .out(M_rs_rt_rd_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));
      Nbit_reg #(9, 9'b0)      XM_bus_regB(.in(X_bus_B),      .out(M_bus_B),      .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));
      Nbit_reg #(16, 16'b0)      XM_A_regB(.in(rsdata_B),     .out(M_A_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst)); 
      Nbit_reg #(16, 16'b0)      XM_B_regB(.in(rtdata_B),     .out(M_B_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(should_flush_B || should_stall_B || rst));


     
      lc4_alu aluA(.i_insn(M_insn_A), .i_pc(M_pc_A), .i_r1data(i_alu_r1data_A), .i_r2data(i_alu_r2data_A), .o_result(alu_result_A)); //ALU
      lc4_alu aluB(.i_insn(M_insn_B), .i_pc(M_pc_B), .i_r1data(i_alu_r1data_B), .i_r2data(i_alu_r2data_B), .o_result(alu_result_B)); //ALU



      Nbit_reg #(16, 16'b0)     MW_pc_regA(.in(M_pc_A),         .out(W_pc_A),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   MW_insn_regA(.in(M_insn_A),       .out(W_insn_A),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) MW_rs_rt_rd_regA(.in(M_rs_rt_rd_A),   .out(W_rs_rt_rd_A),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      MW_O_regA(.in(alu_result_A),   .out(W_alu_result_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data
      Nbit_reg #(9, 9'b0)      MW_bus_regA(.in(M_bus_A),        .out(W_bus_A),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(16, 16'b0)     MW_pc_regB(.in(M_pc_B),         .out(W_pc_B),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   MW_insn_regB(.in(M_insn_B),       .out(W_insn_B),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) MW_rs_rt_rd_regB(.in(M_rs_rt_rd_B),   .out(W_rs_rt_rd_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      MW_O_regB(.in(alu_result_B),   .out(W_alu_result_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data
      Nbit_reg #(9, 9'b0)      MW_bus_regB(.in(M_bus_B),        .out(W_bus_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));



      Nbit_reg #(16, 16'b0)     WD_pc_regA(.in(W_pc_A),         .out(pc_out_A),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   WD_insn_regA(.in(W_insn_A),       .out(insn_out_A),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) WD_rs_rt_rd_regA(.in(W_rs_rt_rd_A),   .out(rs_rt_rd_out_A),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      WD_O_regA(.in(W_alu_result_A), .out(alu_result_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(9, 9'b0)      WD_bus_regA(.in(W_bus_A),        .out(bus_out_A),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      Nbit_reg #(16, 16'b0)     WD_pc_regB(.in(W_pc_B),         .out(pc_out_B),         .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)   WD_insn_regB(.in(W_insn_B),       .out(insn_out_B),       .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(9, 9'b0) WD_rs_rt_rd_regB(.in(W_rs_rt_rd_B),   .out(rs_rt_rd_out_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0)      WD_O_regB(.in(W_alu_result_B), .out(alu_result_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(9, 9'b0)      WD_bus_regB(.in(W_bus_B),        .out(bus_out_B),        .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));



      Nbit_reg #(3, 3'b0) M_nzp_reg_A(.in(nzp_in_A),  .out(W_nzp_A),  .clk(clk), .we(M_nzp_we_A), .gwe(gwe), .rst(rst));
	   Nbit_reg #(3, 3'b0) W_nzp_reg_A(.in(W_nzp_A),   .out(nzp_A),    .clk(clk), .we(W_nzp_we_A), .gwe(gwe), .rst(rst));

      Nbit_reg #(3, 3'b0) M_nzp_reg_B(.in(nzp_in_B),  .out(W_nzp_B),  .clk(clk), .we(M_nzp_we_B), .gwe(gwe), .rst(rst));
	   Nbit_reg #(3, 3'b0) W_nzp_reg_B(.in(W_nzp_B),   .out(nzp_B),    .clk(clk), .we(W_nzp_we_B), .gwe(gwe), .rst(rst));


      assign M_dmem_addr_A = M_is_store_A || M_is_load_A ? alu_result_A : 16'b0;
      Nbit_reg #(16, 16'b0) MW_dmem_addr_regA(.in(M_dmem_addr_A), .out(W_dmem_addr_A),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(16, 16'b0) WD_dmem_addr_regA(.in(W_dmem_addr_A), .out(dmem_addr_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address

      assign M_dmem_addr_B = M_is_store_B || M_is_load_B ? alu_result_B : 16'b0;
      Nbit_reg #(16, 16'b0) MW_dmem_addr_regB(.in(M_dmem_addr_B), .out(W_dmem_addr_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address
      Nbit_reg #(16, 16'b0) WD_dmem_addr_regB(.in(W_dmem_addr_B), .out(dmem_addr_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem address

   
      Nbit_reg #(16, 16'b0) MW_dmem_data_regA(.in(M_dmem_data_A), .out(W_dmem_data_A),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0) WD_dmem_data_regA(.in(W_dmem_data_A), .out(dmem_data_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data

      Nbit_reg #(16, 16'b0) MW_dmem_data_regB(.in(M_dmem_data_B), .out(W_dmem_data_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(16, 16'b0) WD_dmem_data_regB(.in(W_dmem_data_B), .out(dmem_data_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst)); //Holds dmem data










      wire [1:0] stall_in_A;// = should_flush_A ? 2'b10 : 2'b00;
      wire [1:0] stall_in_B;// = should_flush_B ? 2'b10 : 2'b00;

      wire [1:0] stall_x_A, stall_x_B;

      //Bypassing logic
      // (1) LTU dependence with dest = D.A (can be within pipe A (from X.A to D.A) or between pipes (from X.B to D.A))
      wire is_DA_LTU_within_pipe = X_is_load_A && ((X_rd_A == D_rs_A && D_rs_re_A) || (X_rd_A == D_rt_A && D_rt_re_A && ~(D_is_store_A || D_is_load_A)));
      wire is_DA_LTU_across_pipes = X_is_load_A && ((X_rd_A == D_rs_B && D_rs_re_B) || (X_rd_A == D_rt_B && D_rt_re_B && ~(D_is_store_B || D_is_load_B)));
      wire is_DA_LTU = is_DA_LTU_within_pipe || is_DA_LTU_across_pipes;

      // (2) LTU dependence with dest = D.B (can be within pipe B (from M.B to D.B) or between pipes (from X.A to D.B (note: a LTU dependence from D.A to D.B should be considered part of (3) below)
      wire is_DB_LTU_within_pipe = X_is_load_B && ((X_rd_B == D_rs_B && X_rs_re_B) || (X_rd_B == D_rt_B && D_rt_re_B && ~(D_is_store_B || D_is_load_B)));
      wire is_DB_LTU_across_pipes = X_is_load_B && ((X_rd_B == D_rs_A && D_rs_re_A) || (X_rd_B == D_rt_A && D_rt_re_A && ~(D_is_store_A || D_is_load_A)));
      wire is_DB_LTU = is_DB_LTU_within_pipe || is_DB_LTU_across_pipes;

      // (3) Dependence from D.A to D.B (including the case where D.A is a load)
      wire is_DA_to_DB_LTU = ((D_rd_B == D_rs_A && D_rs_re_A) || (D_rd_B == D_rt_A && D_rt_re_A && ~D_is_store_A) || (D_rd_B == D_rd_A && ~D_is_store_A));
      //wire is_XB_to_XA_LTU = (X_is_load_A && ((X_rd_A == X_rs_B && X_rs_re_B) || (X_rd_A == X_rt_B && X_rt_re_B && ~X_is_store_B)));

      // (4) Structural hazard (both D.A and D.B access memory)
      wire is_structural_hazard = (D_is_load_A || D_is_store_A) && (D_is_load_B || D_is_store_B);

      // if instruction D.A (the insn in the Decode stage in the A pipe) has a LTU dependence,
      wire case1 = is_DA_LTU;
      // insert a NOP into both pipes, and stall the fetch and decode stages. Record a load-to-use stall (stall = 3) in pipe A and a superscalar stall (stall = 1) in pipeline B.

      // If instruction X.B has a LTU dependence, but does not have any dependencies on instruction X.A, and instruction X.A does not stall, 
      wire case2 = is_DB_LTU && ~is_DA_to_DB_LTU && ~is_DA_LTU;
      // stall pipeline B only (see Pipe Switching section below) and record a load-to-use stall in pipeline B.
   
      // If instruction X.B requires a value computed by X.A (including if X.A is a load), and instruction X.A does not stall, 
      wire case3 = is_DA_to_DB_LTU && ~is_DA_LTU;
      // stall pipe B only (see Pipe Switching section), and record a superscalar stall in pipeline B.

      // If neither instruction has a load-to-use dependence, and instruction X.B does not depend on instruction X.A, 
      wire case4 = ~is_DB_LTU && ~is_DA_LTU && ~is_DA_to_DB_LTU;
      // both instructions advance normally.

      // If you have two independent instructions that interact with memory in the same stage (e.g., two loads, or a load and a store), 
      wire case5 = ~is_DB_LTU && ~is_DA_LTU && ~is_DA_to_DB_LTU && is_structural_hazard;
      // instruction X.B incurs a superscalar stall, since only one instruction can interact with memory at a time.
   

      
      assign superscalar_stall = stall_x_B == 2'b01;
      assign should_stall_A = stall_x_A == 2'b11;
      assign should_stall_B = stall_x_B == 2'b11;

      assign stall_in_A = should_flush_A ? 2'b10 : 2'b00;
      assign stall_x_A = X_stall_A == 2'b10 ? 2'b10 : (case1 ? 2'b11 : 2'b00);

      Nbit_reg #(2, 2'b10)   F_stall_regA(.in(stall_in_A),     .out(X_stall_A),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   D_stall_regA(.in(stall_x_A),     .out(M_stall_A),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   X_stall_regA(.in(M_stall_A),      .out(W_stall_A),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   M_stall_regA(.in(W_stall_A),     .out(stall_out_A),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      assign stall_in_B = should_flush_B ? 2'b10 : 2'b00;
      assign stall_x_B = X_stall_B == 2'b10 ? 2'b10 : (case1 ? 2'b01 : (case2 ? 2'b11 : (case3 ? 2'b01 : (case4 ? 2'b00 : (case5 ? 2'b01 :  2'b00)))));

      Nbit_reg #(2, 2'b10)   F_stall_regB(.in(stall_in_B),     .out(X_stall_B),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   D_stall_regB(.in(stall_x_B),     .out(M_stall_B),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   X_stall_regB(.in(M_stall_B),      .out(W_stall_B),   .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
      Nbit_reg #(2, 2'b10)   M_stall_regB(.in(W_stall_B),     .out(stall_out_B),    .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

      assign should_flush_A = 1'b0;//(M_is_branch_B && |(M_insn_B[11:9] & W_nzp_B)) || M_is_control_insn_B;
      assign should_flush_B = 1'b0;
      
      assign rsdata_B = W_regfile_we_B && (W_rd_B == X_rs_B) ? W_dmem_data_B : regfile_rsdata_out_B;
      assign rtdata_B = W_regfile_we_B && (W_rd_B == X_rt_B) ? W_dmem_addr_B : regfile_rtdata_out_B;

      assign i_alu_r1data_B = W_regfile_we_B && (W_rd_B == M_rs_B) ? W_alu_result_B : (regfile_we_B && (rd_B == M_rs_B) ? rddata_B : M_A_B);
      assign i_alu_r2data_B = W_regfile_we_B && (W_rd_B == M_rt_B) ? W_alu_result_B : (regfile_we_B && (rd_B == M_rt_B) ? rddata_B : M_B_B);

      wire is_load_to_store_A = W_is_load_A && M_is_store_A && W_rd_A == M_rt_A;
      assign M_dmem_data_A = is_load_to_store_A ? W_dmem_data_A : (M_is_load_A ? i_cur_dmem_data : (M_is_store_A ? i_alu_r2data_A: 16'b0));

      wire is_load_to_store_B = W_is_load_B && M_is_store_B && W_rd_B == M_rt_B;
      assign M_dmem_data_B = is_load_to_store_B ? W_dmem_data_B : (M_is_load_B ? i_cur_dmem_data : (M_is_store_B ? i_alu_r2data_B: 16'b0));

      wire [15:0] nzp_data_A = M_is_control_insn_A ? X_pc_A : (M_is_load_A ? M_dmem_data_A : alu_result_A);
      assign nzp_in_A[2] = nzp_data_A[15];
      assign nzp_in_A[1] = &(~nzp_data_A);
      assign nzp_in_A[0] = ~nzp_data_A[15] && (|nzp_data_A);

      wire [15:0] nzp_data_B = M_is_control_insn_B ? X_pc_B : (M_is_load_B ? M_dmem_data_B : alu_result_B);
      assign nzp_in_B[2] = nzp_data_B[15];
      assign nzp_in_B[1] = &(~nzp_data_B);
      assign nzp_in_B[0] = ~nzp_data_B[15] && (|nzp_data_B);


      assign rd_A        = rs_rt_rd_out_A[2:0];
      assign rd_B        = rs_rt_rd_out_B[2:0];

      assign rddata_A    = is_control_insn_A ? W_pc_A : (is_load_A ? dmem_data_out_A : alu_result_out_A);
      assign rddata_B    = is_control_insn_B ? W_pc_B : (is_load_B ? dmem_data_out_B : alu_result_out_B);

      assign next_pc_A = pc_plus_two_A; //should_flush_A ? alu_result_A : (should_stall_A ? pc_A : pc_plus_one_A); //assume the next pc is pc+1
      assign next_pc_B = pc_plus_two_B; //should_flush_B ? alu_result_B : (should_stall_B ? pc_B : pc_plus_one_B); //assume the next pc is pc+1
      
      
      
      //SET OUTPUTS
      assign o_dmem_we = M_is_store_B;  // Data memory write enable
      assign o_dmem_addr = M_dmem_addr_B;        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
      assign o_dmem_towrite = M_dmem_data_B;
      assign o_cur_pc = should_switch_pipes ? pc_B : pc_A; //TODO *******
      


      //SET TESTING PINS - 
      assign test_regfile_we_A   = regfile_we_A;    // Testbench: register file write enable
      assign test_regfile_we_B   = regfile_we_B;    // Testbench: register file write enable

      assign test_regfile_wsel_A = rd_A;  // Testbench: which register to write in the register file
      assign test_regfile_wsel_B = rd_B;

      assign test_regfile_data_A = rddata_A;  // Testbench: value to write into the register file
      assign test_regfile_data_B = rddata_B;

      assign test_nzp_we_A       = nzp_we_A;     // Testbench: NZP condition codes write enable
      assign test_nzp_we_B       = nzp_we_B;

      assign test_nzp_new_bits_A = nzp_A;  // Testbench: value to write to NZP bits
      assign test_nzp_new_bits_B = nzp_B;

      assign test_dmem_we_A      = is_store_A;       // Testbench: data memory write enable
      assign test_dmem_we_B      = is_store_B;

      assign test_dmem_addr_A    = dmem_addr_out_A;     // Testbench: address to read/write memory
      assign test_dmem_addr_B    = dmem_addr_out_B;

      assign test_dmem_data_A    = dmem_data_out_A;     // Testbench: value read/writen from/to memory 
      assign test_dmem_data_B    = dmem_data_out_B;

      assign test_stall_A        = stall_out_A; // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
      assign test_stall_B        = stall_out_B;

      assign test_cur_pc_A       = pc_out_A; 
      assign test_cur_pc_B       = pc_out_B; 

      assign test_cur_insn_A     = insn_out_A; 
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
