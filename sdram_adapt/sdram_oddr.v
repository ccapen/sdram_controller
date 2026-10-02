module sdram_oddr (
	input			I_clk,
	input			I_rstn,
	input			I_d0,
	input			I_d1,
	output			O_q
);

// `define SIMULATION

`ifndef SIMULATION

EG_LOGIC_ODDR#( 
	.ASYNCRST	("ENABLE")
) ODDR_inst( 
	.q		(O_q), 
	.d1		(I_d1), 
	.d0		(I_d0), 
	.clk	(I_clk), 
	.rst	(!I_rstn) 
);

`else

reg R_qpos;
reg R_qneg;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_qpos <= 1'b0;
	else 
		R_qpos <= I_d1;
end

always @(negedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_qneg <= 1'b0;
	else 
		R_qneg <= I_d0;
end

assign O_q = I_clk ? R_qpos : R_qneg;

`endif



endmodule
