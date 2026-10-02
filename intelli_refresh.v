module intelli_refresh#(
	parameter	CLK_FREQ		= 125_000_000,
	parameter	REFRESH_TIME_MS	= 64,
	parameter	REFRESH_LINE	= 4096,
	parameter	REFRESH_SLICE	= 16	//suggest >= 4, must >= 2, must <= REFRESH_TIME_MS
) (
	input			I_clk,
	input			I_rstn,

	output			O_refresh_immediately,
	output			O_refresh_no_immediately,
	input			I_refresh_ready
);

`include "../Verilog-LIB/verilog_math.v"

localparam	SLICE_TIME_MS	= (REFRESH_TIME_MS > REFRESH_SLICE) ? (REFRESH_TIME_MS / REFRESH_SLICE) : 1;
localparam	SLICE_LINE		= int_ceil_div(REFRESH_LINE , (REFRESH_SLICE - 1));
localparam	LINECNTWIDTH	= $clog2(SLICE_LINE) + 2;


wire W_slice_en;
reg R_slice_delay_rstn;

time_delay_ms #(
	.CLK_FREQ	(CLK_FREQ),
	.DELAY_MS	(SLICE_TIME_MS)
) time_delay_ms_u(
	.I_clk		(I_clk),

	.I_rstn		(R_slice_delay_rstn),
	.O_rstn		(W_slice_en)
);

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_slice_delay_rstn <= 1'b0;
	else 
		R_slice_delay_rstn <= !(R_slice_delay_rstn && W_slice_en);
end


reg [LINECNTWIDTH-1:0] R_cnt_refresh_line;
reg R_refresh_immediately;
reg R_refresh_no_immediately;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_cnt_refresh_line <= {LINECNTWIDTH{1'b0}};
	else case ({W_slice_en, (I_refresh_ready && O_refresh_no_immediately)})
		2'b00:	R_cnt_refresh_line <= R_cnt_refresh_line;
		2'b01:	R_cnt_refresh_line <= R_cnt_refresh_line - 1'b1;
		2'b10:	R_cnt_refresh_line <= R_cnt_refresh_line + SLICE_LINE;
		2'b11:	R_cnt_refresh_line <= R_cnt_refresh_line + SLICE_LINE - 1'b1;
		default:R_cnt_refresh_line <= R_cnt_refresh_line;
	endcase

	if(!I_rstn)
		R_refresh_immediately <= 1'b0;
	else 
		R_refresh_immediately <= (R_cnt_refresh_line > SLICE_LINE);

	if(!I_rstn)
		R_refresh_no_immediately <= 1'b0;
	else 
		R_refresh_no_immediately <= (R_cnt_refresh_line != {LINECNTWIDTH{1'b0}});
end

assign O_refresh_immediately	= R_refresh_immediately;
assign O_refresh_no_immediately	= R_refresh_no_immediately;



endmodule
