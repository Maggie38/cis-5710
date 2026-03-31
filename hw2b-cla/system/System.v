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
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 32; _gv_i_1 = _gv_i_1 + 1) begin : gp_gen
			localparam i = _gv_i_1;
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
		for (_gv_i_1 = 0; _gv_i_1 < 32; _gv_i_1 = _gv_i_1 + 1) begin : sum_gen
			localparam i = _gv_i_1;
			assign sum[i] = (a[i] ^ b[i]) ^ c[i];
		end
	endgenerate
endmodule
module SystemDemo (
	external_clk_25MHz,
	btn,
	led
);
	reg _sv2v_0;
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output reg [7:0] led;
	reg [31:0] ab;
	wire [15:0] a;
	wire [15:0] b;
	wire [31:0] expected_sum;
	wire [31:0] actual_sum;
	wire rst = ~btn[0];
	reg error;
	wire [2:0] chunk = ab[31:29];
	reg [7:0] completed;
	CarryLookaheadAdder cla_inst(
		.a(a),
		.b(b),
		.cin(1'b0),
		.sum(actual_sum)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		a = ab[31:16];
		b = ab[15:0];
		expected_sum = a + b;
	end
	always @(posedge external_clk_25MHz)
		if (rst) begin
			ab <= 32'd0;
			error <= 1'b0;
			completed <= 8'd0;
		end
		else if (!error) begin
			if (actual_sum != expected_sum)
				error <= 1'b1;
			else begin
				ab <= ab + 1;
				if (ab[28:0] == 29'h1fffffff)
					completed[chunk] <= 1'b1;
			end
		end
	reg [23:0] blink;
	always @(posedge external_clk_25MHz)
		if (rst)
			blink <= 0;
		else
			blink <= blink + 1;
	always @(*) begin
		if (_sv2v_0)
			;
		if (error)
			led = completed;
		else
			led = completed | ({7'd0, blink[23]} << chunk);
	end
	initial _sv2v_0 = 0;
endmodule