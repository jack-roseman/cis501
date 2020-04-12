/* Ryan Telesca - ryashnic ... Jack Roseman - jackrose */

`timescale 1ns / 1ps

`default_nettype none

module lc4_alu(input wire [15:0] i_insn,
	       input wire [15:0] i_pc,
	       input wire [15:0] i_r1data,
	       input wire [15:0] i_r2data,
	       output wire [15:0] o_result);

       wire [15:0] o_sext;
       wire [15:0] lhs;
       wire [15:0] rhs;
       wire [15:0] o_cla16;
       wire [15:0] o_logic;
       wire [15:0] o_cmp;
       wire [15:0] o_shift;
       wire [15:0] remainder;
       wire [15:0] quotient;
       wire [15:0] o_arith;
       wire [15:0] o_jsr;
       wire [3:0] opcode = i_insn[15:12];

       lc4_divider divide(.i_dividend(i_r1data), .i_divisor(i_r2data), .o_remainder(remainder), .o_quotient(quotient));

       sign_ext s0(.i_inst(i_insn), .o_sext(o_sext));

       lhs left(.i_pc(i_pc), .i_r1data(i_r1data), .i_insn(i_insn), .o_lhs(lhs));
       rhs right(.i_r2data(i_r2data), .i_insn(i_insn), .i_sext(o_sext), .o_rhs(rhs));

       wire cin = (i_insn[15:12] == 4'b1100 | i_insn[15:12] == 4'b0000 | (i_insn[15:12] == 4'b0001 & i_insn[5:3] == 3'b010)) ? 1'b1 : 1'b0;

       //cla output - 0000 or 0110 or 0111
       cla16 adder(.a(lhs), .b(rhs), .cin(cin), .sum(o_cla16));
       
       //logic - 0101
       logic logical(.i_insn(i_insn), .i_rs(i_r1data), .i_rt(i_r2data), .i_sext(o_sext), .o_logic(o_logic));

       //hiconst - 1101
       wire [15:0] hi_const = (i_r1data & {{8'b0}, {8{1'b1}}}) | (o_sext << 8);
       //trap - 1111
       wire [15:0] trap = {1'b1, 15'b0} | o_sext;
       
       //compare - 0010
       cmp comparer(.i_insn(i_insn), .i_r1data(i_r1data), .i_r2data(i_r2data), .o_cmp(o_cmp));

       //shift - 1010
       shift shifter(.i_r1data(i_r1data), .i_remainder(remainder), .i_insn(i_insn), .i_sext(o_sext), .o_shift(o_shift));

       //arith - 0001
       arith math(.i_r1data(i_r1data), .i_r2data(i_r2data), .i_insn(i_insn), .i_cla16(o_cla16), .i_quotient(quotient), .o_arith(o_arith));

       //rti - 1000 just return i_r1data
       
       //jmp - 1100
       wire [15:0] o_jmp = i_insn[11] ? o_cla16 : i_r1data;

       //jsr - 0100
       jsr jsr_r(.i_pc(i_pc), .i_r1data(i_r1data), .i_insn(i_insn), .o_pc(o_jsr));

       //const - 1001
       wire [15:0] const = o_sext;

       assign o_result = (opcode == 4'b0000 | opcode == 4'b0110 | opcode == 4'b0111) ? o_cla16 : (opcode == 4'b0001 ? o_arith : (opcode == 4'b0010 ? o_cmp : (opcode == 4'b0100 ? o_jsr : (opcode == 4'b0101 ? o_logic : (opcode == 4'b1000 ? i_r1data : (opcode == 4'b1001 ? const : (opcode == 4'b1010 ? o_shift : (opcode == 4'b1100 ? o_jmp : (opcode == 4'b1101 ? hi_const : (opcode == 4'b1111 ? trap : 16'b0))))))))));

endmodule

module jsr(input wire [15:0] i_pc,
           input wire [15:0] i_r1data,
           input wire [15:0] i_insn,
           output wire [15:0] o_pc);

   assign o_pc = (!i_insn[11]) ? i_r1data : ((i_pc & 16'h8000) | (i_insn[10:0] << 4));
endmodule

module lhs(input wire [15:0] i_pc,
           input wire [15:0] i_r1data,
           input wire [15:0] i_insn,
           output wire [15:0] o_lhs);

   assign o_lhs = (i_insn[15:12] == 4'b0000 | i_insn[15:12] == 4'b1100 | i_insn[15:12] == 4'b0100) ? i_pc : i_r1data;

endmodule

module rhs(input wire [15:0] i_r2data,
           input wire [15:0] i_insn,
           input wire [15:0] i_sext,
           output wire [15:0] o_rhs);

   assign o_rhs = (i_insn[15:12] == 4'b0000 | i_insn[15:12] == 4'b0110 | i_insn[15:12] == 4'b0111 | i_insn[15:12] == 4'b1100) ? i_sext : (i_insn[15:12] == 4'b0001 ? (i_insn[5:3] == 3'b010 ? ~i_r2data : (i_insn[5] ? i_sext : i_r2data)) : 16'b0);

endmodule

module logic(input wire [15:0] i_insn,
             input wire [15:0] i_rs,
	     input wire [15:0] i_rt,
	     input wire [15:0] i_sext,
	     output wire [15:0] o_logic);

     wire [2:0] subOp = i_insn[5:3];
     
     assign o_logic = (subOp[2]) ? (i_rs & i_sext) : (subOp == 3'b000 ? (i_rs & i_rt) : (subOp == 3'b001 ? (~i_rs) : (subOp == 3'b010 ? i_rs | i_rt : (subOp == 3'b011 ? (i_rs ^ i_rt) : 16'b0))));
endmodule

module sign_ext(input wire [15:0] i_inst,
		output wire [15:0] o_sext);

	wire [3:0] opCode = i_inst[15:12];
	wire [15:0] imm9 = {{7{i_inst[8]}}, i_inst[8:0]};
	wire [15:0] imm6 = {{10{i_inst[5]}}, i_inst[5:0]};
	wire [15:0] imm5 = {{11{i_inst[4]}}, i_inst[4:0]};
	wire [15:0] imm11 = {{5{i_inst[10]}}, i_inst[10:0]};
	wire [15:0] imm8 = {8'b0, i_inst[7:0]};
	wire [15:0] imm4 = {12'b0, i_inst[3:0]};

	assign o_sext = (opCode == 4'b0000 | opCode == 4'b1001) ? imm9 : ((opCode == 4'b0110) | (opCode == 4'b0111) ? imm6 : ((opCode == 4'b0001) | (opCode == 4'b0101) ? imm5 : ((opCode == 4'b0100 | opCode == 4'b1100) ? imm11 : ((opCode == 4'b1101) | (opCode == 4'b1111) ? imm8 : (opCode == 4'b1010 ? imm4 : 16'b0)))));

endmodule

module shift(input wire [15:0] i_r1data,
	     input wire [15:0] i_remainder,
	     input wire [15:0] i_insn,
	     input wire [15:0] i_sext,
	     output wire [15:0] o_shift);

     wire [15:0] sra = i_r1data[15] ? ((~(16'b1111111111111111 >> i_sext)) | (i_r1data >> i_sext)) : (i_r1data >> i_sext);
     assign o_shift = i_insn[5:4] == 2'b00 ? i_r1data << i_sext : (i_insn[5:4] == 2'b01 ? sra : (i_insn[5:4] == 2'b10 ? i_r1data >> i_sext : (i_insn[5:4] == 2'b11 ? i_remainder : 16'b0)));

endmodule

module cmp(input wire [15:0] i_insn,
           input wire [15:0] i_r1data,
           input wire [15:0] i_r2data,
           output wire [15:0] o_cmp);

   wire signed [15:0] s_r1 = $signed(i_r1data);
   wire signed [15:0] s_r2 = $signed(i_r2data);
   wire signed [15:0] imm7;
   wire [15:0] uimm7;
   wire [15:0] zero = 16'b0;
   wire [15:0] one = {{15'b0}, {1'b1}};
   wire [15:0] negOne = {16{1'b1}};

   assign imm7 = {{9{i_insn[6]}}, i_insn[6:0]};

   assign uimm7 = {{9'b0}, i_insn[6:0]};

   assign o_cmp = (i_insn[8:7] == 2'b00) ? (s_r1 <= s_r2 ? (s_r1 == s_r2 ? zero : negOne) : one) : ((i_insn[8:7] == 2'b01) ? (i_r1data <= i_r2data ? (i_r1data == i_r2data ? zero : negOne) : one) : ((i_insn[8:7] == 2'b10) ? (s_r1 <= imm7 ? (s_r1 == imm7 ? zero : negOne) : one) : ((i_insn[8:7] == 2'b11) ? (i_r1data <= uimm7 ? (i_r1data == uimm7 ? zero : negOne) : one) : zero)));


endmodule

module arith(input wire [15:0] i_r1data,
	     input wire [15:0] i_r2data,
	     input wire [15:0] i_insn,
	     input wire [15:0] i_cla16,
	     input wire [15:0] i_quotient,
	     output wire [15:0] o_arith);

     assign o_arith = (i_insn[5:3] == 3'b000 | i_insn[5:3] == 3'b010 | i_insn[5]) ? i_cla16 : (i_insn[5:3] == 3'b001 ? i_r1data * i_r2data : (i_insn[5:3] == 3'b011 ? i_quotient : 16'b0));
endmodule