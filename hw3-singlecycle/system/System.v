module MyClockGen (
	input_clk_25MHz,
	clk_proc,
	clk_mem,
	locked
);
	input input_clk_25MHz;
	output wire clk_proc;
	output wire clk_mem;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "4.16667" *) (* FREQUENCY_PIN_CLKOS = "4.01003" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
		.PLLRST_ENA("DISABLED"),
		.INTFB_WAKE("DISABLED"),
		.STDBY_ENABLE("DISABLED"),
		.DPHASE_SOURCE("DISABLED"),
		.OUTDIVIDER_MUXA("DIVA"),
		.OUTDIVIDER_MUXB("DIVB"),
		.OUTDIVIDER_MUXC("DIVC"),
		.OUTDIVIDER_MUXD("DIVD"),
		.CLKI_DIV(6),
		.CLKOP_ENABLE("ENABLED"),
		.CLKOP_DIV(128),
		.CLKOP_CPHASE(64),
		.CLKOP_FPHASE(0),
		.CLKOS_ENABLE("ENABLED"),
		.CLKOS_DIV(133),
		.CLKOS_CPHASE(97),
		.CLKOS_FPHASE(2),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(1)
	) pll_i(
		.RST(1'b0),
		.STDBY(1'b0),
		.CLKI(input_clk_25MHz),
		.CLKOP(clk_proc),
		.CLKOS(clk_mem),
		.CLKFB(clkfb),
		.CLKINTFB(clkfb),
		.PHASESEL0(1'b0),
		.PHASESEL1(1'b0),
		.PHASEDIR(1'b1),
		.PHASESTEP(1'b1),
		.PHASELOADREG(1'b1),
		.PLLWAKESYNC(1'b0),
		.ENCLKOP(1'b0),
		.LOCK(locked)
	);
endmodule
module DividerUnsigned (
	i_dividend,
	i_divisor,
	o_remainder,
	o_quotient
);
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [1023:0] dividend_wires;
	wire [1023:0] remainder_wires;
	wire [1023:0] quotient_wires;
	DividerOneIter first_iter(
		.i_dividend(i_dividend),
		.i_divisor(i_divisor),
		.i_remainder(32'b00000000000000000000000000000000),
		.i_quotient(32'b00000000000000000000000000000000),
		.o_dividend(dividend_wires[31-:32]),
		.o_remainder(remainder_wires[31-:32]),
		.o_quotient(quotient_wires[31-:32])
	);
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 1; _gv_i_1 < 32; _gv_i_1 = _gv_i_1 + 1) begin : DIVIDER_LOOP
			localparam i = _gv_i_1;
			DividerOneIter one_iter(
				.i_dividend(dividend_wires[(32 * i) - 1-:32]),
				.i_divisor(i_divisor),
				.i_remainder(remainder_wires[(32 * i) - 1-:32]),
				.i_quotient(quotient_wires[(32 * i) - 1-:32]),
				.o_dividend(dividend_wires[(32 * (i + 1)) - 1-:32]),
				.o_remainder(remainder_wires[(32 * (i + 1)) - 1-:32]),
				.o_quotient(quotient_wires[(32 * (i + 1)) - 1-:32])
			);
		end
	endgenerate
	assign o_remainder = remainder_wires[1023-:32];
	assign o_quotient = quotient_wires[1023-:32];
endmodule
module DividerOneIter (
	i_dividend,
	i_divisor,
	i_remainder,
	i_quotient,
	o_dividend,
	o_remainder,
	o_quotient
);
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	input wire [31:0] i_remainder;
	input wire [31:0] i_quotient;
	output wire [31:0] o_dividend;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [31:0] r_temp1 = (i_remainder << 1) | ((i_dividend >> 31) & 32'b00000000000000000000000000000001);
	wire lt_temp1 = (r_temp1 < i_divisor ? 1'b1 : 1'b0);
	assign o_quotient = (lt_temp1 ? i_quotient << 1 : (i_quotient << 1) | 32'b00000000000000000000000000000001);
	assign o_remainder = (lt_temp1 ? r_temp1 : r_temp1 - i_divisor);
	assign o_dividend = i_dividend << 1;
endmodule
module gp1 (
	a,
	b,
	g,
	p
);
	input wire a;
	input wire b;
	output wire g;
	output wire p;
	assign g = a & b;
	assign p = a | b;
endmodule
module gp4 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [3:0] gin;
	input wire [3:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [2:0] cout;
	assign cout[0] = gin[0] | (pin[0] & cin);
	wire g10 = (gin[0] & pin[1]) | gin[1];
	assign cout[1] = ((cin & pin[0]) & pin[1]) | g10;
	assign cout[2] = (gin[2] | (pin[2] & g10)) | (((pin[2] & pin[1]) & pin[0]) & cin);
	assign pout = ((pin[0] & pin[1]) & pin[2]) & pin[3];
	wire g32 = (gin[2] & pin[3]) | gin[3];
	assign gout = g32 | ((g10 & pin[3]) & pin[2]);
endmodule
module gp8 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [7:0] gin;
	input wire [7:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [6:0] cout;
	wire g30;
	wire p30;
	wire g74;
	wire p74;
	wire [2:0] c31;
	wire [2:0] c74;
	gp4 lower(
		.gin(gin[3:0]),
		.pin(pin[3:0]),
		.cin(cin),
		.gout(g30),
		.pout(p30),
		.cout(c31)
	);
	assign cout[3] = g30 | (p30 & cin);
	gp4 upper(
		.gin(gin[7:4]),
		.pin(pin[7:4]),
		.cin(g30 | (p30 & cin)),
		.gout(g74),
		.pout(p74),
		.cout(c74)
	);
	assign cout[0] = c31[0];
	assign cout[1] = c31[1];
	assign cout[2] = c31[2];
	assign cout[4] = c74[0];
	assign cout[5] = c74[1];
	assign gout = (p74 & g30) | g74;
	assign pout = p30 & p74;
	assign cout[6] = c74[2];
endmodule
module CarryLookaheadAdder (
	a,
	b,
	cin,
	sum
);
	input wire [31:0] a;
	input wire [31:0] b;
	input wire cin;
	output wire [31:0] sum;
	wire [31:0] g;
	wire [31:0] p;
	wire [31:0] c;
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 0; _gv_i_2 < 32; _gv_i_2 = _gv_i_2 + 1) begin : gp_gen
			localparam i = _gv_i_2;
			gp1 gp_inst(
				.a(a[i]),
				.b(b[i]),
				.g(g[i]),
				.p(p[i])
			);
		end
	endgenerate
	wire g70;
	wire g158;
	wire g2316;
	wire g3124;
	wire p70;
	wire p158;
	wire p2316;
	wire p3124;
	assign c[0] = cin;
	gp8 lower8(
		.gin(g[7:0]),
		.pin(p[7:0]),
		.cin(cin),
		.gout(g70),
		.pout(p70),
		.cout(c[7:1])
	);
	assign c[8] = g70 | (p70 & cin);
	gp8 midlower8(
		.gin(g[15:8]),
		.pin(p[15:8]),
		.cin(g70 | (p70 & cin)),
		.gout(g158),
		.pout(p158),
		.cout(c[15:9])
	);
	assign c[16] = g158 | (p158 & (g70 | (p70 & cin)));
	gp8 midupper8(
		.gin(g[23:16]),
		.pin(p[23:16]),
		.cin(g158 | (p158 & (g70 | (p70 & cin)))),
		.gout(g2316),
		.pout(p2316),
		.cout(c[23:17])
	);
	assign c[24] = g2316 | (p2316 & (g158 | (p158 & (g70 | (p70 & cin)))));
	gp8 upper8(
		.gin(g[31:24]),
		.pin(p[31:24]),
		.cin(g2316 | (p2316 & (g158 | (p158 & (g70 | (p70 & cin)))))),
		.gout(g3124),
		.pout(p3124),
		.cout(c[31:25])
	);
	generate
		for (_gv_i_2 = 0; _gv_i_2 < 32; _gv_i_2 = _gv_i_2 + 1) begin : sum_gen
			localparam i = _gv_i_2;
			assign sum[i] = (a[i] ^ b[i]) ^ c[i];
		end
	endgenerate
endmodule
module RegFile (
	rd,
	rd_data,
	rs1,
	rs1_data,
	rs2,
	rs2_data,
	clk,
	we,
	rst
);
	input wire [4:0] rd;
	input wire [31:0] rd_data;
	input wire [4:0] rs1;
	output wire [31:0] rs1_data;
	input wire [4:0] rs2;
	output wire [31:0] rs2_data;
	input wire clk;
	input wire we;
	input wire rst;
	localparam signed [31:0] NumRegs = 32;
	reg [31:0] regs [0:31];
	always @(posedge clk)
		if (rst) begin : sv2v_autoblock_1
			integer i;
			for (i = 0; i < NumRegs; i = i + 1)
				regs[i] <= 1'sb0;
		end
		else if (we && (rd != 5'd0))
			regs[rd] <= rd_data;
	assign rs1_data = regs[rs1];
	assign rs2_data = regs[rs2];
endmodule
module DatapathSingleCycle (
	clk,
	rst,
	halt,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem,
	trace_completed_pc,
	trace_completed_insn,
	trace_completed_cycle_status
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	output reg halt;
	output wire [31:0] pc_to_imem;
	input wire [31:0] insn_from_imem;
	output reg [31:0] addr_to_dmem;
	input wire [31:0] load_data_from_dmem;
	output reg [31:0] store_data_to_dmem;
	output reg [3:0] store_we_to_dmem;
	output wire [31:0] trace_completed_pc;
	output wire [31:0] trace_completed_insn;
	output wire [31:0] trace_completed_cycle_status;
	wire [6:0] insn_funct7;
	wire [4:0] insn_rs2;
	wire [4:0] insn_rs1;
	wire [2:0] insn_funct3;
	wire [4:0] insn_rd;
	wire [6:0] insn_opcode;
	assign {insn_funct7, insn_rs2, insn_rs1, insn_funct3, insn_rd, insn_opcode} = insn_from_imem;
	wire [31:0] imm_u;
	assign imm_u = {insn_from_imem[31:12], 12'b000000000000};
	wire [11:0] imm_i;
	assign imm_i = insn_from_imem[31:20];
	wire [4:0] imm_shamt = insn_from_imem[24:20];
	wire [11:0] imm_s;
	assign imm_s[11:5] = insn_funct7;
	assign imm_s[4:0] = insn_rd;
	wire [12:0] imm_b;
	assign {imm_b[12], imm_b[10:5]} = insn_funct7;
	assign {imm_b[4:1], imm_b[11]} = insn_rd;
	assign imm_b[0] = 1'b0;
	wire [20:0] imm_j;
	assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {insn_from_imem[31:12], 1'b0};
	wire [31:0] imm_i_sext = {{20 {imm_i[11]}}, imm_i[11:0]};
	wire [31:0] imm_s_sext = {{20 {imm_s[11]}}, imm_s[11:0]};
	wire [31:0] imm_b_sext = {{19 {imm_b[12]}}, imm_b[12:0]};
	wire [31:0] imm_j_sext = {{11 {imm_j[20]}}, imm_j[20:0]};
	localparam [6:0] OpLoad = 7'b0000011;
	localparam [6:0] OpStore = 7'b0100011;
	localparam [6:0] OpBranch = 7'b1100011;
	localparam [6:0] OpJalr = 7'b1100111;
	localparam [6:0] OpMiscMem = 7'b0001111;
	localparam [6:0] OpJal = 7'b1101111;
	localparam [6:0] OpRegImm = 7'b0010011;
	localparam [6:0] OpRegReg = 7'b0110011;
	localparam [6:0] OpEnviron = 7'b1110011;
	localparam [6:0] OpAuipc = 7'b0010111;
	localparam [6:0] OpLui = 7'b0110111;
	wire insn_lui = insn_opcode == OpLui;
	wire insn_auipc = insn_opcode == OpAuipc;
	wire insn_jal = insn_opcode == OpJal;
	wire insn_jalr = insn_opcode == OpJalr;
	wire insn_beq = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b000);
	wire insn_bne = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b001);
	wire insn_blt = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b100);
	wire insn_bge = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b101);
	wire insn_bltu = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b110);
	wire insn_bgeu = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b111);
	wire insn_lb = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b000);
	wire insn_lh = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b001);
	wire insn_lw = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b010);
	wire insn_lbu = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b100);
	wire insn_lhu = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b101);
	wire insn_sb = (insn_opcode == OpStore) && (insn_from_imem[14:12] == 3'b000);
	wire insn_sh = (insn_opcode == OpStore) && (insn_from_imem[14:12] == 3'b001);
	wire insn_sw = (insn_opcode == OpStore) && (insn_from_imem[14:12] == 3'b010);
	wire insn_addi = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b000);
	wire insn_slti = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b010);
	wire insn_sltiu = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b011);
	wire insn_xori = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b100);
	wire insn_ori = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b110);
	wire insn_andi = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b111);
	wire insn_slli = ((insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b001)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_srli = ((insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_srai = ((insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'b0100000);
	wire insn_add = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b000)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_sub = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b000)) && (insn_from_imem[31:25] == 7'b0100000);
	wire insn_sll = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b001)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_slt = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b010)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_sltu = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b011)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_xor = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b100)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_srl = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_sra = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'b0100000);
	wire insn_or = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b110)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_and = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b111)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_mul = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b000);
	wire insn_mulh = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b001);
	wire insn_mulhsu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b010);
	wire insn_mulhu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b011);
	wire insn_div = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b100);
	wire insn_divu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b101);
	wire insn_rem = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b110);
	wire insn_remu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b111);
	wire insn_ecall = (insn_opcode == OpEnviron) && (insn_from_imem[31:7] == 25'd0);
	wire insn_fence = insn_opcode == OpMiscMem;
	reg [31:0] pcNext;
	reg [31:0] pcCurrent;
	always @(posedge clk)
		if (rst)
			pcCurrent <= 32'd0;
		else
			pcCurrent <= pcNext;
	assign pc_to_imem = pcCurrent;
	wire [31:0] pc_plus_4 = {pcCurrent[31:2] + 30'd1, 2'b00};
	reg [31:0] cycles_current;
	reg [31:0] num_insns_current;
	always @(posedge clk)
		if (rst) begin
			cycles_current <= 0;
			num_insns_current <= 0;
		end
		else begin
			cycles_current <= cycles_current + 1;
			if (!rst)
				num_insns_current <= num_insns_current + 1;
		end
	wire [31:0] rs1_data;
	wire [31:0] rs2_data;
	reg [31:0] rd_data;
	reg write_enable;
	RegFile rf(
		.clk(clk),
		.rst(rst),
		.we(write_enable),
		.rd(insn_rd),
		.rd_data(rd_data),
		.rs1(insn_rs1),
		.rs2(insn_rs2),
		.rs1_data(rs1_data),
		.rs2_data(rs2_data)
	);
	reg [31:0] adder_a;
	reg [31:0] adder_b;
	reg adder_cin;
	wire [31:0] adder_result;
	CarryLookaheadAdder general_adder(
		.a(adder_a),
		.b(adder_b),
		.cin(adder_cin),
		.sum(adder_result)
	);
	wire mul_sign_rs1 = ((insn_mul | insn_mulh) | insn_mulhsu) & rs1_data[31];
	wire mul_sign_rs2 = (insn_mul | insn_mulh) & rs2_data[31];
	wire signed [32:0] mul_op_a = {mul_sign_rs1, rs1_data};
	wire signed [32:0] mul_op_b = {mul_sign_rs2, rs2_data};
	wire signed [65:0] mul_result = mul_op_a * mul_op_b;
	reg [31:0] dividend;
	reg [31:0] divisor;
	wire [31:0] quotient;
	wire [31:0] remainder;
	DividerUnsigned div_unit(
		.i_dividend(dividend),
		.i_divisor(divisor),
		.o_quotient(quotient),
		.o_remainder(remainder)
	);
	wire [31:0] rs1_neg = ~rs1_data + 32'd1;
	wire [31:0] rs2_neg = ~rs2_data + 32'd1;
	wire [31:0] neg_quotient = ~quotient + 32'd1;
	wire [31:0] neg_remainder = ~remainder + 32'd1;
	reg [4:0] shifter_amount;
	reg shifter_right;
	reg shifter_arith;
	wire [31:0] shifter_reversed_in;
	genvar _gv_si_1;
	generate
		for (_gv_si_1 = 0; _gv_si_1 < 32; _gv_si_1 = _gv_si_1 + 1) begin : gen_shifter_rev_in
			localparam si = _gv_si_1;
			assign shifter_reversed_in[si] = rs1_data[31 - si];
		end
	endgenerate
	wire [31:0] shifter_input = (shifter_right ? rs1_data : shifter_reversed_in);
	wire [32:0] shifter_ext = {shifter_arith & shifter_input[31], shifter_input};
	wire [32:0] shifter_out_ext = $signed(shifter_ext) >>> shifter_amount;
	wire [31:0] shifter_out_raw = shifter_out_ext[31:0];
	wire [31:0] shifter_reversed_out;
	generate
		for (_gv_si_1 = 0; _gv_si_1 < 32; _gv_si_1 = _gv_si_1 + 1) begin : gen_shifter_rev_out
			localparam si = _gv_si_1;
			assign shifter_reversed_out[si] = shifter_out_raw[31 - si];
		end
	endgenerate
	reg illegal_insn;
	always @(*) begin
		if (_sv2v_0)
			;
		illegal_insn = 1'b0;
		write_enable = 1'b0;
		rd_data = 1'sb0;
		adder_a = 1'sb0;
		adder_b = 1'sb0;
		adder_cin = 1'b0;
		shifter_amount = 1'sb0;
		shifter_right = 1'b0;
		shifter_arith = 1'b0;
		addr_to_dmem = 1'sb0;
		store_data_to_dmem = 1'sb0;
		store_we_to_dmem = 4'b0000;
		dividend = 1'sb1;
		divisor = 1'sb1;
		halt = 1'b0;
		pcNext = pc_plus_4;
		case (insn_opcode)
			OpLui: begin
				write_enable = 1'b1;
				rd_data = imm_u;
			end
			OpAuipc: begin
				write_enable = 1'b1;
				adder_a = pcCurrent;
				adder_b = imm_u;
				rd_data = adder_result;
			end
			OpJal: begin
				write_enable = 1'b1;
				rd_data = pc_plus_4;
				adder_a = pcCurrent;
				adder_b = imm_j_sext;
				pcNext = adder_result;
			end
			OpJalr: begin
				write_enable = 1'b1;
				rd_data = pc_plus_4;
				adder_a = rs1_data;
				adder_b = imm_i_sext;
				pcNext = adder_result & ~32'b00000000000000000000000000000001;
			end
			OpRegImm:
				if (insn_addi) begin
					write_enable = 1'b1;
					adder_a = rs1_data;
					adder_b = imm_i_sext;
					rd_data = adder_result;
				end
				else if (insn_slti) begin
					write_enable = 1'b1;
					rd_data = ($signed(rs1_data) < $signed(imm_i_sext) ? 1 : 0);
				end
				else if (insn_sltiu) begin
					write_enable = 1'b1;
					rd_data = (rs1_data < imm_i_sext ? 1 : 0);
				end
				else if (insn_xori) begin
					write_enable = 1'b1;
					rd_data = rs1_data ^ imm_i_sext;
				end
				else if (insn_ori) begin
					write_enable = 1'b1;
					rd_data = rs1_data | imm_i_sext;
				end
				else if (insn_andi) begin
					write_enable = 1'b1;
					rd_data = rs1_data & imm_i_sext;
				end
				else if (insn_slli) begin
					write_enable = 1'b1;
					shifter_amount = imm_shamt;
					rd_data = shifter_reversed_out;
				end
				else if (insn_srli) begin
					write_enable = 1'b1;
					shifter_amount = imm_shamt;
					shifter_right = 1'b1;
					rd_data = shifter_out_raw;
				end
				else if (insn_srai) begin
					write_enable = 1'b1;
					shifter_amount = imm_shamt;
					shifter_right = 1'b1;
					shifter_arith = 1'b1;
					rd_data = shifter_out_raw;
				end
				else
					illegal_insn = 1'b1;
			OpRegReg:
				if (insn_add) begin
					write_enable = 1'b1;
					adder_a = rs1_data;
					adder_b = rs2_data;
					rd_data = adder_result;
				end
				else if (insn_sub) begin
					write_enable = 1'b1;
					adder_a = rs1_data;
					adder_b = ~rs2_data;
					adder_cin = 1'b1;
					rd_data = adder_result;
				end
				else if (insn_sll) begin
					write_enable = 1'b1;
					shifter_amount = rs2_data[4:0];
					rd_data = shifter_reversed_out;
				end
				else if (insn_slt) begin
					write_enable = 1'b1;
					rd_data = ($signed(rs1_data) < $signed(rs2_data) ? 1 : 0);
				end
				else if (insn_sltu) begin
					write_enable = 1'b1;
					rd_data = (rs1_data < rs2_data ? 1 : 0);
				end
				else if (insn_xor) begin
					write_enable = 1'b1;
					rd_data = rs1_data ^ rs2_data;
				end
				else if (insn_srl) begin
					write_enable = 1'b1;
					shifter_amount = rs2_data[4:0];
					shifter_right = 1'b1;
					rd_data = shifter_out_raw;
				end
				else if (insn_sra) begin
					write_enable = 1'b1;
					shifter_amount = rs2_data[4:0];
					shifter_right = 1'b1;
					shifter_arith = 1'b1;
					rd_data = shifter_out_raw;
				end
				else if (insn_or) begin
					write_enable = 1'b1;
					rd_data = rs1_data | rs2_data;
				end
				else if (insn_and) begin
					write_enable = 1'b1;
					rd_data = rs1_data & rs2_data;
				end
				else if (insn_mul) begin
					write_enable = 1'b1;
					rd_data = mul_result[31:0];
				end
				else if (insn_mulh) begin
					write_enable = 1'b1;
					rd_data = mul_result[63:32];
				end
				else if (insn_mulhsu) begin
					write_enable = 1'b1;
					rd_data = mul_result[63:32];
				end
				else if (insn_mulhu) begin
					write_enable = 1'b1;
					rd_data = mul_result[63:32];
				end
				else if (insn_div) begin
					write_enable = 1'b1;
					dividend = (rs1_data[31] ? rs1_neg : rs1_data);
					divisor = (rs2_data[31] ? rs2_neg : rs2_data);
					if (rs2_data != 0)
						rd_data = (rs1_data[31] ^ rs2_data[31] ? neg_quotient : quotient);
					else
						rd_data = 32'hffffffff;
				end
				else if (insn_divu) begin
					write_enable = 1'b1;
					dividend = rs1_data;
					divisor = rs2_data;
					if (rs2_data != 0)
						rd_data = quotient;
					else
						rd_data = 32'hffffffff;
				end
				else if (insn_rem) begin
					write_enable = 1'b1;
					dividend = (rs1_data[31] ? rs1_neg : rs1_data);
					divisor = (rs2_data[31] ? rs2_neg : rs2_data);
					if (rs2_data != 0)
						rd_data = (rs1_data[31] ? neg_remainder : remainder);
					else
						rd_data = rs1_data;
				end
				else if (insn_remu) begin
					write_enable = 1'b1;
					dividend = rs1_data;
					divisor = rs2_data;
					if (rs2_data != 0)
						rd_data = remainder;
					else
						rd_data = rs1_data;
				end
				else
					illegal_insn = 1'b1;
			OpLoad: begin
				adder_a = rs1_data;
				adder_b = imm_i_sext;
				if (insn_lb) begin
					write_enable = 1'b1;
					addr_to_dmem = {adder_result[31:2], 2'b00};
					case (adder_result[1:0])
						2'b00: rd_data = {{24 {load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
						2'b01: rd_data = {{24 {load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
						2'b10: rd_data = {{24 {load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
						2'b11: rd_data = {{24 {load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
					endcase
				end
				else if (insn_lh) begin
					write_enable = 1'b1;
					addr_to_dmem = {adder_result[31:2], 2'b00};
					case (adder_result[1])
						1'b0: rd_data = {{16 {load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
						1'b1: rd_data = {{16 {load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
					endcase
				end
				else if (insn_lw) begin
					write_enable = 1'b1;
					addr_to_dmem = {adder_result[31:2], 2'b00};
					rd_data = load_data_from_dmem;
				end
				else if (insn_lbu) begin
					write_enable = 1'b1;
					addr_to_dmem = {adder_result[31:2], 2'b00};
					case (adder_result[1:0])
						2'b00: rd_data = {24'b000000000000000000000000, load_data_from_dmem[7:0]};
						2'b01: rd_data = {24'b000000000000000000000000, load_data_from_dmem[15:8]};
						2'b10: rd_data = {24'b000000000000000000000000, load_data_from_dmem[23:16]};
						2'b11: rd_data = {24'b000000000000000000000000, load_data_from_dmem[31:24]};
					endcase
				end
				else if (insn_lhu) begin
					write_enable = 1'b1;
					addr_to_dmem = {adder_result[31:2], 2'b00};
					case (adder_result[1])
						1'b0: rd_data = {16'b0000000000000000, load_data_from_dmem[15:0]};
						1'b1: rd_data = {16'b0000000000000000, load_data_from_dmem[31:16]};
					endcase
				end
				else
					illegal_insn = 1'b1;
			end
			OpStore: begin
				adder_a = rs1_data;
				adder_b = imm_s_sext;
				if (insn_sb) begin
					addr_to_dmem = {adder_result[31:2], 2'b00};
					store_we_to_dmem = 4'b0001 << adder_result[1:0];
					store_data_to_dmem = {4 {rs2_data[7:0]}};
				end
				else if (insn_sh) begin
					addr_to_dmem = {adder_result[31:2], 2'b00};
					store_we_to_dmem = (adder_result[1] ? 4'b1100 : 4'b0011);
					store_data_to_dmem = {2 {rs2_data[15:0]}};
				end
				else if (insn_sw) begin
					addr_to_dmem = {adder_result[31:2], 2'b00};
					store_we_to_dmem = 4'b1111;
					store_data_to_dmem = rs2_data;
				end
				else
					illegal_insn = 1'b1;
			end
			OpBranch: begin
				adder_a = pcCurrent;
				adder_b = imm_b_sext;
				if (insn_beq) begin
					if (rs1_data == rs2_data)
						pcNext = adder_result;
				end
				else if (insn_bne) begin
					if (rs1_data != rs2_data)
						pcNext = adder_result;
				end
				else if (insn_blt) begin
					if ($signed(rs1_data) < $signed(rs2_data))
						pcNext = adder_result;
				end
				else if (insn_bge) begin
					if ($signed(rs1_data) >= $signed(rs2_data))
						pcNext = adder_result;
				end
				else if (insn_bltu) begin
					if (rs1_data < rs2_data)
						pcNext = adder_result;
				end
				else if (insn_bgeu) begin
					if (rs1_data >= rs2_data)
						pcNext = adder_result;
				end
				else
					illegal_insn = 1'b1;
			end
			OpEnviron:
				if (insn_ecall)
					halt = 1'b1;
				else
					illegal_insn = 1'b1;
			default: illegal_insn = 1'b1;
		endcase
	end
	assign trace_completed_pc = pcCurrent;
	assign trace_completed_insn = insn_from_imem;
	assign trace_completed_cycle_status = 32'd1;
	initial _sv2v_0 = 0;
endmodule
module MemorySingleCycle (
	rst,
	clock_mem,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem
);
	reg _sv2v_0;
	parameter signed [31:0] NUM_WORDS = 512;
	input wire rst;
	input wire clock_mem;
	input wire [31:0] pc_to_imem;
	output reg [31:0] insn_from_imem;
	input wire [31:0] addr_to_dmem;
	output reg [31:0] load_data_from_dmem;
	input wire [31:0] store_data_to_dmem;
	input wire [3:0] store_we_to_dmem;
	reg [31:0] mem_array [0:NUM_WORDS - 1];
	initial $readmemh("mem_initial_contents.hex", mem_array);
	always @(*)
		if (_sv2v_0)
			;
	localparam signed [31:0] AddrMsb = $clog2(NUM_WORDS) + 1;
	localparam signed [31:0] AddrLsb = 2;
	always @(posedge clock_mem)
		if (rst)
			;
		else
			insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
	always @(negedge clock_mem)
		if (rst)
			;
		else begin
			if (store_we_to_dmem[0])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
			if (store_we_to_dmem[1])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
			if (store_we_to_dmem[2])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
			if (store_we_to_dmem[3])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
			load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype none
module debouncer (
	i_clk,
	i_in,
	o_debounced,
	o_debug
);
	parameter NIN = 21;
	parameter LGWAIT = 17;
	input wire i_clk;
	input wire [NIN - 1:0] i_in;
	output reg [NIN - 1:0] o_debounced;
	output wire [30:0] o_debug;
	reg different;
	reg ztimer;
	reg [NIN - 1:0] r_in;
	reg [NIN - 1:0] q_in;
	reg [NIN - 1:0] r_last;
	reg [LGWAIT - 1:0] timer;
	initial q_in = 0;
	initial r_in = 0;
	initial different = 0;
	always @(posedge i_clk) q_in <= i_in;
	always @(posedge i_clk) r_in <= q_in;
	always @(posedge i_clk) r_last <= r_in;
	initial ztimer = 1'b1;
	initial timer = 0;
	always @(posedge i_clk)
		if (ztimer && different) begin
			timer <= {LGWAIT {1'b1}};
			ztimer <= 1'b0;
		end
		else if (!ztimer) begin
			timer <= timer - 1'b1;
			ztimer <= timer[LGWAIT - 1:1] == 0;
		end
		else begin
			ztimer <= 1'b1;
			timer <= 0;
		end
	always @(posedge i_clk) different <= (different && !ztimer) || (r_in != o_debounced);
	initial o_debounced = {NIN {1'b0}};
	always @(posedge i_clk)
		if (ztimer)
			o_debounced <= r_last;
	reg trigger;
	initial trigger = 1'b0;
	always @(posedge i_clk) trigger <= (((!ztimer && !different) && !(|i_in)) && (timer[LGWAIT - 1:2] == 0)) && timer[1];
	wire [30:0] debug;
	assign debug[30] = ztimer;
	assign debug[29] = trigger;
	assign debug[28] = 1'b0;
	generate
		if (NIN >= 14) begin : genblk1
			assign debug[27:14] = o_debounced[13:0];
			assign debug[13:0] = r_in[13:0];
		end
		else begin : genblk1
			assign debug[27:14 + NIN] = 0;
			assign debug[(14 + NIN) - 1:14] = o_debounced;
			assign debug[13:NIN] = 0;
			assign debug[NIN - 1:0] = r_in;
		end
	endgenerate
	assign o_debug = debug;
endmodule
module SystemDemo (
	external_clk_25MHz,
	btn,
	led
);
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output wire [7:0] led;
	localparam signed [31:0] MmapButtons = 32'hff001000;
	localparam signed [31:0] MmapLeds = 32'hff002000;
	wire rst_button_n;
	wire [30:0] ignore;
	wire clk_proc;
	debouncer #(.NIN(1)) db(
		.i_clk(clk_proc),
		.i_in(btn[0]),
		.o_debounced(rst_button_n),
		.o_debug(ignore)
	);
	wire clk_mem;
	wire clk_locked;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_proc(clk_proc),
		.clk_mem(clk_mem),
		.locked(clk_locked)
	);
	wire rst = !rst_button_n || !clk_locked;
	wire [31:0] pc_to_imem;
	wire [31:0] insn_from_imem;
	wire [31:0] mem_data_addr;
	wire [31:0] mem_data_loaded_value;
	wire [31:0] mem_data_to_write;
	wire [3:0] mem_data_we;
	reg [7:0] led_state;
	assign led = led_state;
	always @(posedge clk_mem)
		if (rst)
			led_state <= 0;
		else if ((mem_data_addr == MmapLeds) && (mem_data_we[0] == 1))
			led_state <= mem_data_to_write[7:0];
	MemorySingleCycle #(.NUM_WORDS(1024)) memory(
		.rst(rst),
		.clock_mem(clk_mem),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.load_data_from_dmem(mem_data_loaded_value),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem((mem_data_addr == MmapLeds ? 4'd0 : mem_data_we))
	);
	wire halt;
	DatapathSingleCycle datapath(
		.clk(clk_proc),
		.rst(rst),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we),
		.load_data_from_dmem((mem_data_addr == MmapButtons ? {25'd0, btn} : mem_data_loaded_value)),
		.halt(halt)
	);
endmodule