module sdram_init #(
	parameter	CLK_FREQ			= 125_000_000,
	parameter	PHYADDRWIDTH		= 11,
	parameter	PHYBANKWIDTH		= 2,
	parameter	CASLATENCY			= 3,
	parameter	POWERUP_DELAYMS		= 1000,
	parameter	BURSTLENGTH			= 4,
	parameter	BURSTTYPE			= "SEQUENTIAL"		//"SEQUENTIAL" "INTERLEAVE"
) (
	input						I_clk,
	input						I_rstn,

	output						O_init_done,
	output	[2:0]				O_init_cmd,
	output	[PHYBANKWIDTH-1:0]	O_init_bank,
	output	[PHYADDRWIDTH-1:0]	O_init_addr
);

`include "./sdram_adapt/sdram_params_h.v"
`include "../Verilog-LIB/verilog_math.v"

localparam CLK_PERIOD	= (1_000_000_000 / CLK_FREQ);
localparam TRP			= int_ceil_div(`tRP , CLK_PERIOD);
localparam TINIT		= TRP + `tMRD_clk + 2;
localparam INITCNTWIDTH	= $clog2(TINIT);



wire [2:0]	W_rfu = 3'b0;
wire 		W_wbl = 1'b0;
wire [1:0]	W_test_mode = 2'b0;
wire [2:0]	W_cas_latency = 3'b011;
wire 		W_bt = (BURSTTYPE == "INTERLEAVE");
reg [2:0]	W_burst_length;

always @(*)begin
	case (BURSTLENGTH)
		1:	W_burst_length = 3'b000;
		2:	W_burst_length = 3'b001;
		4:	W_burst_length = 3'b010;
		8:	W_burst_length = 3'b011;
		default:W_burst_length = 3'b000;
	endcase
end

wire [12:0] W_mrs_value = {W_rfu, W_wbl, W_test_mode, W_cas_latency, W_bt, W_burst_length};


wire W_powerup_rstn;

time_delay_ms #(
	.CLK_FREQ	(CLK_FREQ),
	.DELAY_MS	(POWERUP_DELAYMS)
) time_delay_ms_u(
	.I_clk		(I_clk),

	.I_rstn		(I_rstn),
	.O_rstn		(W_powerup_rstn)
);


localparam CMD_NOP				= 3'b111;
// localparam CMD_BURST_TERMINATE	= 3'b110;
// localparam CMD_READ				= 3'b101;
// localparam CMD_WRITE			= 3'b100;
// localparam CMD_BANK_ACTIVE		= 3'b011;
localparam CMD_PRECHARGE		= 3'b010;
// localparam CMD_REFRESH			= 3'b001;
localparam CMD_MODE_REG_SET		= 3'b000;



reg [INITCNTWIDTH-1:0] R_cnt_init;

reg						R_init_done;
reg	[2:0]				R_init_cmd;
reg	[PHYBANKWIDTH-1:0]	R_init_bank;
reg	[PHYADDRWIDTH-1:0]	R_init_addr;


always @(posedge I_clk or negedge W_powerup_rstn) begin
	if(!W_powerup_rstn)
		R_cnt_init <= (TINIT - 1);
	else if(R_cnt_init != {INITCNTWIDTH{1'b0}})
		R_cnt_init <= R_cnt_init - 1'b1;
	else 
		R_cnt_init <= R_cnt_init;

	if(!W_powerup_rstn)
		R_init_done <= 1'b0;
	else 
		R_init_done <= (R_cnt_init == {INITCNTWIDTH{1'b0}});
	
	if(!W_powerup_rstn)
		R_init_cmd <= CMD_NOP;
	else if(R_cnt_init == (TINIT - 2))
		R_init_cmd <= CMD_PRECHARGE;
	else if(R_cnt_init == (TINIT - 2 - TRP))
		R_init_cmd <= CMD_MODE_REG_SET;
	else 
		R_init_cmd <= CMD_NOP;

	if(!W_powerup_rstn)
		R_init_bank <= {PHYBANKWIDTH{1'b0}};
	else if(R_cnt_init == (TINIT - 2 - TRP))
		R_init_bank <= W_mrs_value[12:11];
	else 
		R_init_bank <= {PHYADDRWIDTH{1'b0}};

	if(!W_powerup_rstn)
		R_init_addr <= {PHYADDRWIDTH{1'b0}};
	else if(R_cnt_init == (TINIT - 2))
		R_init_addr <= {1'b1, {(PHYADDRWIDTH-1){1'b0}}};
	else if(R_cnt_init == (TINIT - 2 - TRP))
		R_init_addr <= W_mrs_value[10:0];
	else 
		R_init_addr <= {PHYADDRWIDTH{1'b0}};
end


assign O_init_done	= R_init_done;
assign O_init_cmd	= R_init_cmd;
assign O_init_bank	= R_init_bank;
assign O_init_addr	= R_init_addr;

endmodule
