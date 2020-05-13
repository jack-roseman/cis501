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

   wire [n-1:0] reg0_r0, reg0_r1, reg0_r2, reg0_r3, reg0_r4, reg0_r5, reg0_r6, reg0_r7; //register 0 outputs
   wire [n-1:0] reg1_r0, reg1_r1, reg1_r2, reg1_r3, reg1_r4, reg1_r5, reg1_r6, reg1_r7; //register 1 outputs
   wire [n-1:0] r0, r1, r2, r3, r4, r5, r6, r7;
   wire [7:0] state_in, state_out;

   wire r0_A_write = (i_rd_A == 3'b000) && i_rd_we_A;
   wire r1_A_write = (i_rd_A == 3'b001) && i_rd_we_A;
   wire r2_A_write = (i_rd_A == 3'b010) && i_rd_we_A;
   wire r3_A_write = (i_rd_A == 3'b011) && i_rd_we_A;
   wire r4_A_write = (i_rd_A == 3'b100) && i_rd_we_A;
   wire r5_A_write = (i_rd_A == 3'b101) && i_rd_we_A;
   wire r6_A_write = (i_rd_A == 3'b110) && i_rd_we_A;
   wire r7_A_write = (i_rd_A == 3'b111) && i_rd_we_A;

   wire r0_B_write = (i_rd_B == 3'b000) && i_rd_we_B;
   wire r1_B_write = (i_rd_B == 3'b001) && i_rd_we_B;
   wire r2_B_write = (i_rd_B == 3'b010) && i_rd_we_B;
   wire r3_B_write = (i_rd_B == 3'b011) && i_rd_we_B;
   wire r4_B_write = (i_rd_B == 3'b100) && i_rd_we_B;
   wire r5_B_write = (i_rd_B == 3'b101) && i_rd_we_B;
   wire r6_B_write = (i_rd_B == 3'b110) && i_rd_we_B;
   wire r7_B_write = (i_rd_B == 3'b111) && i_rd_we_B;

   assign state_in[0] = r0_B_write ? 1'b1 : (r0_A_write ? 1'b0 : state_out[0]);
   assign state_in[1] = r1_B_write ? 1'b1 : (r1_A_write ? 1'b0 : state_out[1]);
   assign state_in[2] = r2_B_write ? 1'b1 : (r2_A_write ? 1'b0 : state_out[2]);
   assign state_in[3] = r3_B_write ? 1'b1 : (r3_A_write ? 1'b0 : state_out[3]);
   assign state_in[4] = r4_B_write ? 1'b1 : (r4_A_write ? 1'b0 : state_out[4]);
   assign state_in[5] = r5_B_write ? 1'b1 : (r5_A_write ? 1'b0 : state_out[5]);
   assign state_in[6] = r6_B_write ? 1'b1 : (r6_A_write ? 1'b0 : state_out[6]);
   assign state_in[7] = r7_B_write ? 1'b1 : (r7_A_write ? 1'b0 : state_out[7]);

   Nbit_reg #(8, 8'b0) read_state(.in(state_in), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(state_out));

   //pipe A
   Nbit_reg #(n) reg0_0(.in(i_wdata_A), .clk(clk), .we(r0_A_write), .gwe(gwe), .rst(rst), .out(reg0_r0));
   Nbit_reg #(n) reg0_1(.in(i_wdata_A), .clk(clk), .we(r1_A_write), .gwe(gwe), .rst(rst), .out(reg0_r1));
   Nbit_reg #(n) reg0_2(.in(i_wdata_A), .clk(clk), .we(r2_A_write), .gwe(gwe), .rst(rst), .out(reg0_r2));
   Nbit_reg #(n) reg0_3(.in(i_wdata_A), .clk(clk), .we(r3_A_write), .gwe(gwe), .rst(rst), .out(reg0_r3));
   Nbit_reg #(n) reg0_4(.in(i_wdata_A), .clk(clk), .we(r4_A_write), .gwe(gwe), .rst(rst), .out(reg0_r4));
   Nbit_reg #(n) reg0_5(.in(i_wdata_A), .clk(clk), .we(r5_A_write), .gwe(gwe), .rst(rst), .out(reg0_r5));
   Nbit_reg #(n) reg0_6(.in(i_wdata_A), .clk(clk), .we(r6_A_write), .gwe(gwe), .rst(rst), .out(reg0_r6));
   Nbit_reg #(n) reg0_7(.in(i_wdata_A), .clk(clk), .we(r7_A_write), .gwe(gwe), .rst(rst), .out(reg0_r7));

   //Pipe B
   Nbit_reg #(n) reg1_0(.in(i_wdata_B), .clk(clk), .we(r0_B_write), .gwe(gwe), .rst(rst), .out(reg1_r0));
   Nbit_reg #(n) reg1_1(.in(i_wdata_B), .clk(clk), .we(r1_B_write), .gwe(gwe), .rst(rst), .out(reg1_r1));
   Nbit_reg #(n) reg1_2(.in(i_wdata_B), .clk(clk), .we(r2_B_write), .gwe(gwe), .rst(rst), .out(reg1_r2));
   Nbit_reg #(n) reg1_3(.in(i_wdata_B), .clk(clk), .we(r3_B_write), .gwe(gwe), .rst(rst), .out(reg1_r3));
   Nbit_reg #(n) reg1_4(.in(i_wdata_B), .clk(clk), .we(r4_B_write), .gwe(gwe), .rst(rst), .out(reg1_r4));
   Nbit_reg #(n) reg1_5(.in(i_wdata_B), .clk(clk), .we(r5_B_write), .gwe(gwe), .rst(rst), .out(reg1_r5));
   Nbit_reg #(n) reg1_6(.in(i_wdata_B), .clk(clk), .we(r6_B_write), .gwe(gwe), .rst(rst), .out(reg1_r6));
   Nbit_reg #(n) reg1_7(.in(i_wdata_B), .clk(clk), .we(r7_B_write), .gwe(gwe), .rst(rst), .out(reg1_r7));

   assign r0 = (i_rs_A == 3'b000 || i_rs_B == 3'b000 || i_rt_A == 3'b000 || i_rt_B == 3'b000) && (r0_A_write || r0_B_write) ? (state_in[0] ? i_wdata_B : i_wdata_A) : (state_out[0] ? reg1_r0 : reg0_r0);
   assign r1 = (i_rs_A == 3'b001 || i_rs_B == 3'b001 || i_rt_A == 3'b001 || i_rt_B == 3'b001) && (r1_A_write || r1_B_write) ? (state_in[1] ? i_wdata_B : i_wdata_A) : (state_out[1] ? reg1_r1 : reg0_r1);
   assign r2 = (i_rs_A == 3'b010 || i_rs_B == 3'b010 || i_rt_A == 3'b010 || i_rt_B == 3'b010) && (r2_A_write || r2_B_write) ? (state_in[2] ? i_wdata_B : i_wdata_A) : (state_out[2] ? reg1_r2 : reg0_r2);
   assign r3 = (i_rs_A == 3'b011 || i_rs_B == 3'b011 || i_rt_A == 3'b011 || i_rt_B == 3'b011) && (r3_A_write || r3_B_write) ? (state_in[3] ? i_wdata_B : i_wdata_A) : (state_out[3] ? reg1_r3 : reg0_r3);
   assign r4 = (i_rs_A == 3'b100 || i_rs_B == 3'b100 || i_rt_A == 3'b100 || i_rt_B == 3'b100) && (r4_A_write || r4_B_write) ? (state_in[4] ? i_wdata_B : i_wdata_A) : (state_out[4] ? reg1_r4 : reg0_r4);
   assign r5 = (i_rs_A == 3'b101 || i_rs_B == 3'b101 || i_rt_A == 3'b101 || i_rt_B == 3'b101) && (r5_A_write || r5_B_write) ? (state_in[5] ? i_wdata_B : i_wdata_A) : (state_out[5] ? reg1_r5 : reg0_r5);
   assign r6 = (i_rs_A == 3'b110 || i_rs_B == 3'b110 || i_rt_A == 3'b110 || i_rt_B == 3'b110) && (r6_A_write || r6_B_write) ? (state_in[6] ? i_wdata_B : i_wdata_A) : (state_out[6] ? reg1_r6 : reg0_r6);
   assign r7 = (i_rs_A == 3'b111 || i_rs_B == 3'b111 || i_rt_A == 3'b111 || i_rt_B == 3'b111) && (r7_A_write || r7_B_write) ? (state_in[7] ? i_wdata_B : i_wdata_A) : (state_out[7] ? reg1_r7 : reg0_r7);

   
   assign o_rs_data_A = (i_rs_A == 3'b000 ? r0 : (i_rs_A == 3'b001 ? r1 :  (i_rs_A == 3'b010 ? r2 : (i_rs_A == 3'b011 ? r3 : (i_rs_A == 3'b100 ? r4 : (i_rs_A == 3'b101 ? r5 : (i_rs_A == 3'b110 ? r6 : r7)))))));
   assign o_rs_data_B = (i_rs_B == 3'b000 ? r0 : (i_rs_B == 3'b001 ? r1 :  (i_rs_B == 3'b010 ? r2 : (i_rs_B == 3'b011 ? r3 : (i_rs_B == 3'b100 ? r4 : (i_rs_B == 3'b101 ? r5 : (i_rs_B == 3'b110 ? r6 : r7)))))));

   assign o_rt_data_A = (i_rt_A == 3'b000 ? r0 : (i_rt_A == 3'b001 ? r1 :  (i_rt_A == 3'b010 ? r2 : (i_rt_A == 3'b011 ? r3 : (i_rt_A == 3'b100 ? r4 : (i_rt_A == 3'b101 ? r5 : (i_rt_A == 3'b110 ? r6 : r7)))))));
   assign o_rt_data_B = (i_rt_B == 3'b000 ? r0 : (i_rt_B == 3'b001 ? r1 :  (i_rt_B == 3'b010 ? r2 : (i_rt_B == 3'b011 ? r3 : (i_rt_B == 3'b100 ? r4 : (i_rt_B == 3'b101 ? r5 : (i_rt_B == 3'b110 ? r6 : r7)))))));
   
endmodule
