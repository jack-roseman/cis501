`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

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