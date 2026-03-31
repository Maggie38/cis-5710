/* INSERT NAME AND PENNKEY HERE */

`timescale 1ns / 1ns

// quotient = dividend / divisor

module DividerUnsigned (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);

    // TODO: your code here
    wire [32 * 32 - 1:0] dividend_wires;
    wire [32 * 32 - 1:0] remainder_wires;
    wire [32 * 32 - 1:0] quotient_wires;

    DividerOneIter first_iter (
        .i_dividend (i_dividend),
        .i_divisor (i_divisor),
        .i_remainder (32'b0),
        .i_quotient (32'b0),
        .o_dividend (dividend_wires[31 -: 32]),
        .o_remainder (remainder_wires[31 -: 32]),
        .o_quotient (quotient_wires[31 -: 32])
    );

    genvar i;
    generate 
        for (i = 1; i < 32; i++) begin: DIVIDER_LOOP
            DividerOneIter one_iter (
                .i_dividend (dividend_wires[32*i-1 -: 32]),
                .i_divisor (i_divisor),
                .i_remainder (remainder_wires[32*i-1 -: 32]),
                .i_quotient (quotient_wires[32*i-1 -: 32]),
                .o_dividend (dividend_wires[32*(i+1)-1 -: 32]),
                .o_remainder (remainder_wires[32*(i+1)-1 -: 32]),
                .o_quotient (quotient_wires[32*(i+1)-1 -: 32])
            );
        end
    endgenerate
    assign o_remainder = remainder_wires[32*32-1 -: 32];
    assign o_quotient = quotient_wires[32*32-1 -: 32];
endmodule


module DividerOneIter (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    input  wire [31:0] i_remainder,
    input  wire [31:0] i_quotient,
    output wire [31:0] o_dividend,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);
  /*
    for (int i = 0; i < 32; i++) {
        remainder = (remainder << 1) | ((dividend >> 31) & 0x1);
        if (remainder < divisor) {
            quotient = (quotient << 1);
        } else {
            quotient = (quotient << 1) | 0x1;
            remainder = remainder - divisor;
        }
        dividend = dividend << 1;
    }
    */

    // TODO: your code here
    wire [31:0] r_temp1 = (i_remainder << 1) | ((i_dividend >> 31) & 32'b1);
    wire lt_temp1 = (r_temp1 < i_divisor) ? 1'b1 : 1'b0;
    assign o_quotient = lt_temp1 ? (i_quotient << 1) : ((i_quotient << 1) | 32'b1);
    assign o_remainder = lt_temp1 ? r_temp1 : (r_temp1 - i_divisor);
    assign o_dividend = i_dividend << 1;

endmodule
