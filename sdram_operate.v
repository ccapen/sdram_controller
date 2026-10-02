module sdram_operate #(
	parameter	CLK_FREQ			= 125_000_000,
	parameter	ADDRWIDTH			= 21,
	parameter	DATAWIDTH			= 32,
	parameter	PHYADDRWIDTH		= 11,
	parameter	PHYBANKWIDTH		= 2,
	parameter	PHYDQMWIDTH			= DATAWIDTH/8,
	parameter	CASLATENCY			= 3,
	parameter	BANKADDRWIDTH		= 2,
	parameter	ROWADDRWIDTH		= 11,
	parameter	COLADDRWIDTH		= 8,
	parameter	BURSTLENGTH			= 4
) (
	input						I_clk,
	input						I_dq_retclk,
	input						I_rstn,

	input						I_init_done,
	input	[2:0]				I_init_cmd,
	input	[PHYBANKWIDTH-1:0]	I_init_bank,
	input	[PHYADDRWIDTH-1:0]	I_init_addr,

	input						I_refresh_immediately,
	input						I_refresh_no_immediately,
	output						O_refresh_ready,

	input						I_all_precharged,
	input						I_precharge_valid,
	input	[BANKADDRWIDTH-1:0]	I_precharge_bank_addr,
	output						O_precharge_ready,

	input						I_active_valid,
	input	[BANKADDRWIDTH-1:0]	I_active_bank_addr,
	input	[ROWADDRWIDTH-1:0]	I_active_row_addr,
	output						O_active_ready,

	input						I_wr_rd_valid,
	input						I_wr_rd_cmden,
	input						I_wr_rd_is_rd,
	input	[ADDRWIDTH-1:0]		I_wr_rd_addr,
	input	[DATAWIDTH-1:0]		I_wr_rd_data,
	input	[PHYDQMWIDTH-1:0]	I_wr_rd_dqm,
	output						O_wr_rd_ready,

	output						O_out_valid,
	output	[ADDRWIDTH-1:0]		O_out_addr,
	output	[DATAWIDTH-1:0]		O_out_data,
	output	[PHYDQMWIDTH-1:0]	O_out_dqm,

	output						O_sdram_clk,
	output						O_sdram_cke,
	output						O_sdram_csn,
	output						O_sdram_rasn,
	output						O_sdram_casn,
	output						O_sdram_wen,
	output	[PHYBANKWIDTH-1:0]	O_sdram_bank,
	output	[PHYADDRWIDTH-1:0]	O_sdram_addr,
	input	[DATAWIDTH-1:0]		I_sdram_data,
	output						O_sdram_data_en,
	output	[DATAWIDTH-1:0]		O_sdram_data,
	output	[PHYDQMWIDTH-1:0]	O_sdram_dqm
);

`include "./sdram_adapt/sdram_params_h.v"
`include "../Verilog-LIB/verilog_math.v"

localparam CLK_PERIOD	= (1_000_000_000 / CLK_FREQ);
localparam TRRD			= int_ceil_div(`tRRD , CLK_PERIOD);
localparam RRDCNTWIDTH	= $clog2(TRRD);
localparam TRP			= int_ceil_div(`tRP , CLK_PERIOD);
localparam RPCNTWIDTH	= $clog2(TRP);
localparam TRFC			= int_ceil_div(`tRFC , CLK_PERIOD);
localparam RFCCNTWIDTH	= $clog2(TRFC);
localparam TWTR			= 1;
localparam WTRCNTWIDTH	= (TWTR < 2) ? 1 : $clog2(TWTR);
localparam TRTW			= CASLATENCY + 1;
localparam RTWCNTWIDTH	= $clog2(TRTW);

localparam TRC			= int_ceil_div(`tRC , CLK_PERIOD);


wire W_write_ready = O_wr_rd_ready && (!I_wr_rd_is_rd);
wire W_read_ready = O_wr_rd_ready && I_wr_rd_is_rd;

reg [RRDCNTWIDTH-1:0] R_cnt_active;
reg [RPCNTWIDTH -1:0] R_cnt_precharge;
reg [RFCCNTWIDTH-1:0] R_cnt_refresh;
reg [WTRCNTWIDTH-1:0] R_cnt_wtr;
reg [RTWCNTWIDTH-1:0] R_cnt_rtw;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_cnt_precharge <= {RPCNTWIDTH{1'b0}};
	else if(O_precharge_ready)
		R_cnt_precharge <= (TRP - 1'b1);
	else if(R_cnt_precharge == {RPCNTWIDTH{1'b0}})
		R_cnt_precharge <= {RPCNTWIDTH{1'b0}};
	else 
		R_cnt_precharge <= R_cnt_precharge - 1'b1;

	if(!I_rstn)
		R_cnt_active <= {RRDCNTWIDTH{1'b0}};
	else if(O_active_ready)
		R_cnt_active <= (TRRD - 1'b1);
	else if(R_cnt_active == {RRDCNTWIDTH{1'b0}})
		R_cnt_active <= {RRDCNTWIDTH{1'b0}};
	else 
		R_cnt_active <= R_cnt_active - 1'b1;
	
	if(!I_rstn)
		R_cnt_refresh <= {RFCCNTWIDTH{1'b0}};
	else if(O_refresh_ready)
		R_cnt_refresh <= (TRFC - 1'b1);
	else if(O_precharge_ready)
		R_cnt_refresh <= (TRP - 1'b1);
	else if(R_cnt_refresh == {RFCCNTWIDTH{1'b0}})
		R_cnt_refresh <= {RFCCNTWIDTH{1'b0}};
	else 
		R_cnt_refresh <= R_cnt_refresh - 1'b1;
	
	if(!I_rstn)
		R_cnt_wtr <= {WTRCNTWIDTH{1'b0}};
	else if(W_write_ready)
		R_cnt_wtr <= (TWTR - 1'b1);
	else if(R_cnt_wtr == {WTRCNTWIDTH{1'b0}})
		R_cnt_wtr <= R_cnt_wtr;
	else 
		R_cnt_wtr <= R_cnt_wtr - 1'b1;
	
	if(!I_rstn)
		R_cnt_rtw <= {RTWCNTWIDTH{1'b0}};
	else if(W_read_ready)
		R_cnt_rtw <= (TRTW - 1'b1);
	else if(R_cnt_rtw == {RTWCNTWIDTH{1'b0}})
		R_cnt_rtw <= R_cnt_rtw;
	else 
		R_cnt_rtw <= R_cnt_rtw - 1'b1;
end



reg R_refresh_prepared;
reg R_precharge_prepared;
reg R_active_prepared;
reg R_write_prepared;
reg R_read_prepared;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_refresh_prepared <= 1'b0;
	else if(!I_init_done)
		R_refresh_prepared <= 1'b0;
	else if(O_refresh_ready || (R_cnt_refresh > 1'b1))
		R_refresh_prepared <= 1'b0;
	else if(O_active_ready || (!I_all_precharged) || (R_cnt_precharge > 1'b1))
		R_refresh_prepared <= 1'b0;
	else 
		R_refresh_prepared <= 1'b1;

	if(!I_rstn)
		R_precharge_prepared <= 1'b0;
	else if(!I_init_done)
		R_precharge_prepared <= 1'b0;
	else if(O_refresh_ready || (R_cnt_refresh > 1'b1))
		R_precharge_prepared <= 1'b0;
	else 
		R_precharge_prepared <= 1'b1;

	if(!I_rstn)
		R_active_prepared <= 1'b0;
	else if(!I_init_done)
		R_active_prepared <= 1'b0;
	else if(O_refresh_ready || (R_cnt_refresh > 1'b1))
		R_active_prepared <= 1'b0;
	else if(I_refresh_immediately)
		R_active_prepared <= 1'b0;
	else if(((TRRD > 1) && O_active_ready) || (R_cnt_active > 1'b1))
		R_active_prepared <= 1'b0;
	else 
		R_active_prepared <= 1'b1;

	if(!I_rstn)
		R_write_prepared <= 1'b0;
	else if(!I_init_done)
		R_write_prepared <= 1'b0;
	else if(O_refresh_ready || (R_cnt_refresh > 1'b1))
		R_write_prepared <= 1'b0;
	else if(W_read_ready || (R_cnt_rtw > 1'b1))
		R_write_prepared <= 1'b0;
	else 
		R_write_prepared <= 1'b1;

	if(!I_rstn)
		R_read_prepared <= 1'b0;
	else if(!I_init_done)
		R_read_prepared <= 1'b0;
	else if(O_refresh_ready || (R_cnt_refresh > 1'b1))
		R_read_prepared <= 1'b0;
	else if(((TWTR > 1) && W_write_ready) || (R_cnt_wtr > 1'b1))
		R_read_prepared <= 1'b0;
	else 
		R_read_prepared <= 1'b1;
end

assign O_refresh_ready = R_refresh_prepared && (I_refresh_immediately || (I_refresh_no_immediately && (!I_active_valid)));
assign O_wr_rd_ready = I_wr_rd_valid && (I_wr_rd_is_rd ? R_read_prepared : R_write_prepared);
assign O_active_ready = I_active_valid && (!(O_wr_rd_ready && I_wr_rd_cmden)) && R_active_prepared && (!I_refresh_immediately);
assign O_precharge_ready = I_precharge_valid && (!O_active_ready) && (!(O_wr_rd_ready && I_wr_rd_cmden)) && R_precharge_prepared;



localparam BURSTCNTWIDTH	= $clog2(BURSTLENGTH);

reg [BURSTCNTWIDTH-1:0] R_cnt_burst;
reg R_burst_is_rd;
wire W_in_burst = (R_cnt_burst != {BURSTCNTWIDTH{1'b0}});

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_cnt_burst <= {BURSTCNTWIDTH{1'b0}};
	else if(O_wr_rd_ready && I_wr_rd_cmden)
		R_cnt_burst <= (BURSTLENGTH - 1'b1);
	else if(R_cnt_burst == {BURSTCNTWIDTH{1'b0}})
		R_cnt_burst <= {BURSTCNTWIDTH{1'b0}};
	else 
		R_cnt_burst <= R_cnt_burst - 1'b1;

	if(!I_rstn)
		R_burst_is_rd <= 1'b0;
	else if(O_wr_rd_ready)
		R_burst_is_rd <= I_wr_rd_is_rd;
	else 
		R_burst_is_rd <= R_burst_is_rd;
end

wire W_wcmd_mask_position;
wire W_rcmd_mask_position;
wire [PHYDQMWIDTH-1:0] W_wcmd_mask_dqm;
wire [PHYDQMWIDTH-1:0] W_rcmd_mask_dqm;
wire W_wburst_mask;
wire W_rburst_mask;

assign W_wcmd_mask_position = W_write_ready;
assign W_wcmd_mask_dqm = I_wr_rd_dqm;
assign W_wburst_mask = W_in_burst && (!O_wr_rd_ready) && (!R_burst_is_rd);

vector_delay #(
	.WIDTH		(1+PHYDQMWIDTH+1),
	.DELAY		(CASLATENCY-2)
) vector_delay_rmask(
	.I_clk		(I_clk),
	.I_rstn		(I_rstn),
	
	.I_data		({W_read_ready, I_wr_rd_dqm, (W_in_burst && (!O_wr_rd_ready) && R_burst_is_rd)}),
	.O_data		({W_rcmd_mask_position, W_rcmd_mask_dqm, W_rburst_mask})
);



localparam CMD_NOP				= 3'b111;
localparam CMD_BURST_TERMINATE	= 3'b110;
localparam CMD_READ				= 3'b101;
localparam CMD_WRITE			= 3'b100;
localparam CMD_BANK_ACTIVE		= 3'b011;
localparam CMD_PRECHARGE		= 3'b010;
localparam CMD_REFRESH			= 3'b001;
localparam CMD_MODE_REG_SET		= 3'b000;

reg [2:0] R_cmd;
reg [PHYBANKWIDTH-1:0]	R_bank;
reg [PHYADDRWIDTH-1:0]	R_addr;
reg R_data_en;
reg [DATAWIDTH-1:0]	R_data;
reg [PHYDQMWIDTH-1:0] R_dqm;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_cmd <= CMD_NOP;
	else case(1'b1)
		(!I_init_done):						R_cmd <= I_init_cmd;
		(O_refresh_ready):					R_cmd <= CMD_REFRESH;
		(W_write_ready && I_wr_rd_cmden):	R_cmd <= CMD_WRITE;
		(W_read_ready && I_wr_rd_cmden):	R_cmd <= CMD_READ;
		(O_active_ready):					R_cmd <= CMD_BANK_ACTIVE;
		(O_precharge_ready):				R_cmd <= CMD_PRECHARGE;
		default:							R_cmd <= CMD_NOP;
	endcase

	if(!I_rstn)
		R_bank <= {PHYBANKWIDTH{1'b0}};
	else case (1'b1)
		(!I_init_done):						R_bank <= I_init_bank;
		(O_wr_rd_ready && I_wr_rd_cmden):	R_bank <= I_wr_rd_addr[ADDRWIDTH-1:ADDRWIDTH-BANKADDRWIDTH];
		(O_active_ready):					R_bank <= I_active_bank_addr;
		(O_precharge_ready):				R_bank <= I_precharge_bank_addr;
		default:							R_bank <= {PHYBANKWIDTH{1'bx}};
	endcase

	if(!I_rstn)
		R_addr <= {PHYADDRWIDTH{1'b0}};
	else case (1'b1)
		(!I_init_done):						R_addr <= I_init_addr;
		(O_wr_rd_ready && I_wr_rd_cmden):	R_addr <= {{(PHYADDRWIDTH-COLADDRWIDTH){1'b0}}, I_wr_rd_addr[COLADDRWIDTH-1:0]};
		(O_active_ready):					R_addr <= I_active_row_addr;
		default:							R_addr <= {PHYADDRWIDTH{1'bx}};
	endcase

	if(!I_rstn)
		R_data_en <= 1'b0;
	else if(W_write_ready)
		R_data_en <= 1'b1;
	else 
		R_data_en <= 1'b0;

	if(!I_rstn)
		R_data <= {DATAWIDTH{1'b0}};
	else if(W_write_ready)
		R_data <= I_wr_rd_data;
	else 
		R_data <= {DATAWIDTH{1'b0}};

	if(!I_rstn)
		R_dqm <= {PHYDQMWIDTH{1'b1}};
	else if(!I_init_done)
		R_dqm <= {PHYDQMWIDTH{1'b1}};
	else if(W_wcmd_mask_position)
		R_dqm <= W_wcmd_mask_dqm;
	else if(W_rcmd_mask_position)
		R_dqm <= W_rcmd_mask_dqm;
	else 
		R_dqm <= {PHYDQMWIDTH{(W_wburst_mask || W_rburst_mask)}};
end

sdram_oddr sdram_oddr_u(
	.I_clk		(I_clk),
	.I_rstn		(I_rstn),
	.I_d0		(1'b0),
	.I_d1		(1'b1),
	.O_q		(O_sdram_clk)
);

assign O_sdram_cke		= 1'b1;
assign O_sdram_csn		= 1'b0;
assign O_sdram_rasn		= R_cmd[2];
assign O_sdram_casn		= R_cmd[1];
assign O_sdram_wen		= R_cmd[0];
assign O_sdram_bank		= R_bank;
assign O_sdram_addr		= R_addr;
assign O_sdram_data_en	= R_data_en;
assign O_sdram_data		= R_data;
assign O_sdram_dqm		= R_dqm;


wire W_out_valid = W_read_ready;

vector_delay #(
	.WIDTH		(1+ADDRWIDTH+PHYDQMWIDTH),
	.DELAY		(CASLATENCY+3)
) vector_delay_outdata(
	.I_clk		(I_clk),
	.I_rstn		(I_rstn),
	
	.I_data		({W_out_valid, I_wr_rd_addr, I_wr_rd_dqm}),
	.O_data		({O_out_valid, O_out_addr, O_out_dqm})
);

reg [DATAWIDTH-1:0] R_ret_data;

always @(posedge I_dq_retclk) begin
	R_ret_data <= I_sdram_data;
end

reg [DATAWIDTH-1:0] R_out_data;

always @(posedge I_clk) begin
	R_out_data <= R_ret_data;
end

assign O_out_data = R_out_data;


endmodule
