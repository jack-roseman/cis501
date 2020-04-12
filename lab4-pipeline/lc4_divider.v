`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);


           wire [15:0] remainder[16:0];
           assign remainder[0] = 16'b0;

           wire [15:0] quotient[16:0];
           assign quotient[0] = 16'b0;

            wire [15:0] dividend[16:0];
           assign dividend[0] = i_dividend;

           genvar i;
            for(i=0; i<16; i = i+1) begin
                lc4_divider_one_iter iter(.i_dividend(dividend[i]), .i_divisor(i_divisor), .i_remainder(remainder[i]), .i_quotient(quotient[i]), .o_dividend(dividend[i+1]),
                        .o_remainder(remainder[i+1]), .o_quotient(quotient[i+1]));
            end

            assign o_remainder = remainder[16];
            assign o_quotient = quotient[16];

endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      parameter binOne16 = {15'b0, 1'b1};
		    
      wire [15:0] rem_1, quo_1, rem_2, div_1;

      assign div_1 = (i_dividend>>15) & binOne16;
      assign rem_1 = (i_remainder<<1) | div_1;

      wire quo_ind;
      wire [15:0] quo_2, quo_3;

      assign quo_ind = (i_divisor == 16'b0) ? 1'b1 : 1'b0;
      assign quo_1 = i_quotient<<1;
      assign quo_2 = quo_1 | binOne16;
      
      wire rem_div_comp;
      wire [15:0] rem_div_diff;
      assign rem_div_diff = rem_1 - i_divisor;
      assign rem_div_comp = (rem_1 < i_divisor) ? 1'b1 : 1'b0;
      assign rem_2 = rem_div_comp ? rem_1 : rem_div_diff;

      assign quo_3 = rem_div_comp ? quo_1 : quo_2;
      
      assign o_dividend = i_dividend<<1;

      assign o_remainder = quo_ind ? 16'b0 : rem_2;

      assign o_quotient = quo_ind ? 16'b0 : quo_3;


endmodule