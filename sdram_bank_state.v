module sdram_bank_state #(
	parameter	CLK_FREQ			= 125_000_000,
	parameter	ROWADDRWIDTH		= 11,
	parameter	RWBUFFERDEPTH		= 32,
	parameter	RWBUFCNTWIDTH		= $clog2(RWBUFFERDEPTH+1)
) (
	input						I_clk,
	input						I_rstn,

	input						I_precharge_valid,
	input						I_active_valid,
	input	[ROWADDRWIDTH-1:0]	I_active_row,
	input						I_active_cmd,
	input						I_wr_inc,
	input						I_rd_inc,
	input						I_wr_rd_dec,
	input						I_dec_cmden,
	input						I_dec_is_rd,
	output						O_precharge_prepared,
	output						O_active_prepared,
	output						O_wr_rd_prepared,
	output						O_is_active,
	output						O_is_phy_active,
	output	[ROWADDRWIDTH-1:0]	O_active_row,
	output	[RWBUFCNTWIDTH-1:0]	O_rw_num
);

`include "./sdram_adapt/sdram_params_h.v"
`include "../Verilog-LIB/verilog_math.v"

localparam CLK_PERIOD	= (1_000_000_000 / CLK_FREQ);
localparam TRCD			= int_ceil_div(`tRCD , CLK_PERIOD);
localparam RCDCNTWIDTH	= $clog2(TRCD);
localparam TCCD			= `tCCD_clk;
localparam CCDCNTWIDTH	= (TCCD < 2) ? 1 : $clog2(TCCD);
localparam TWR			= `tWR_clk;
localparam TRP			= int_ceil_div(`tRP , CLK_PERIOD);
localparam TRAS			= int_ceil_div(`tRAS , CLK_PERIOD);
localparam PRECNTVALMAX	= (TRAS > TWR) ? TRAS : TWR;
localparam PACNTVALMAX	= (TRP > PRECNTVALMAX) ? TRP : PRECNTVALMAX;
localparam PACNTWIDTH	= $clog2(PACNTVALMAX);


reg [RCDCNTWIDTH-1:0] R_cnt_rw;
reg [CCDCNTWIDTH-1:0] R_cnt_ccd;
reg [PACNTWIDTH-1:0] R_cnt_pre_act;
reg [RWBUFCNTWIDTH-1:0] R_wr_rd_num;
reg R_bank_logic_active;
reg R_bank_phy_active;
reg [ROWADDRWIDTH-1:0] R_active_row;

always @ (posedge I_clk or negedge I_rstn)begin
	if(!I_rstn)
		R_cnt_rw <= {RCDCNTWIDTH{1'b0}};
	else if(I_active_cmd)
		R_cnt_rw <= (TRCD - 1'b1);
	else if(R_cnt_rw == {RCDCNTWIDTH{1'b0}})
		R_cnt_rw <= {RCDCNTWIDTH{1'b0}};
	else 
		R_cnt_rw <= R_cnt_rw - 1'b1;

	if(!I_rstn)
		R_cnt_ccd <= {CCDCNTWIDTH{1'b0}};
	else if(I_wr_rd_dec && I_dec_cmden)
		R_cnt_ccd <= (TCCD - 1'b1);
	else if(R_cnt_ccd == {CCDCNTWIDTH{1'b0}})
		R_cnt_ccd <= {CCDCNTWIDTH{1'b0}};
	else 
		R_cnt_ccd <= R_cnt_ccd - 1'b1;

	if(!I_rstn)
		R_cnt_pre_act <= {PACNTWIDTH{1'b0}};
	else if(I_precharge_valid)
		R_cnt_pre_act <= (TRP - 1'b1);
	else if(I_active_cmd)
		R_cnt_pre_act <= (TRAS - 1'b1);
	else if(I_wr_rd_dec && (!I_dec_is_rd))
		R_cnt_pre_act <= (TWR - 1'b1);
	else if(R_cnt_pre_act == {PACNTWIDTH{1'b0}})
		R_cnt_pre_act <= {PACNTWIDTH{1'b0}};
	else 
		R_cnt_pre_act <= R_cnt_pre_act - 1'b1;

	if(!I_rstn)
		R_wr_rd_num <= {RWBUFCNTWIDTH{1'b0}};
	else case ({I_wr_inc, I_rd_inc, I_wr_rd_dec})
		3'b001:	R_wr_rd_num <= R_wr_rd_num - 1'b1;
		3'b010:	R_wr_rd_num <= R_wr_rd_num + 1'b1;
		3'b100:	R_wr_rd_num <= R_wr_rd_num + 1'b1;
		3'b111:	R_wr_rd_num <= R_wr_rd_num + 1'b1;
		3'b110:	R_wr_rd_num <= R_wr_rd_num + 2'd2;
		default:R_wr_rd_num <= R_wr_rd_num;
	endcase

	if(!I_rstn)
		R_bank_logic_active <= 1'b0;
	else if(I_precharge_valid)
		R_bank_logic_active <= 1'b0;
	else if(I_active_valid)
		R_bank_logic_active <= 1'b1;
	else 
		R_bank_logic_active <= R_bank_logic_active;

	if(!I_rstn)
		R_bank_phy_active <= 1'b0;
	else if(I_precharge_valid)
		R_bank_phy_active <= 1'b0;
	else if(I_active_cmd)
		R_bank_phy_active <= 1'b1;
	else 
		R_bank_phy_active <= R_bank_phy_active;
	
	if(!I_rstn)
		R_active_row <= {ROWADDRWIDTH{1'b0}};
	else if(I_active_valid)
		R_active_row <= I_active_row;
	else 
		R_active_row <= R_active_row;
end

reg R_precharge_prepared;
reg R_active_prepared;
reg R_wr_rd_prepared;
reg R_wr_rd_cmd_prepared;

always @ (posedge I_clk or negedge I_rstn)begin
	if(!I_rstn)
		R_precharge_prepared <= 1'b0;
	else if(!R_bank_logic_active)
		R_precharge_prepared <= 1'b0;
	else if(I_wr_inc || I_rd_inc || (R_wr_rd_num > 1'b1) || ((R_wr_rd_num == 1'b1) && ({I_wr_inc, I_rd_inc, I_wr_rd_dec} != 3'b001)))
		R_precharge_prepared <= 1'b0;
	else if(I_precharge_valid || (I_wr_rd_dec && (!I_dec_is_rd) && (TWR > 1'b1)) || (R_cnt_pre_act > 1'b1))
		R_precharge_prepared <= 1'b0;
	else 
		R_precharge_prepared <= 1'b1;

	if(!I_rstn)
		R_active_prepared <= 1'b0;
	else if(R_bank_logic_active || I_active_valid)
		R_active_prepared <= 1'b0;
	else if(I_active_cmd || (R_cnt_pre_act > 1'b1))
		R_active_prepared <= 1'b0;
	else 
		R_active_prepared <= 1'b1;

	if(!I_rstn)
		R_wr_rd_prepared <= 1'b0;
	else if(!R_bank_phy_active)
		R_wr_rd_prepared <= 1'b0;
	else if(I_active_cmd || (R_cnt_rw > 1'b1))
		R_wr_rd_prepared <= 1'b0;
	else 
		R_wr_rd_prepared <= 1'b1;

	if(!I_rstn)
		R_wr_rd_cmd_prepared <= 1'b0;
	else if(((TCCD > 1) && I_wr_rd_dec && I_dec_cmden) || (R_cnt_ccd > 1'b1))
		R_wr_rd_cmd_prepared <= 1'b0;
	else 
		R_wr_rd_cmd_prepared <= 1'b1;
end


assign O_precharge_prepared	= R_precharge_prepared;
assign O_active_prepared	= R_active_prepared;
assign O_wr_rd_prepared		= R_wr_rd_prepared && ((TCCD <= 1) || (!I_dec_cmden) || R_wr_rd_cmd_prepared);
assign O_is_active		= R_bank_logic_active;
assign O_is_phy_active	= R_bank_phy_active;
assign O_active_row	= R_active_row;
assign O_rw_num		= R_wr_rd_num;

endmodule
