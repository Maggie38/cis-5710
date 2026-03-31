`timescale 1ns / 1ns

// quotient = dividend / divisor

module DividerUnsignedPipelined (
    input wire clk,
    rst,
    stall,
    input wire [31:0] i_dividend,
    input wire [31:0] i_divisor,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);
  // Internal wires
  wire  [31:0][31:0] dividends;
  wire  [31:0][31:0] remainders;
  wire  [31:0][31:0] quotients;

  // Pipeline registers for stages 1-8
  logic [ 6:0][31:0] dividend_stage;
  logic [ 6:0][31:0] divisor_stage;
  logic [ 6:0][31:0] remainder_stage;
  logic [ 6:0][31:0] quotient_stage;
  always_ff @(posedge clk) begin
    integer i;
    for (i = 0; i < 7; i++) begin
      if (rst) begin
        dividend_stage[i]  <= 32'b0;
        divisor_stage[i]   <= 32'b0;
        remainder_stage[i] <= 32'b0;
        quotient_stage[i]  <= 32'b0;
      end else begin
        dividend_stage[i]  <= dividends[(4*i)+3];
        divisor_stage[i]   <= (i == 0) ? i_divisor : divisor_stage[i-1];
        remainder_stage[i] <= remainders[(4*i)+3];
        quotient_stage[i]  <= quotients[(4*i)+3];
      end
    end
  end

  // First stage: feed inputs into the pipeline
  divu_1iter div_iter_stage_0_start (
      .i_dividend(i_dividend),
      .i_divisor(i_divisor),
      .i_remainder(32'b0),  // Initial remainder is 0
      .i_quotient(32'b0),  // Initial quotient is 0
      .o_dividend(dividends[0]),
      .o_remainder(remainders[0]),
      .o_quotient(quotients[0])
  );
  genvar k;
  generate
    for (k = 1; k < 4; k++) begin : pipeline_divider_stage_0
      divu_1iter div_iter_stage_0_rest (
          .i_dividend (dividends[k-1]),
          .i_divisor  (i_divisor),
          .i_remainder(remainders[k-1]),
          .i_quotient (quotients[k-1]),
          .o_dividend (dividends[k]),
          .o_remainder(remainders[k]),
          .o_quotient (quotients[k])
      );
    end
  endgenerate

  // Second through eighth stages: feed outputs of previous stage into next stage
  genvar i, j;
  generate
    for (i = 1; i < 8; i++) begin : pipeline_divider_stages_outer
      divu_1iter div_iter_stage_start (
          .i_dividend (dividend_stage[i-1]),
          .i_divisor  (divisor_stage[i-1]),
          .i_remainder(remainder_stage[i-1]),
          .i_quotient (quotient_stage[i-1]),
          .o_dividend (dividends[4*i]),
          .o_remainder(remainders[4*i]),
          .o_quotient (quotients[4*i])
      );
      for (j = 1; j < 4; j++) begin : pipeline_divider_stages_inner
        divu_1iter div_iter_stage_rest (
            .i_dividend (dividends[(4*i)+j-1]),
            .i_divisor  (divisor_stage[i-1]),
            .i_remainder(remainders[(4*i)+j-1]),
            .i_quotient (quotients[(4*i)+j-1]),
            .o_dividend (dividends[(4*i)+j]),
            .o_remainder(remainders[(4*i)+j]),
            .o_quotient (quotients[(4*i)+j])
        );
      end
    end
  endgenerate

  // Output from the last stage of the pipeline
  assign o_remainder = remainders[31];
  assign o_quotient  = quotients[31];

endmodule


module divu_1iter (
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    input  wire  [31:0] i_remainder,
    input  wire  [31:0] i_quotient,
    output logic [31:0] o_dividend,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);
  // Shift remainder left by 1 and bring in MSB of dividend (pure wiring)
  wire [31:0] r_shifted = {i_remainder[30:0], i_dividend[31]};

  // Single subtraction replaces separate comparator + subtractor:
  // bit 32 is the borrow — tells us if r_shifted < i_divisor
  wire [32:0] sub_result = {1'b0, r_shifted} - {1'b0, i_divisor};

  // Quotient: shift left and insert comparison bit (pure wiring + 1 inverter)
  assign o_quotient  = {i_quotient[30:0], ~sub_result[32]};
  // Remainder: if borrow (r_shifted < divisor), keep r_shifted; else use difference
  assign o_remainder = sub_result[32] ? r_shifted : sub_result[31:0];
  // Shift dividend left (pure wiring)
  assign o_dividend  = {i_dividend[30:0], 1'b0};

endmodule