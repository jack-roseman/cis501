`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

/* 8-register, n-bit register file with
 * four read ports and two write ports
 * to support two pipes.
 * 
 * If both pipes try to write to the
 * same register, pipe B wins.
 * 
 * Inputs should be bypassed to the outputs
 * as needed so the register file returns
 * data that is written immediately
 * rather than only on the next cycle.
 */
module lc4_regfile_ss #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,

    input  wire [  2:0] i_rs_A,      // pipe A: rs selector
    output wire [n-1:0] o_rs_data_A, // pipe A: rs contents
    input  wire [  2:0] i_rt_A,      // pipe A: rt selector
    output wire [n-1:0] o_rt_data_A, // pipe A: rt contents

    input  wire [  2:0] i_rs_B,      // pipe B: rs selector
    output wire [n-1:0] o_rs_data_B, // pipe B: rs contents
    input  wire [  2:0] i_rt_B,      // pipe B: rt selector
    output wire [n-1:0] o_rt_data_B, // pipe B: rt contents

    input  wire [  2:0]  i_rd_A,     // pipe A: rd selector
    input  wire [n-1:0]  i_wdata_A,  // pipe A: data to write
    input  wire          i_rd_we_A,  // pipe A: write enable

    input  wire [  2:0]  i_rd_B,     // pipe B: rd selector
    input  wire [n-1:0]  i_wdata_B,  // pipe B: data to write
    input  wire          i_rd_we_B   // pipe B: write enable
    );

   wire should_write_A = ~(i_rd_A == i_rd_B);
   wire should_write_B = (i_rd_A == i_rd_B);

   

   lc4_regfile c1(.clk(clk), .gwe(gwe), .rst(rst), 
                  .i_rd(i_rd_A), .i_rd_we(i_rd_we_A), .i_wdata(i_wdata_A),
                  .i_rs(i_rs_A), .i_rt(i_rt_A),
                  .o_rs_data(o_rs_data_A), .o_rt_data(o_rt_data_A));
   
   lc4_regfile c2(.clk(clk), .gwe(gwe), .rst(rst), 
                  .i_rd(i_rd_B), .i_rd_we(i_rd_we_B), .i_wdata(i_wdata_B),
                  .i_rs(i_rs_B), .i_rt(i_rt_B),
                  .o_rs_data(o_rs_data_B), .o_rt_data(o_rt_data_B));
endmodule



module lc4_regfile #(parameter n = 16)
   (input  wire         clk,
    input  wire         gwe,
    input  wire         rst,
    input  wire [  2:0] i_rs,      // rs selector
    output wire [n-1:0] o_rs_data, // rs contents
    input  wire [  2:0] i_rt,      // rt selector
    output wire [n-1:0] o_rt_data, // rt contents
    input  wire [  2:0] i_rd,      // rd selector
    input  wire [n-1:0] i_wdata,   // data to write
    input  wire         i_rd_we    // write enable
    );

   wire [n-1:0] r0, r1, r2, r3, r4, r5, r6, r7;
   
   Nbit_reg #(n) r_0(.in(i_wdata), .clk(clk), .we(i_rd == 3'b000 & i_rd_we), .gwe(gwe), .rst(rst), .out(r0));
   Nbit_reg #(n) r_1(.in(i_wdata), .clk(clk), .we(i_rd == 3'b001 & i_rd_we), .gwe(gwe), .rst(rst), .out(r1));
   Nbit_reg #(n) r_2(.in(i_wdata), .clk(clk), .we(i_rd == 3'b010 & i_rd_we), .gwe(gwe), .rst(rst), .out(r2));
   Nbit_reg #(n) r_3(.in(i_wdata), .clk(clk), .we(i_rd == 3'b011 & i_rd_we), .gwe(gwe), .rst(rst), .out(r3));
   Nbit_reg #(n) r_4(.in(i_wdata), .clk(clk), .we(i_rd == 3'b100 & i_rd_we), .gwe(gwe), .rst(rst), .out(r4));
   Nbit_reg #(n) r_5(.in(i_wdata), .clk(clk), .we(i_rd == 3'b101 & i_rd_we), .gwe(gwe), .rst(rst), .out(r5));
   Nbit_reg #(n) r_6(.in(i_wdata), .clk(clk), .we(i_rd == 3'b110 & i_rd_we), .gwe(gwe), .rst(rst), .out(r6));
   Nbit_reg #(n) r_7(.in(i_wdata), .clk(clk), .we(i_rd == 3'b111 & i_rd_we), .gwe(gwe), .rst(rst), .out(r7));
   
   assign o_rs_data = i_rs == 3'b000 ? r0 : (i_rs == 3'b001 ? r1 :  (i_rs == 3'b010 ? r2 : (i_rs == 3'b011 ? r3 : (i_rs == 3'b100 ? r4 : (i_rs == 3'b101 ? r5 : (i_rs == 3'b110 ? r6 : r7))))));
   assign o_rt_data = i_rt == 3'b000 ? r0 : (i_rt == 3'b001 ? r1 :  (i_rt == 3'b010 ? r2 : (i_rt == 3'b011 ? r3 : (i_rt == 3'b100 ? r4 : (i_rt == 3'b101 ? r5 : (i_rt == 3'b110 ? r6 : r7))))));
   
endmodule