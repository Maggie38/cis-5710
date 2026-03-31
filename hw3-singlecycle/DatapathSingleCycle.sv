
`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31:0

// insns are 32 bits in RV32IM
`define INSN_SIZE 31:0

// RV opcodes are 7 bits
`define OPCODE_SIZE 6:0

`include "../hw2a-divider/DividerUnsigned.sv"
`include "../hw2b-cla/CarryLookaheadAdder.sv"
`include "cycle_status.sv"

module RegFile (
    input logic [4:0] rd,
    input logic [`REG_SIZE] rd_data,
    input logic [4:0] rs1,
    output logic [`REG_SIZE] rs1_data,
    input logic [4:0] rs2,
    output logic [`REG_SIZE] rs2_data,

    input logic clk,
    input logic we,
    input logic rst
);
  localparam int NumRegs = 32;
  logic [`REG_SIZE] regs[NumRegs];

  always_ff @(posedge clk) begin
    // Reset all registers to 0 on rst
    if (rst) begin
      integer i;
      for (i = 0; i < NumRegs; i = i + 1) begin
        regs[i] <= '0;
      end
      // Write to register rd, discard x0
    end else if (we && rd != 5'd0) begin
      regs[rd] <= rd_data;
    end
  end

  // Read from registers rs1 and rs2
  assign rs1_data = regs[rs1];
  assign rs2_data = regs[rs2];

endmodule

module DatapathSingleCycle (
    input  wire               clk,
    input  wire               rst,
    output logic              halt,
    output logic [ `REG_SIZE] pc_to_imem,
    input  wire  [`INSN_SIZE] insn_from_imem,
    // addr_to_dmem is used for both loads and stores
    output logic [ `REG_SIZE] addr_to_dmem,
    input  logic [ `REG_SIZE] load_data_from_dmem,
    output logic [ `REG_SIZE] store_data_to_dmem,
    output logic [       3:0] store_we_to_dmem,

    // the PC of the insn executing in the current cycle
    output logic          [ `REG_SIZE] trace_completed_pc,
    // the machine code of the insn executing in the current cycle
    output logic          [`INSN_SIZE] trace_completed_insn,
    // the cycle status of the current cycle: should always be CYCLE_NO_STALL
    output cycle_status_e              trace_completed_cycle_status
);

  // components of the instruction
  wire [6:0] insn_funct7;
  wire [4:0] insn_rs2;
  wire [4:0] insn_rs1;
  wire [2:0] insn_funct3;
  wire [4:0] insn_rd;
  wire [`OPCODE_SIZE] insn_opcode;

  // split R-type instruction - see section 2.2 of RiscV spec
  assign {insn_funct7, insn_rs2, insn_rs1, insn_funct3, insn_rd, insn_opcode} = insn_from_imem;

  // setup for U, I, S, B & J type instructions
  // U - upper immediate
  wire [31:0] imm_u;
  assign imm_u = {insn_from_imem[31:12], 12'b0};

  // I - short immediates and loads
  wire [11:0] imm_i;
  assign imm_i = insn_from_imem[31:20];
  wire [ 4:0] imm_shamt = insn_from_imem[24:20];

  // S - stores
  wire [11:0] imm_s;
  assign imm_s[11:5] = insn_funct7, imm_s[4:0] = insn_rd;

  // B - conditionals
  wire [12:0] imm_b;
  assign {imm_b[12], imm_b[10:5]} = insn_funct7, {imm_b[4:1], imm_b[11]} = insn_rd, imm_b[0] = 1'b0;

  // J - unconditional jumps
  wire [20:0] imm_j;
  assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {
    insn_from_imem[31:12], 1'b0
  };

  wire [`REG_SIZE] imm_i_sext = {{20{imm_i[11]}}, imm_i[11:0]};
  wire [`REG_SIZE] imm_s_sext = {{20{imm_s[11]}}, imm_s[11:0]};
  wire [`REG_SIZE] imm_b_sext = {{19{imm_b[12]}}, imm_b[12:0]};
  wire [`REG_SIZE] imm_j_sext = {{11{imm_j[20]}}, imm_j[20:0]};

  // opcodes - see section 19 of RiscV spec
  localparam bit [`OPCODE_SIZE] OpLoad = 7'b00_000_11;
  localparam bit [`OPCODE_SIZE] OpStore = 7'b01_000_11;
  localparam bit [`OPCODE_SIZE] OpBranch = 7'b11_000_11;
  localparam bit [`OPCODE_SIZE] OpJalr = 7'b11_001_11;
  localparam bit [`OPCODE_SIZE] OpMiscMem = 7'b00_011_11;
  localparam bit [`OPCODE_SIZE] OpJal = 7'b11_011_11;

  localparam bit [`OPCODE_SIZE] OpRegImm = 7'b00_100_11;
  localparam bit [`OPCODE_SIZE] OpRegReg = 7'b01_100_11;
  localparam bit [`OPCODE_SIZE] OpEnviron = 7'b11_100_11;

  localparam bit [`OPCODE_SIZE] OpAuipc = 7'b00_101_11;
  localparam bit [`OPCODE_SIZE] OpLui = 7'b01_101_11;

  wire insn_lui = insn_opcode == OpLui;
  wire insn_auipc = insn_opcode == OpAuipc;
  wire insn_jal = insn_opcode == OpJal;
  wire insn_jalr = insn_opcode == OpJalr;

  wire insn_beq = insn_opcode == OpBranch && insn_from_imem[14:12] == 3'b000;
  wire insn_bne = insn_opcode == OpBranch && insn_from_imem[14:12] == 3'b001;
  wire insn_blt = insn_opcode == OpBranch && insn_from_imem[14:12] == 3'b100;
  wire insn_bge = insn_opcode == OpBranch && insn_from_imem[14:12] == 3'b101;
  wire insn_bltu = insn_opcode == OpBranch && insn_from_imem[14:12] == 3'b110;
  wire insn_bgeu = insn_opcode == OpBranch && insn_from_imem[14:12] == 3'b111;

  wire insn_lb = insn_opcode == OpLoad && insn_from_imem[14:12] == 3'b000;
  wire insn_lh = insn_opcode == OpLoad && insn_from_imem[14:12] == 3'b001;
  wire insn_lw = insn_opcode == OpLoad && insn_from_imem[14:12] == 3'b010;
  wire insn_lbu = insn_opcode == OpLoad && insn_from_imem[14:12] == 3'b100;
  wire insn_lhu = insn_opcode == OpLoad && insn_from_imem[14:12] == 3'b101;

  wire insn_sb = insn_opcode == OpStore && insn_from_imem[14:12] == 3'b000;
  wire insn_sh = insn_opcode == OpStore && insn_from_imem[14:12] == 3'b001;
  wire insn_sw = insn_opcode == OpStore && insn_from_imem[14:12] == 3'b010;

  wire insn_addi = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b000;
  wire insn_slti = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b010;
  wire insn_sltiu = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b011;
  wire insn_xori = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b100;
  wire insn_ori = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b110;
  wire insn_andi = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b111;

  wire insn_slli = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b001 && insn_from_imem[31:25] == 7'd0;
  wire insn_srli = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b101 && insn_from_imem[31:25] == 7'd0;
  wire insn_srai = insn_opcode == OpRegImm && insn_from_imem[14:12] == 3'b101 && insn_from_imem[31:25] == 7'b0100000;

  wire insn_add  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b000 && insn_from_imem[31:25] == 7'd0;
  wire insn_sub  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b000 && insn_from_imem[31:25] == 7'b0100000;
  wire insn_sll  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b001 && insn_from_imem[31:25] == 7'd0;
  wire insn_slt  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b010 && insn_from_imem[31:25] == 7'd0;
  wire insn_sltu = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b011 && insn_from_imem[31:25] == 7'd0;
  wire insn_xor  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b100 && insn_from_imem[31:25] == 7'd0;
  wire insn_srl  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b101 && insn_from_imem[31:25] == 7'd0;
  wire insn_sra  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b101 && insn_from_imem[31:25] == 7'b0100000;
  wire insn_or   = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b110 && insn_from_imem[31:25] == 7'd0;
  wire insn_and  = insn_opcode == OpRegReg && insn_from_imem[14:12] == 3'b111 && insn_from_imem[31:25] == 7'd0;

  wire insn_mul    = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b000;
  wire insn_mulh   = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b001;
  wire insn_mulhsu = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b010;
  wire insn_mulhu  = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b011;
  wire insn_div    = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b100;
  wire insn_divu   = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b101;
  wire insn_rem    = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b110;
  wire insn_remu   = insn_opcode == OpRegReg && insn_from_imem[31:25] == 7'd1 && insn_from_imem[14:12] == 3'b111;

  wire insn_ecall = insn_opcode == OpEnviron && insn_from_imem[31:7] == 25'd0;
  wire insn_fence = insn_opcode == OpMiscMem;

  // this code is only for simulation, not synthesis
`ifndef SYNTHESIS
  `include "RvDisassembler.sv"
  string disasm_string;
  always_comb begin
    disasm_string = rv_disasm(insn_from_imem);
  end
  // HACK: get disasm_string to appear in GtkWave, which can apparently show only wire/logic...
  wire [(8*32)-1:0] disasm_wire;
  genvar i;
  for (i = 0; i < 32; i = i + 1) begin : gen_disasm
    assign disasm_wire[(((i+1))*8)-1:((i)*8)] = disasm_string[31-i];
  end
`endif

  // program counter
  logic [`REG_SIZE] pcNext, pcCurrent;
  always @(posedge clk) begin
    if (rst) begin
      pcCurrent <= 32'd0;
    end else begin
      pcCurrent <= pcNext;
    end
  end
  assign pc_to_imem = pcCurrent;
  wire [31:0] pc_plus_4 = {pcCurrent[31:2] + 30'd1, 2'b00};

  // cycle/insn_from_imem counters
  logic [`REG_SIZE] cycles_current, num_insns_current;
  always @(posedge clk) begin
    if (rst) begin
      cycles_current <= 0;
      num_insns_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
      if (!rst) begin
        num_insns_current <= num_insns_current + 1;
      end
    end
  end

  // NOTE: don't rename your RegFile instance as the tests expect it to be `rf`
  // you will need to edit the port connections, however.
  wire [`REG_SIZE] rs1_data;
  wire [`REG_SIZE] rs2_data;
  logic [`REG_SIZE] rd_data;
  logic write_enable;
  RegFile rf (
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

  // Single consolidated adder: used for add, sub, address calculation for
  // loads/stores/jumps, and branch target calculation
  logic [31:0] adder_a, adder_b;
  logic adder_cin;
  wire [31:0] adder_result;
  CarryLookaheadAdder general_adder (
      .a  (adder_a),
      .b  (adder_b),
      .cin(adder_cin),
      .sum(adder_result)
  );

  // Single consolidated multiplier: sign/zero-extend operands to 33 bits
  wire mul_sign_rs1 = (insn_mul | insn_mulh | insn_mulhsu) & rs1_data[31];
  wire mul_sign_rs2 = (insn_mul | insn_mulh) & rs2_data[31];
  wire signed [32:0] mul_op_a = {mul_sign_rs1, rs1_data};
  wire signed [32:0] mul_op_b = {mul_sign_rs2, rs2_data};
  wire signed [65:0] mul_result = mul_op_a * mul_op_b;

  // Single consolidated divider: take absolute values of operands,
  // then fix up signs of quotient/remainder at the end
  logic [31:0] dividend, divisor;
  wire [31:0] quotient, remainder;
  DividerUnsigned div_unit (
      .i_dividend (dividend),
      .i_divisor  (divisor),
      .o_quotient (quotient),
      .o_remainder(remainder)
  );
  wire [31:0] rs1_neg = ~rs1_data + 32'd1;
  wire [31:0] rs2_neg = ~rs2_data + 32'd1;
  wire [31:0] neg_quotient = ~quotient + 32'd1;
  wire [31:0] neg_remainder = ~remainder + 32'd1;

  // Unified barrel shifter: handles slli/srli/srai/sll/srl/sra
  // Left shifts use the reverse-shift-reverse trick to share a single right-shifter.
  logic [4:0] shifter_amount;
  logic shifter_right;
  logic shifter_arith;

  wire [31:0] shifter_reversed_in;
  genvar si;
  for (si = 0; si < 32; si = si + 1) begin : gen_shifter_rev_in
    assign shifter_reversed_in[si] = rs1_data[31-si];
  end

  wire [31:0] shifter_input = shifter_right ? rs1_data : shifter_reversed_in;
  wire [32:0] shifter_ext = {shifter_arith & shifter_input[31], shifter_input};
  wire [32:0] shifter_out_ext = $signed(shifter_ext) >>> shifter_amount;
  wire [31:0] shifter_out_raw = shifter_out_ext[31:0];

  wire [31:0] shifter_reversed_out;
  for (si = 0; si < 32; si = si + 1) begin : gen_shifter_rev_out
    assign shifter_reversed_out[si] = shifter_out_raw[31-si];
  end

  logic illegal_insn;

  always_comb begin
    // Default values to satisfy always_comb
    illegal_insn = 1'b0;

    write_enable = 1'b0;

    rd_data = '0;

    adder_a = '0;
    adder_b = '0;
    adder_cin = 1'b0;

    shifter_amount = '0;
    shifter_right = 1'b0;
    shifter_arith = 1'b0;

    addr_to_dmem = '0;
    store_data_to_dmem = '0;
    store_we_to_dmem = 4'b0;

    dividend = '1;
    divisor = '1;

    halt = 1'b0;
    pcNext = pc_plus_4;  // Default PC update: go to next instruction

    case (insn_opcode)
      // Wide Immediate Instructions
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

      // Jump Instructions
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
        pcNext = adder_result & ~32'b1;
      end

      // Immediate ALU Instructions
      OpRegImm: begin
        if (insn_addi) begin  // Add
          write_enable = 1'b1;
          adder_a = rs1_data;
          adder_b = imm_i_sext;
          rd_data = adder_result;
        end else if (insn_slti) begin  // Comparison
          write_enable = 1'b1;
          rd_data = ($signed(rs1_data) < $signed(imm_i_sext)) ? 1 : 0;
        end else if (insn_sltiu) begin
          write_enable = 1'b1;
          rd_data = (rs1_data < imm_i_sext) ? 1 : 0;
        end else if (insn_xori) begin  // Logic
          write_enable = 1'b1;
          rd_data = rs1_data ^ imm_i_sext;
        end else if (insn_ori) begin
          write_enable = 1'b1;
          rd_data = rs1_data | imm_i_sext;
        end else if (insn_andi) begin
          write_enable = 1'b1;
          rd_data = rs1_data & imm_i_sext;
        end else if (insn_slli) begin  // Shift
          write_enable = 1'b1;
          shifter_amount = imm_shamt;
          rd_data = shifter_reversed_out;
        end else if (insn_srli) begin
          write_enable = 1'b1;
          shifter_amount = imm_shamt;
          shifter_right = 1'b1;
          rd_data = shifter_out_raw;
        end else if (insn_srai) begin
          write_enable = 1'b1;
          shifter_amount = imm_shamt;
          shifter_right = 1'b1;
          shifter_arith = 1'b1;
          rd_data = shifter_out_raw;
        end else begin
          illegal_insn = 1'b1;
        end
      end

      // Two Register ALU Instructions
      OpRegReg: begin
        if (insn_add) begin  // Add/Subtract
          write_enable = 1'b1;
          adder_a = rs1_data;
          adder_b = rs2_data;
          rd_data = adder_result;
        end else if (insn_sub) begin
          write_enable = 1'b1;
          adder_a = rs1_data;
          adder_b = ~rs2_data;
          adder_cin = 1'b1;
          rd_data = adder_result;

        end else if (insn_sll) begin  // Shift/Compare
          write_enable = 1'b1;
          shifter_amount = rs2_data[4:0];
          rd_data = shifter_reversed_out;
        end else if (insn_slt) begin
          write_enable = 1'b1;
          rd_data = ($signed(rs1_data) < $signed(rs2_data)) ? 1 : 0;
        end else if (insn_sltu) begin
          write_enable = 1'b1;
          rd_data = (rs1_data < rs2_data) ? 1 : 0;
        end else if (insn_xor) begin
          write_enable = 1'b1;
          rd_data = rs1_data ^ rs2_data;
        end else if (insn_srl) begin
          write_enable = 1'b1;
          shifter_amount = rs2_data[4:0];
          shifter_right = 1'b1;
          rd_data = shifter_out_raw;
        end else if (insn_sra) begin
          write_enable = 1'b1;
          shifter_amount = rs2_data[4:0];
          shifter_right = 1'b1;
          shifter_arith = 1'b1;
          rd_data = shifter_out_raw;

        end else if (insn_or) begin  // Logical
          write_enable = 1'b1;
          rd_data = rs1_data | rs2_data;
        end else if (insn_and) begin
          write_enable = 1'b1;
          rd_data = rs1_data & rs2_data;

        end else if (insn_mul) begin  // Multiplication
          write_enable = 1'b1;
          rd_data = mul_result[31:0];
        end else if (insn_mulh) begin
          write_enable = 1'b1;
          rd_data = mul_result[63:32];
        end else if (insn_mulhsu) begin
          write_enable = 1'b1;
          rd_data = mul_result[63:32];
        end else if (insn_mulhu) begin
          write_enable = 1'b1;
          rd_data = mul_result[63:32];

        end else if (insn_div) begin  // Division
          write_enable = 1'b1;
          dividend = rs1_data[31] ? rs1_neg : rs1_data;
          divisor = rs2_data[31] ? rs2_neg : rs2_data;
          if (rs2_data != 0) begin
            rd_data = (rs1_data[31] ^ rs2_data[31]) ? neg_quotient : quotient;
          end else begin
            rd_data = 32'hFFFF_FFFF;
          end
        end else if (insn_divu) begin
          write_enable = 1'b1;
          dividend = rs1_data;
          divisor = rs2_data;
          if (rs2_data != 0) begin
            rd_data = quotient;
          end else begin
            rd_data = 32'hFFFF_FFFF;
          end
        end else if (insn_rem) begin
          write_enable = 1'b1;
          dividend = rs1_data[31] ? rs1_neg : rs1_data;
          divisor = rs2_data[31] ? rs2_neg : rs2_data;
          if (rs2_data != 0) begin
            rd_data = rs1_data[31] ? neg_remainder : remainder;
          end else begin
            rd_data = rs1_data;
          end
        end else if (insn_remu) begin
          write_enable = 1'b1;
          dividend = rs1_data;
          divisor = rs2_data;
          if (rs2_data != 0) begin
            rd_data = remainder;
          end else begin
            rd_data = rs1_data;
          end

        end else begin
          illegal_insn = 1'b1;
        end
      end

      // Load instructions — address computed via CLA
      OpLoad: begin
        adder_a = rs1_data;
        adder_b = imm_i_sext;
        if (insn_lb) begin
          write_enable = 1'b1;
          addr_to_dmem = {adder_result[31:2], 2'b00};
          case (adder_result[1:0])
            2'b00: rd_data = {{24{load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
            2'b01: rd_data = {{24{load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
            2'b10: rd_data = {{24{load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
            2'b11: rd_data = {{24{load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
          endcase
        end else if (insn_lh) begin
          write_enable = 1'b1;
          addr_to_dmem = {adder_result[31:2], 2'b00};
          case (adder_result[1])
            1'b0: rd_data = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
            1'b1: rd_data = {{16{load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
          endcase
        end else if (insn_lw) begin
          write_enable = 1'b1;
          addr_to_dmem = {adder_result[31:2], 2'b00};
          rd_data = load_data_from_dmem;
        end else if (insn_lbu) begin
          write_enable = 1'b1;
          addr_to_dmem = {adder_result[31:2], 2'b00};
          case (adder_result[1:0])
            2'b00: rd_data = {24'b0, load_data_from_dmem[7:0]};
            2'b01: rd_data = {24'b0, load_data_from_dmem[15:8]};
            2'b10: rd_data = {24'b0, load_data_from_dmem[23:16]};
            2'b11: rd_data = {24'b0, load_data_from_dmem[31:24]};
          endcase
        end else if (insn_lhu) begin
          write_enable = 1'b1;
          addr_to_dmem = {adder_result[31:2], 2'b00};
          case (adder_result[1])
            1'b0: rd_data = {16'b0, load_data_from_dmem[15:0]};
            1'b1: rd_data = {16'b0, load_data_from_dmem[31:16]};
          endcase
        end else begin
          illegal_insn = 1'b1;
        end
      end

      // Store instructions — address computed via CLA
      OpStore: begin
        adder_a = rs1_data;
        adder_b = imm_s_sext;
        if (insn_sb) begin
          addr_to_dmem = {adder_result[31:2], 2'b00};
          store_we_to_dmem = 4'b0001 << adder_result[1:0];
          store_data_to_dmem = {4{rs2_data[7:0]}};
        end else if (insn_sh) begin
          addr_to_dmem = {adder_result[31:2], 2'b00};
          store_we_to_dmem = adder_result[1] ? 4'b1100 : 4'b0011;
          store_data_to_dmem = {2{rs2_data[15:0]}};
        end else if (insn_sw) begin
          addr_to_dmem = {adder_result[31:2], 2'b00};
          store_we_to_dmem = 4'b1111;
          store_data_to_dmem = rs2_data;
        end else begin
          illegal_insn = 1'b1;
        end
      end

      // Branch Instructions — target computed via CLA; default pcNext (pc+4) used if not taken
      OpBranch: begin
        adder_a = pcCurrent;
        adder_b = imm_b_sext;
        if (insn_beq) begin
          if (rs1_data == rs2_data) pcNext = adder_result;
        end else if (insn_bne) begin
          if (rs1_data != rs2_data) pcNext = adder_result;
        end else if (insn_blt) begin
          if ($signed(rs1_data) < $signed(rs2_data)) pcNext = adder_result;
        end else if (insn_bge) begin
          if ($signed(rs1_data) >= $signed(rs2_data)) pcNext = adder_result;
        end else if (insn_bltu) begin
          if (rs1_data < rs2_data) pcNext = adder_result;
        end else if (insn_bgeu) begin
          if (rs1_data >= rs2_data) pcNext = adder_result;
        end else begin
          illegal_insn = 1'b1;
        end
      end

      // Halt
      OpEnviron: begin
        if (insn_ecall) begin
          halt = 1'b1;
        end else begin
          illegal_insn = 1'b1;
        end
      end

      default: begin
        illegal_insn = 1'b1;
      end
    endcase
  end

  assign trace_completed_pc = pcCurrent;
  assign trace_completed_insn = insn_from_imem;
  assign trace_completed_cycle_status = CYCLE_NO_STALL;

endmodule

/* A memory module that supports 1-cycle reads and writes, with one read-only port
 * and one read+write port.
 */
module MemorySingleCycle #(
    parameter int NUM_WORDS = 512
) (
    // rst for both imem and dmem
    input wire rst,

    // clock for both imem and dmem. See RiscvProcessor for clock details.
    input wire clock_mem,

    // must always be aligned to a 4B boundary
    input wire [`REG_SIZE] pc_to_imem,

    // the value at memory location pc_to_imem
    output logic [`INSN_SIZE] insn_from_imem,

    // must always be aligned to a 4B boundary
    input wire [`REG_SIZE] addr_to_dmem,

    // the value at memory location addr_to_dmem
    output logic [`REG_SIZE] load_data_from_dmem,

    // the value to be written to addr_to_dmem, controlled by store_we_to_dmem
    input wire [`REG_SIZE] store_data_to_dmem,

    // Each bit determines whether to write the corresponding byte of store_data_to_dmem to memory location addr_to_dmem.
    // E.g., 4'b1111 will write 4 bytes. 4'b0001 will write only the least-significant byte.
    input wire [3:0] store_we_to_dmem
);

  // memory is arranged as an array of 4B words
  logic [`REG_SIZE] mem_array[NUM_WORDS];

`ifdef SYNTHESIS
  initial begin
    $readmemh("mem_initial_contents.hex", mem_array);
  end
`endif

  always_comb begin
    // memory addresses should always be 4B-aligned
    assert (pc_to_imem[1:0] == 2'b00);
    assert (addr_to_dmem[1:0] == 2'b00);
  end

  localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam int AddrLsb = 2;

  always @(posedge clock_mem) begin
    if (rst) begin
    end else begin
      insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
    end
  end

  always @(negedge clock_mem) begin
    if (rst) begin
    end else begin
      if (store_we_to_dmem[0]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
      end
      if (store_we_to_dmem[1]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
      end
      if (store_we_to_dmem[2]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
      end
      if (store_we_to_dmem[3]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
      end
      // dmem is "read-first": read returns value before the write
      load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
    end
  end
endmodule

/*
This shows the relationship between clock_proc and clock_mem. The clock_mem is
phase-shifted 90° from clock_proc. You could think of one proc cycle being
broken down into 3 parts. During part 1 (which starts @posedge clock_proc)
the current PC is sent to the imem. In part 2 (starting @posedge clock_mem) we
read from imem. In part 3 (starting @negedge clock_mem) we read/write memory and
prepare register/PC updates, which occur at @posedge clock_proc.

        ____
 proc: |    |______
           ____
 mem:  ___|    |___
*/
module Processor (
    input  wire                        clock_proc,
    input  wire                        clock_mem,
    input  wire                        rst,
    output wire           [ `REG_SIZE] trace_completed_pc,
    output wire           [`INSN_SIZE] trace_completed_insn,
    output cycle_status_e              trace_completed_cycle_status,
    output logic                       halt
);

  wire [`REG_SIZE] pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [`INSN_SIZE] insn_from_imem;
  wire [3:0] mem_data_we;

  // This wire is set by cocotb to the name of the currently-running test, to make it easier
  // to see what is going on in the waveforms.
  wire [(8*32)-1:0] test_case;

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
      .rst                (rst),
      .clock_mem          (clock_mem),
      // imem is read-only
      .pc_to_imem         (pc_to_imem),
      .insn_from_imem     (insn_from_imem),
      // dmem is read-write
      .addr_to_dmem       (mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem   (mem_data_we)
  );

  DatapathSingleCycle datapath (
      .clk(clock_proc),
      .rst(rst),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_loaded_value),
      .trace_completed_pc(trace_completed_pc),
      .trace_completed_insn(trace_completed_insn),
      .trace_completed_cycle_status(trace_completed_cycle_status),
      .halt(halt)
  );

endmodule