/* TODO: INSERT NAME AND PENNKEY HERE */

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals 
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits collectively generate a carry (ignoring cin)
 * @param pout whether these 4 bits collectively would propagate an incoming carry (ignoring cin)
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);
   wire g10, p10, g32, p32, p30, g30, c1, c2, c3, c4;

	//compute generate/propogate signal for the first two bits of gin and
	//pin in order to compute c1
	assign g10 = gin[1] | (pin[1] & gin[0]);
	assign p10 = pin[1] & pin[0];
	assign c1 = gin[0] | (pin[0] & cin);

	//compute generate/propogate signal for the second two bits of gin and
	//pin but we cant compute c3 until we compute c2 so we compute c2 from
	//p10 and g10 signals before
	assign g32 = gin[3] | (pin[3] & gin[2]);
	assign p32 = pin[3] & pin[2];

	//compute generate/propogate signal for the first 4 bits of gin and
	//pin given c2, the carry for the first 2 bits
	assign p30 = p32 & p10;
	assign g30 = g32 | (p32 & g10);

	assign c2 = g10 | (p10 & cin);
	assign c3 = gin[2] | (pin[2] & c2);

	//compute c4 using whether or not the first 4 bits generated at carry
	//or if there was a propogation from the first 4 bits an cin is true
	assign cout[0] = c1;
	assign cout[1] = c2;
	assign cout[2] = c3;
	assign gout = g30;
	assign pout = p30;
endmodule

/**
 * 16-bit Carry-Lookahead Adder
 * @param a first input
 * @param b second input
 * @param cin carry in
 * @param sum sum of a + b + carry-in
 */
module cla16
  (input wire [15:0]  a, b,
   input wire         cin,
   output wire [15:0] sum);

   wire [15:0] g, p;
	wire [17:0] c;
	assign c[0] = cin;

	genvar i;
	for(i=0;i<16;i=i+1) begin
		gp1 add2bits(.a(a[i]), .b(b[i]), .g(g[i]), .p(p[i]));
	end
	
	wire g30, p30, g74, p74, g118, p118, g1512, p1512;
	gp4 a30(.gin(g[3:0]), .pin(p[3:0]), .cin(cin), .gout(g30), .pout(p30), .cout(c[3:1]));
	gp4 a74(.gin(g[7:4]), .pin(p[7:4]), .cin(c[4]), .gout(g74), .pout(p74), .cout(c[7:5]));
	gp4 a118(.gin(g[11:8]), .pin(p[11:8]), .cin(c[8]), .gout(g118), .pout(p118), .cout(c[11:9]));
	gp4 a1512(.gin(g[15:12]), .pin(p[15:12]), .cin(c[12]), .gout(g1512), .pout(p1512), .cout(c[15:13]));
	
	wire g70, p70, g158, p158, g150, p150;
	assign g70 = g74 | (p74 & g30);
	assign p70 = p74 & p30;

	assign c[4] = g30 | (p30 & cin);
	assign c[8] = g70 | (p70 & cin);

	assign c[12] = g118 | (p118 & c[8]);

	assign g158 = g1512 | (p1512 & g118);
	assign p158 = p1512 & p118;

	assign g150 = g158 | (p158 & g70);
	assign p150 = p158 & p70;

	assign c[16] = g150 | (p150 & cin);

	genvar j;
	for (j=0;j<16;j=j+1) begin
		assign sum[j] = a[j] ^ b[j] ^ c[j];
	end

endmodule


/** Lab 2 Extra Credit, see details at
  https://github.com/upenn-acg/cis501/blob/master/lab2-alu/lab2-cla.md#extra-credit
 If you are not doing the extra credit, you should leave this module empty.
 */
module gpn
  #(parameter N = 4)
  (input wire [N-1:0] gin, pin,
   input wire  cin,
   output wire gout, pout,
   output wire [N-2:0] cout);
 
endmodule
