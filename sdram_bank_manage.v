module sdram_bank_manage #(
	parameter	CLK_FREQ			= 125_000_000,
	parameter	ADDRWIDTH			= 21,
	parameter	DATAWIDTH			= 32,
	parameter	BANKNUM				= 4,
	parameter	PHYDQMWIDTH			= DATAWIDTH/8,
	parameter	BANKADDRWIDTH		= 2,
	parameter	ROWADDRWIDTH		= 11,
	parameter	COLADDRWIDTH		= 8,
	parameter	BURSTLENGTH			= 4,
	parameter	BURSTTYPE			= "SEQUENTIAL",		//"SEQUENTIAL" "INTERLEAVE"
	parameter	WPREACTIVEDEPTH		= 8,		//must be 2**n
	parameter	RPREACTIVEDEPTH		= 8,		//must be 2**n
	parameter	RWBUFFERDEPTH		= 16		//must be 2**n
) (
	input						I_clk,
	input						I_rstn,

	input						I_wvalid,
	input	[ADDRWIDTH-1:0]		I_waddr,
	input	[DATAWIDTH-1:0]		I_wdata,
	input	[PHYDQMWIDTH-1:0]	I_wdqm,
	output						O_wready,

	input						I_rvalid,
	input	[ADDRWIDTH-1:0]		I_raddr,
	input	[PHYDQMWIDTH-1:0]	I_rdqm,
	output						O_rready,

	output						O_all_precharged,
	output						O_precharge_valid,
	output	[BANKADDRWIDTH-1:0]	O_precharge_bank_addr,
	input						I_precharge_ready,

	output						O_active_valid,
	output	[BANKADDRWIDTH-1:0]	O_active_bank_addr,
	output	[ROWADDRWIDTH-1:0]	O_active_row_addr,
	input						I_active_ready,

	output						O_wr_rd_valid,
	output						O_wr_rd_cmden,
	output						O_wr_rd_is_rd,
	output	[ADDRWIDTH-1:0]		O_wr_rd_addr,
	output	[DATAWIDTH-1:0]		O_wr_rd_data,
	output	[PHYDQMWIDTH-1:0]	O_wr_rd_dqm,
	input						I_wr_rd_ready
);


localparam ACTUAL_RWBUFFERDEPTH = WPREACTIVEDEPTH + RPREACTIVEDEPTH + RWBUFFERDEPTH + 1;
localparam RWBUFCNTWIDTH	= $clog2(ACTUAL_RWBUFFERDEPTH+1);
wire W_wr_inc;
wire [BANKADDRWIDTH-1:0] W_wr_inc_ba;
wire W_rd_inc;
wire [BANKADDRWIDTH-1:0] W_rd_inc_ba;
wire [BANKNUM-1:0] W_bank_precharge_prepared;
wire [BANKNUM-1:0] W_bank_active_prepared;
wire [BANKNUM-1:0] W_bank_wr_rd_prepared;
wire [BANKNUM-1:0] W_bank_is_active;
wire [BANKNUM-1:0] W_bank_is_phy_active;
wire [ROWADDRWIDTH-1:0]	W_bank_active_row[BANKNUM-1:0];
wire [RWBUFCNTWIDTH-1:0] W_bank_rw_num[BANKNUM-1:0];

wire [ROWADDRWIDTH*BANKNUM-1:0] W_bank_active_row_flat;
genvar i;
generate
	for(i = 0; i < BANKNUM; i = i + 1)
	begin:FLAT_BANK_ACTIVE_ROW
		assign W_bank_active_row_flat[ROWADDRWIDTH*(i+1)-1:ROWADDRWIDTH*i] = W_bank_active_row[i];
	end
endgenerate


wire						W_logic_active_valid;
wire	[BANKADDRWIDTH-1:0]	W_logic_active_bank_addr;
wire	[ROWADDRWIDTH-1:0]	W_logic_active_row_addr;

wire						W_post_active_wvalid;
wire	[ADDRWIDTH-1:0]		W_post_active_waddr;
wire	[DATAWIDTH-1:0]		W_post_active_wdata;
wire	[PHYDQMWIDTH-1:0]	W_post_active_wdqm;
wire						W_post_active_wready;

wire						W_post_active_rvalid;
wire	[ADDRWIDTH-1:0]		W_post_active_raddr;
wire	[PHYDQMWIDTH-1:0]	W_post_active_rdqm;
wire						W_post_active_rready;

sdram_bank_active #(
	.ADDRWIDTH				(ADDRWIDTH),
	.DATAWIDTH				(DATAWIDTH),
	.BANKNUM				(BANKNUM),
	.PHYDQMWIDTH			(PHYDQMWIDTH),
	.BANKADDRWIDTH			(BANKADDRWIDTH),
	.ROWADDRWIDTH			(ROWADDRWIDTH),
	.COLADDRWIDTH			(COLADDRWIDTH),
	.WPREACTIVEDEPTH		(WPREACTIVEDEPTH),
	.RPREACTIVEDEPTH		(RPREACTIVEDEPTH)
) sdram_bank_active_u(
	.I_clk						(I_clk),
	.I_rstn						(I_rstn),

	.I_wvalid					(I_wvalid),
	.I_waddr					(I_waddr),
	.I_wdata					(I_wdata),
	.I_wdqm						(I_wdqm),
	.O_wready					(O_wready),

	.I_rvalid					(I_rvalid),
	.I_raddr					(I_raddr),
	.I_rdqm						(I_rdqm),
	.O_rready					(O_rready),

	.I_bank_precharge_prepared	(W_bank_precharge_prepared),
	.I_bank_active_prepared		(W_bank_active_prepared),
	.I_bank_is_active			(W_bank_is_active),
	.I_bank_active_row_flat		(W_bank_active_row_flat),
	.O_wr_inc					(W_wr_inc),
	.O_wr_inc_ba				(W_wr_inc_ba),
	.O_rd_inc					(W_rd_inc),
	.O_rd_inc_ba				(W_rd_inc_ba),

	.O_logic_active_valid		(W_logic_active_valid),
	.O_logic_active_bank_addr	(W_logic_active_bank_addr),
	.O_logic_active_row_addr	(W_logic_active_row_addr),

	.O_active_valid				(O_active_valid),
	.O_active_bank_addr			(O_active_bank_addr),
	.O_active_row_addr			(O_active_row_addr),
	.I_active_ready				(I_active_ready),

	.O_wvalid					(W_post_active_wvalid),
	.O_waddr					(W_post_active_waddr),
	.O_wdata					(W_post_active_wdata),
	.O_wdqm						(W_post_active_wdqm),
	.I_wready					(W_post_active_wready),

	.O_rvalid					(W_post_active_rvalid),
	.O_raddr					(W_post_active_raddr),
	.O_rdqm						(W_post_active_rdqm),
	.I_rready					(W_post_active_rready)
);


sdram_bank_rw #(
	.ADDRWIDTH				(ADDRWIDTH),
	.DATAWIDTH				(DATAWIDTH),
	.BANKNUM				(BANKNUM),
	.PHYDQMWIDTH			(PHYDQMWIDTH),
	.BANKADDRWIDTH			(BANKADDRWIDTH),
	.BURSTLENGTH			(BURSTLENGTH),
	.BURSTTYPE				(BURSTTYPE),
	.RWBUFFERDEPTH			(RWBUFFERDEPTH)
) sdram_bank_rw_u(
	.I_clk						(I_clk),
	.I_rstn						(I_rstn),

	.I_wvalid					(W_post_active_wvalid),
	.I_waddr					(W_post_active_waddr),
	.I_wdata					(W_post_active_wdata),
	.I_wdqm						(W_post_active_wdqm),
	.O_wready					(W_post_active_wready),

	.I_rvalid					(W_post_active_rvalid),
	.I_raddr					(W_post_active_raddr),
	.I_rdqm						(W_post_active_rdqm),
	.O_rready					(W_post_active_rready),

	.I_bank_wr_rd_prepared		(W_bank_wr_rd_prepared),

	.O_wr_rd_valid				(O_wr_rd_valid),
	.O_wr_rd_cmden				(O_wr_rd_cmden),
	.O_wr_rd_is_rd				(O_wr_rd_is_rd),
	.O_wr_rd_addr				(O_wr_rd_addr),
	.O_wr_rd_data				(O_wr_rd_data),
	.O_wr_rd_dqm				(O_wr_rd_dqm),
	.I_wr_rd_ready				(I_wr_rd_ready)
);


reg [BANKADDRWIDTH-1:0] R_precharge_bank_loop;
reg [BANKADDRWIDTH-1:0] R_precharge_bank_addr;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_precharge_bank_loop <= {BANKADDRWIDTH{1'b0}};
	else if(R_precharge_bank_loop == (BANKNUM - 1'b1))
		R_precharge_bank_loop <= {BANKADDRWIDTH{1'b0}};
	else 
		R_precharge_bank_loop <= R_precharge_bank_loop + 1'b1;
	
	if(!I_rstn)
		R_precharge_bank_addr <= {BANKADDRWIDTH{1'b0}};
	else if(!W_bank_is_phy_active[R_precharge_bank_loop])
		R_precharge_bank_addr <= R_precharge_bank_addr;
	else if(!W_bank_is_phy_active[R_precharge_bank_addr])
		R_precharge_bank_addr <= R_precharge_bank_loop;
	else if(W_bank_rw_num[R_precharge_bank_loop] < W_bank_rw_num[R_precharge_bank_addr])
		R_precharge_bank_addr <= R_precharge_bank_loop;
	else 
		R_precharge_bank_addr <= R_precharge_bank_addr;
end

assign O_all_precharged = !(|W_bank_is_phy_active);
assign O_precharge_valid = W_bank_precharge_prepared[R_precharge_bank_addr];
assign O_precharge_bank_addr = R_precharge_bank_addr;


genvar k;
generate
	for(k = 0; k < BANKNUM; k = k + 1)
	begin:BANK_STATE_GEN
		sdram_bank_state #(
			.CLK_FREQ			(CLK_FREQ),
			.ROWADDRWIDTH		(ROWADDRWIDTH),
			.RWBUFFERDEPTH		(ACTUAL_RWBUFFERDEPTH),
			.RWBUFCNTWIDTH		(RWBUFCNTWIDTH)
		) sdram_bank_state_u(
			.I_clk					(I_clk),
			.I_rstn					(I_rstn),

			.I_precharge_valid		(I_precharge_ready && (O_precharge_bank_addr == k)),
			.I_active_valid			(W_logic_active_valid && (W_logic_active_bank_addr == k)),
			.I_active_row			(W_logic_active_row_addr),
			.I_active_cmd			(I_active_ready && (O_active_bank_addr == k)),
			.I_wr_inc				(W_wr_inc && (W_wr_inc_ba == k)),
			.I_rd_inc				(W_rd_inc && (W_rd_inc_ba == k)),
			.I_wr_rd_dec			(I_wr_rd_ready && (O_wr_rd_addr[ADDRWIDTH-1 : ADDRWIDTH-BANKADDRWIDTH] == k)),
			.I_dec_cmden			(O_wr_rd_cmden),
			.I_dec_is_rd			(O_wr_rd_is_rd),
			.O_precharge_prepared	(W_bank_precharge_prepared[k]),
			.O_active_prepared		(W_bank_active_prepared[k]),
			.O_wr_rd_prepared		(W_bank_wr_rd_prepared[k]),
			.O_is_active			(W_bank_is_active[k]),
			.O_is_phy_active		(W_bank_is_phy_active[k]),
			.O_active_row			(W_bank_active_row[k]),
			.O_rw_num				(W_bank_rw_num[k])
		);
	end
endgenerate


endmodule
