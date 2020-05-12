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

   wire[n-1:0] i_wdata;

   //00 is A 01 is B 10 is nothing
   wire write = i_rd_we_B || i_rd_we_A ? 1'b1 : 1'b0;
   wire[1:0] being_written = i_rd_we_B ? 2'b01 : (i_rd_we_A ? 2'b00 : 2'b10);

   wire[2:0] dest = being_written == 2'b00 ? i_rd_A : i_rd_B;

   wire rs_A_bypass = i_rs_A == dest ? 1'b1 : 1'b0;
   wire rs_B_bypass = i_rs_B == dest ? 1'b1 : 1'b0;
   wire rt_A_bypass = i_rt_A == dest ? 1'b1 : 1'b0;
   wire rt_B_bypass = i_rt_B == dest ? 1'b1 : 1'b0;

   assign i_wdata = being_written == 2'b00 ? i_wdata_A : i_wdata_B;

   wire [n-1:0] r0, r1, r2, r3, r4, r5, r6, r7;
   
   Nbit_reg #(n) r_0(.in(i_wdata), .clk(clk), .we(dest == 3'b000 & write), .gwe(gwe), .rst(rst), .out(r0));
   Nbit_reg #(n) r_1(.in(i_wdata), .clk(clk), .we(dest == 3'b001 & write), .gwe(gwe), .rst(rst), .out(r1));
   Nbit_reg #(n) r_2(.in(i_wdata), .clk(clk), .we(dest == 3'b010 & write), .gwe(gwe), .rst(rst), .out(r2));
   Nbit_reg #(n) r_3(.in(i_wdata), .clk(clk), .we(dest == 3'b011 & write), .gwe(gwe), .rst(rst), .out(r3));
   Nbit_reg #(n) r_4(.in(i_wdata), .clk(clk), .we(dest == 3'b100 & write), .gwe(gwe), .rst(rst), .out(r4));
   Nbit_reg #(n) r_5(.in(i_wdata), .clk(clk), .we(dest == 3'b101 & write), .gwe(gwe), .rst(rst), .out(r5));
   Nbit_reg #(n) r_6(.in(i_wdata), .clk(clk), .we(dest == 3'b110 & write), .gwe(gwe), .rst(rst), .out(r6));
   Nbit_reg #(n) r_7(.in(i_wdata), .clk(clk), .we(dest == 3'b111 & write), .gwe(gwe), .rst(rst), .out(r7));
   
   assign o_rs_data_A = (rs_A_bypass && write) ? i_wdata : (i_rs_A == 3'b000 ? r0 : (i_rs_A == 3'b001 ? r1 :  (i_rs_A == 3'b010 ? r2 : (i_rs_A == 3'b011 ? r3 : (i_rs_A == 3'b100 ? r4 : (i_rs_A == 3'b101 ? r5 : (i_rs_A == 3'b110 ? r6 : r7)))))));
   assign o_rs_data_B = (rs_B_bypass && write) ? i_wdata : (i_rs_B == 3'b000 ? r0 : (i_rs_B == 3'b001 ? r1 :  (i_rs_B == 3'b010 ? r2 : (i_rs_B == 3'b011 ? r3 : (i_rs_B == 3'b100 ? r4 : (i_rs_B == 3'b101 ? r5 : (i_rs_B == 3'b110 ? r6 : r7)))))));

   assign o_rt_data_A = (rt_A_bypass && write) ? i_wdata : (i_rt_A == 3'b000 ? r0 : (i_rt_A == 3'b001 ? r1 :  (i_rt_A == 3'b010 ? r2 : (i_rt_A == 3'b011 ? r3 : (i_rt_A == 3'b100 ? r4 : (i_rt_A == 3'b101 ? r5 : (i_rt_A == 3'b110 ? r6 : r7)))))));
   assign o_rt_data_B = (rt_B_bypass && write) ? i_wdata : (i_rt_B == 3'b000 ? r0 : (i_rt_B == 3'b001 ? r1 :  (i_rt_B == 3'b010 ? r2 : (i_rt_B == 3'b011 ? r3 : (i_rt_B == 3'b100 ? r4 : (i_rt_B == 3'b101 ? r5 : (i_rt_B == 3'b110 ? r6 : r7)))))));
   
   always @(posedge clk) begin

      //$display("%d Inputs: \t rd - R%d, R%d \n\t\t\t\t rs - R%d, R%d \n\t\t\t\t rt - R%d, R%d \n", $time, i_rd_A, i_rd_B, i_rs_A, i_rs_B, i_rt_A, i_rt_B);
      $display("%d \t R0 %h \n\t\t\t R1 %h \n\t\t\t R2 %h \n\t\t\t R3 %h \n\t\t\t R4 %h \n\t\t\t R5 %h \n\t\t\t R6 %h \n\t\t\t R7 %h \n", $time, r0, r1, r2, r3, r4, r5, r6, r7);

      if (i_rd_we_A) begin
         $display("%d Write R%d <= %h", $time, i_rd_A, i_wdata_A);

         if (i_rs_A == i_rd_A || i_rs_A == i_rd_B) begin
         $display("%d rs_A Bypass Needed", $time, );
         end

         if (i_rt_A == i_rd_A || i_rt_A == i_rd_B) begin
            $display("%d rt_A Bypass Needed", $time);
         end
      end

      if (i_rd_we_B) begin
          $display("%d Write R%d <= %h", $time, i_rd_B, i_wdata_B);
          if (i_rs_B == i_rd_A || i_rs_B == i_rd_B) begin
            $display("%d rs_B Bypass", $time);
         end

         if (i_rt_B == i_rd_A || i_rt_B == i_rd_B) begin
            $display("%d rt_B Bypass", $time);
         end
      end

      $display("%d rs_A Read R%d => %h", $time, i_rs_A, o_rs_data_A);
      $display("%d rt_A Read R%d => %h", $time, i_rt_A, o_rt_data_A);

      $display("%d rs_B Read R%d => %h", $time, i_rs_B, o_rs_data_B);
      $display("%d rt_B Read R%d => %h", $time, i_rt_B, o_rt_data_B);
      
      if (i_rd_A == i_rd_B && i_rd_we_A && i_rd_we_B) begin
         $display("%d Two writes to the same register R%d at the same time", $time, i_rd_A);
      end

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