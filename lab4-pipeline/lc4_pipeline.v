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

   wire [2:0] nzp_in;
   wire [2:0] nzp; //nzp bits
   wire [2:0] rd;
   wire is_flush;

   wire[15:0] D_insn_in, D_insn_out, X_insn_in, X_insn_out, M_insn_in, M_insn_out, W_insn_in, W_insn_out, X_insn_sext;
   wire[15:0] rsdata, X_A_out, rtdata, X_B_out, M_O_in, M_O_out, M_B_in, M_B_out, W_O_in, W_O_out, W_D_in, W_D_out, rddata;
   wire [15:0] i_alu_r1data, i_alu_r2data; //inputs to ALU 
   wire[1:0] A_bypass_sel, B_bypass_sel; //assigned by bypass logic module
   wire WO_WD_sel, rddata_MB_sel, SX_B_sel; //assigned by bypass logic module
   wire[1:0] stall; //assigned by stall logic module

   //rs in [2:0], rt in [5:3], rd in [8:6]
   wire[8:0] d_rs_rt_rd;
   wire[8:0] x_rs_rt_rd;
   wire[8:0] m_rs_rt_rd;
   wire[8:0] w_rs_rt_rd;
   wire[8:0] f_rs_rt_rd;

   //rsre (8), rtre (7), regfilewe (6), nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)
   wire [8:0] d_bus;
   wire [8:0] x_bus;
   wire [8:0] m_bus;
   wire [8:0] w_bus;
   wire [8:0] f_bus;

   // pc wires attached to the PC register's ports
   wire [15:0] f_pc;      // Current program counter (read out from pc_reg)
   wire [15:0] d_pc; //defaults to pc+1
   wire [15:0] x_pc, x_pc_plus_one;
   wire [15:0] next_pc;

   wire[15:0] D_data, X_data, M_data, W_data;
   
   wire[1:0] dd_stall, xx_stall, mm_stall, ww_stall;

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) F_pc_reg (.in(next_pc), .out(f_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst || ww_stall == 2'b10));
   cla16 plusone(.a(f_pc), .b(16'b0), .cin(1'b1), .sum(next_pc)); //assume the next instruction for the current decoded insn is pc + 1

   //PIPELINE STARTS HERE	
   cla16 x_incr(.a(x_pc), .b(16'b0), .cin(1'b1), .sum(x_pc_plus_one)); //assume the next instruction for the current decoded insn is pc + 1
   data_hazard stall_logic(.xis_load(x_bus[3]), .dis_store(d_bus[2]), .x_isbranch(x_bus[1]), .dr1(d_rs_rt_rd[2:0]), .i_x_pc_plus_one(x_pc_plus_one), .alu_out(M_O_in), 
				.dr2(d_rs_rt_rd[5:3]), .xw(d_rs_rt_rd[8:6]), .o_stall(stall));
   
   assign A_bypass_sel = m_rs_rt_rd[8:6] == x_rs_rt_rd[2:0] ? 2'b10 : (w_rs_rt_rd[8:6] == x_rs_rt_rd[2:0] ? 2'b01 : 2'b00);
   assign B_bypass_sel = m_rs_rt_rd[8:6] == x_rs_rt_rd[5:3] ? 2'b10 : (w_rs_rt_rd[8:6] == x_rs_rt_rd[5:3] ? 2'b01 : 2'b00);
   assign WO_WD_sel = w_bus[3];
   assign rddata_MB_sel = (w_bus[3] && m_bus[2]) && (w_rs_rt_rd[8:6] == m_rs_rt_rd[5:3]);
   assign SX_B_sel = 1'b0;

   assign is_flush = xx_stall == 2'b10;

   //BEGIN DECODE STAGE
   assign nzp_in[2] = rddata[15];
   assign nzp_in[1] = &(~rddata);
   assign nzp_in[0] = ~rddata[15] && (|rddata);
   Nbit_reg #(3) nzpreg(.in(nzp_in), .out(nzp), .clk(clk), .we(d_bus[5]), .gwe(gwe), .rst(rst));
   //if stall == 2'b11 we want to write back in the instruction otherwise read in the current instruction
   Nbit_reg #(16, 16'b0) D_insn_reg(.in(stall == 2'b11 ? D_insn_out : i_cur_insn), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(D_insn_out));
   
   lc4_decoder dec(.insn(stall == 2'b11 ? D_insn_out : i_cur_insn), .r1sel(f_rs_rt_rd[2:0]), .r1re(f_bus[8]),
           .r2sel(f_rs_rt_rd[5:3]), .r2re(f_bus[7]), .wsel(f_rs_rt_rd[8:6]), .regfile_we(f_bus[6]),
           .nzp_we(f_bus[5]), .select_pc_plus_one(f_bus[4]), .is_load(f_bus[3]),
           .is_store(f_bus[2]), .is_branch(f_bus[1]), .is_control_insn(f_bus[0]));


   Nbit_reg #(9, 9'b0) D_rs_rt_rd_reg(.in(f_rs_rt_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(d_rs_rt_rd));
   Nbit_reg #(16, 16'b0) D_pc_reg (.in(f_pc), .out(d_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(9, 9'b0) D_bus_reg(.in(f_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(d_bus));
   Nbit_reg #(2, 2'b10) D_stall(.in(stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(dd_stall));
   Nbit_reg #(16, 16'b0) D_data_reg(.in(i_cur_dmem_data), .out(D_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   //END DECODE STAGE



   //BEGIN EXECUTE STAGE
   assign X_insn_in = stall == 2'b11 || stall == 2'b10 ? 16'b0  : D_insn_out; //if data_hazard module returns 2'b11 then we pass nop to execute in order to stall
   
   lc4_regfile registerfile(.clk(clk), .gwe(gwe), .rst(rst),
           .i_rs(w_rs_rt_rd[2:0]), .o_rs_data(rsdata), .i_rt(w_rs_rt_rd[5:3]),
           .o_rt_data(rtdata), .i_rd(rd), .i_wdata(rddata), .i_rd_we(w_bus[6]));  

   Nbit_reg #(16, 16'b0) X_insn_reg(.in(X_insn_in), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(X_insn_out)); 
   Nbit_reg #(16, 16'b0) X_A_reg(.in(rsdata), .clk(clk), .we(x_bus[8]), .gwe(gwe), .rst(is_flush || rst), .out(X_A_out)); //Holds rsdata that comes out of register file
   Nbit_reg #(16, 16'b0) X_B_reg(.in(rtdata), .clk(clk), .we(x_bus[7]), .gwe(gwe), .rst(is_flush || rst), .out(X_B_out)); //Holds rtdata that comes out of register file
   Nbit_reg #(9, 9'b0) X_rs_rt_rd_reg(.in(d_rs_rt_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(x_rs_rt_rd));
   Nbit_reg #(9, 9'b0) X_bus_reg(.in(d_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(x_bus));
   Nbit_reg #(16, 16'b0) X_pc_reg (.in(d_pc), .out(x_pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst));
   //i_alu_r1data and i_alu_r2data are assigned values in the beinning of the memory stage in order to evaluate bypassing and wired to ALU below
   lc4_alu alu (.i_insn(X_insn_in), .i_pc(x_pc), .i_r1data(i_alu_r1data), .i_r2data(i_alu_r2data), .o_result(M_O_in)); //ALU
  
   Nbit_reg #(2, 2'b10) X_stall(.in(dd_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(xx_stall));

   Nbit_reg #(16, 16'b0) X_data_reg(.in(D_data), .out(X_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst));
   //END EXECUTE STAGE



   //BEGIN MEMORY STAGE
   //B_bypass_sel values: 0 -> MX bypass, 1 -> WX bypass, otherwise no bypass (comes straight from X_B_reg)
   wire [15:0] B_tmp = B_bypass_sel == 2'b00 ? M_O_out : (B_bypass_sel == 2'b01 ? rddata : X_B_out);
   //A_bypass_sel values: 0 -> MX bypass, 1 -> WX bypass, otherwise no bypass (comes straight from X_A_reg)
   assign i_alu_r1data = A_bypass_sel == 2'b00 ? M_O_out : (A_bypass_sel == 2'b01 ? rddata : X_A_out);
   assign i_alu_r2data = B_tmp;
   assign M_B_in = i_alu_r2data;

   Nbit_reg #(16, 16'b0) M_insn_reg(.in(X_insn_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(M_insn_out));
   Nbit_reg #(16, 16'b0) M_O_reg(.in(M_O_in), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(M_O_out)); //Holds dmem data
   Nbit_reg #(16, 16'b0) M_B_reg(.in(M_B_in), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(M_B_out)); //Holds dmem address 
   Nbit_reg #(9, 9'b0) M_rs_rt_rd_reg(.in(x_rs_rt_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(m_rs_rt_rd));
   Nbit_reg #(9, 9'b0) M_bus_reg(.in(x_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst), .out(m_bus));

   Nbit_reg #(2, 2'b10) M_stall(.in(xx_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(mm_stall));

   Nbit_reg #(16, 16'b0) M_data_reg(.in(X_data), .out(M_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst));
   //END MEMORY STAGE


   
   //BEGIN WRITE STAGE
   assign o_dmem_towrite = rddata_MB_sel ? M_B_out : rddata; //where rddata_MB_sel is evaluated using bypass logic control
   assign W_O_in = M_O_out;
   assign W_D_in = M_data; //given to us as the output of data memory

   Nbit_reg #(16, 16'b0) W_insn_reg(.in(M_insn_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(W_insn_out)); 
   Nbit_reg #(16, 16'b0) W_O_register(.in(W_O_in), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(W_O_out));
   Nbit_reg #(16, 16'b0) W_D_register(.in(W_D_in), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(W_D_out));
   Nbit_reg #(9, 9'b0) W_rs_rt_rd_reg(.in(m_rs_rt_rd), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(w_rs_rt_rd));
   Nbit_reg #(9, 9'b0) W_bus_reg(.in(m_bus), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(w_bus));
   
   assign rddata = WO_WD_sel ? W_D_out : W_O_out; //where WO_WD_sel is found based on bypass control logic
   assign rd = w_rs_rt_rd[8:6]; //this is most likely incorrect

   Nbit_reg #(2, 2'b10) W_stall(.in(mm_stall), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst), .out(ww_stall));
   
   Nbit_reg #(16, 16'b0) W_data_reg(.in(M_data), .out(W_data), .clk(clk), .we(1'b1), .gwe(gwe), .rst(is_flush || rst));
   //END WRITE STAGE
   
   //PIPELINE ENDS HERE


   //SET OUTPUTS
   assign o_dmem_we = m_bus[2]; //if store instruction is in M stage is the only time we write to memory;          // Data memory write enable
   assign o_dmem_addr = M_O_out;        // Address to read/write from/to data memory; SET TO 0x0000 FOR NON LOAD/STORE INSNS
   assign o_dmem_towrite = rddata_MB_sel ? M_B_out : rddata; 
   assign o_cur_pc = is_flush ? M_O_in : f_pc;

   //SET TESTING PINS - 
   //for reference rsre (8), rtre (7), regfilewe (6),
   //nzpwe (5), selectpcplusone (4), isload (3), isstore (2), isbranch (1), iscontrolinsn (0)
   //rs in [2:0], rt in [5:3], rd in [8:6]
   assign test_regfile_we = w_bus[6];    // Testbench: register file write enable
   assign test_regfile_wsel = w_rs_rt_rd[8:6];  // Testbench: which register to write in the register file
   assign test_regfile_data = rddata;  // Testbench: value to write into the register file
   assign test_nzp_we = w_bus[5];     // Testbench: NZP condition codes write enable
   assign test_nzp_new_bits = nzp_in;  // Testbench: value to write to NZP bits
   assign test_dmem_we = o_dmem_we;       // Testbench: data memory write enable
   assign test_dmem_addr = o_dmem_addr;     // Testbench: address to read/write memory
   assign test_dmem_data = o_dmem_towrite;     // Testbench: value read/writen from/to memory 
   assign test_stall = ww_stall; // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_cur_pc = o_cur_pc; 
   assign test_cur_insn = i_cur_insn; 

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
      $display("%d CURR_PC=%h, D_INSN=%h X_INSN=%h, M_INSN=%h, W_INSN=%h", $time, f_pc, D_insn_out, X_insn_out, M_insn_out, W_insn_out);

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

module data_hazard(input wire xis_load, input wire dis_store, input wire x_isbranch, input wire [15:0] alu_out, input wire[15:0] i_x_pc_plus_one,
	input wire[2:0] dr1, input wire[2:0] dr2, input wire[2:0] xw, output wire[1:0] o_stall);

	wire is_load_to_use = xis_load && (dr1 == xw || (dr2 == xw && (~dis_store))) ? 1'b1 : 1'b0;	
	wire superscalar = 1'b0;
	wire flush = (x_isbranch && ~(i_x_pc_plus_one == alu_out));
	assign o_stall = is_load_to_use ? 2'b11 : (superscalar ? 2'b01 : (flush ? 2'b10 : 2'b00));

endmodule //end of data_hazard module