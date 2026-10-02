module sdram_controller #(
	parameter	CLK_FREQ			= 125_000_000,
	parameter	ADDRRANK			= "BRC",	//"BRC" "RBC"	//{BANK, ROW, COLUMN} or {ROW, BANK, COLUMN}
	parameter	ADDRWIDTH			= 21,
	parameter	DATAWIDTH			= 32,
	parameter	BANKNUM				= 4,
	parameter	ROWNUM				= 2048,
	parameter	COLNUM				= 256,
	parameter	PHYADDRWIDTH		= 11,
	parameter	PHYBANKWIDTH		= 2,
	parameter	PHYDQMWIDTH			= DATAWIDTH/8,
	parameter	CASLATENCY			= 3,
	parameter	POWERUP_DELAYMS		= 1000,
	parameter	BURSTLENGTH			= 4,
	parameter	BURSTTYPE			= "SEQUENTIAL",		//"SEQUENTIAL" "INTERLEAVE"

	parameter	INWBUFFERDEPTH		= 16,		//must be 2**n or 0
	parameter	WDATABATCHLENGTH	= 8,		//must < INWBUFFERDEPTH, or be 0
	parameter	WMAXBATCHDELAY		= 20,		//if it == 0, means infinity
	parameter	INRBUFFERDEPTH		= 16,		//must be 2**n or 0
	parameter	RDATABATCHLENGTH	= 8,		//must < INRBUFFERDEPTH, or be 0
	parameter	RMAXBATCHDELAY		= 20,		//if it == 0, means infinity
	
	parameter	WPREACTIVEDEPTH		= 8,		//must be 2**n and should >= 8
	parameter	RPREACTIVEDEPTH		= 8,		//must be 2**n and should >= 8
	parameter	RWBUFFERDEPTH		= 16,		//must be 2**n and >= 4
	parameter	AUTO_REFRESH		= "ENABLE",	//"ENABLE" "DISABLE"
	parameter	REFRESH_TIME_MS		= 64,
	parameter	REFRESH_LINE		= 4096,
	parameter	REFRESH_SLICE		= 16		//suggest >= 4, must >= 2, must <= REFRESH_TIME_MS
) (
	input						I_clk,
	input						I_dq_retclk,
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

localparam	BANKADDRWIDTH	= $clog2(BANKNUM);
localparam	ROWADDRWIDTH	= $clog2(ROWNUM);
localparam	COLADDRWIDTH	= $clog2(COLNUM);


wire [ADDRWIDTH-1:0] W_rank_waddr;
wire [ADDRWIDTH-1:0] W_rank_raddr;
wire [ADDRWIDTH-1:0] W_rank_out_addr;

begin
	if(ADDRRANK == "BRC")begin
		assign W_rank_waddr	= I_waddr;
		assign W_rank_raddr	= I_raddr;
		assign O_out_addr	= W_rank_out_addr;
	end
	else begin
		localparam BCADDRWIDTH = BANKADDRWIDTH + COLADDRWIDTH;
		localparam RCADDRWIDTH = ROWADDRWIDTH + COLADDRWIDTH;
		assign W_rank_waddr	= {I_waddr[BCADDRWIDTH-1:COLADDRWIDTH], I_waddr[ADDRWIDTH-1:BCADDRWIDTH], I_waddr[COLADDRWIDTH-1:0]};
		assign W_rank_raddr	= {I_raddr[BCADDRWIDTH-1:COLADDRWIDTH], I_raddr[ADDRWIDTH-1:BCADDRWIDTH], I_raddr[COLADDRWIDTH-1:0]};
		wire [COLADDRWIDTH-1:0] W_out_col_addr = W_rank_out_addr[COLADDRWIDTH-1:0];
		assign O_out_addr	= {W_rank_out_addr[RCADDRWIDTH-1:COLADDRWIDTH], W_rank_out_addr[ADDRWIDTH-1:RCADDRWIDTH], W_out_col_addr};
	end
end


wire						W_init_done;
wire	[2:0]				W_init_cmd;
wire	[PHYBANKWIDTH-1:0]	W_init_bank;
wire	[PHYADDRWIDTH-1:0]	W_init_addr;

sdram_init #(
	.CLK_FREQ			(CLK_FREQ		),
	.PHYADDRWIDTH		(PHYADDRWIDTH	),
	.PHYBANKWIDTH		(PHYBANKWIDTH	),
	.CASLATENCY			(CASLATENCY		),
	.POWERUP_DELAYMS	(POWERUP_DELAYMS),
	.BURSTLENGTH		(BURSTLENGTH	),
	.BURSTTYPE			(BURSTTYPE		)
) sdram_init_u(
	.I_clk				(I_clk),
	.I_rstn				(I_rstn),

	.O_init_done		(W_init_done),
	.O_init_cmd			(W_init_cmd),
	.O_init_bank		(W_init_bank),
	.O_init_addr		(W_init_addr)
);


wire W_refresh_immediately;
wire W_refresh_no_immediately;
wire W_refresh_ready;

begin
	if(AUTO_REFRESH == "ENABLE")begin
		reg R_ref_rstn;
		always @(posedge I_clk or negedge I_rstn)begin
			if(!I_rstn)
				R_ref_rstn <= 1'b0;
			else 
				R_ref_rstn <= W_init_done;
		end
		intelli_refresh#(
			.CLK_FREQ			(CLK_FREQ		),
			.REFRESH_TIME_MS	(REFRESH_TIME_MS),
			.REFRESH_LINE		(REFRESH_LINE	),
			.REFRESH_SLICE		(REFRESH_SLICE	)
		) intelli_refresh_u(
			.I_clk						(I_clk),
			.I_rstn						(R_ref_rstn),

			.O_refresh_immediately		(W_refresh_immediately),
			.O_refresh_no_immediately	(W_refresh_no_immediately),
			.I_refresh_ready			(W_refresh_ready)
		);
	end
	else begin
		assign W_refresh_immediately = 1'b0;
		assign W_refresh_no_immediately = 1'b0;
	end
end


wire						W_wvalid;
wire	[ADDRWIDTH-1:0]		W_waddr;
wire	[DATAWIDTH-1:0]		W_wdata;
wire	[PHYDQMWIDTH-1:0]	W_wdqm;
wire						W_wready;

begin
	if(INWBUFFERDEPTH == 0)begin
		assign W_wvalid	= I_wvalid;
		assign W_waddr	= W_rank_waddr;
		assign W_wdata	= I_wdata;
		assign W_wdqm	= I_wdqm;
		assign O_wready	= W_wready;
	end
	else begin
		wire	W_inw_full;
		wire	W_inw_empty;

		wire W_wbatch_re;
		wire [ADDRWIDTH+PHYDQMWIDTH+DATAWIDTH-1:0] W_wbatch_rdata;
		wire W_wbatch_empty;

		simple_sync_fifo_sdram_adapt #(
			.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH+DATAWIDTH),
			.DATADEPTH		((INWBUFFERDEPTH < 4) ? 4 : INWBUFFERDEPTH),	//must be 2**n
			.SHOWAHEAD		("ENABLE"),	//"ENABLE" "DISABLE"
			.TIM_PRIOR		("ADDRESS")	//"DATA" "ADDRESS"
		) simple_sync_fifo_inw(
			.I_clk			(I_clk),
			.I_rstn			(I_rstn),

			.I_we			(O_wready),
			.I_wdata		({W_rank_waddr, I_wdqm, I_wdata}),
			.O_full			(W_inw_full),

			.I_re			(W_wbatch_re),
			.O_rdata		(W_wbatch_rdata),
			.O_empty		(W_wbatch_empty)
		);

		assign O_wready = (!W_inw_full) && I_wvalid;

		if((WDATABATCHLENGTH <= 1) || (WDATABATCHLENGTH >= INWBUFFERDEPTH))begin
			assign W_wbatch_re = W_wready;
			assign {W_waddr, W_wdqm, W_wdata} = W_wbatch_rdata;
			assign W_inw_empty = W_wbatch_empty;

			assign W_wvalid = !W_inw_empty;
		end
		else begin
			data_batch #(
				.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH+DATAWIDTH),
				.BUFFERDEPTH	((INWBUFFERDEPTH < 4) ? 4 : INWBUFFERDEPTH),
				.BATCH_LENGTH	(WDATABATCHLENGTH),
				.MAX_DELAY		(WMAXBATCHDELAY)
			) data_wbatch_u(
				.I_clk			(I_clk),
				.I_rstn			(I_rstn),

				.I_we			(O_wready),

				.O_re			(W_wbatch_re),
				.I_rdata		(W_wbatch_rdata),
				.I_empty		(W_wbatch_empty),

				.O_valid		(W_wvalid),
				.O_data			({W_waddr, W_wdqm, W_wdata}),
				.I_ready		(W_wready)
			);
		end
	end
end

wire						W_rvalid;
wire	[ADDRWIDTH-1:0]		W_raddr;
wire	[PHYDQMWIDTH-1:0]	W_rdqm;
wire						W_rready;

begin
	if(INRBUFFERDEPTH == 0)begin
		assign W_rvalid	= I_rvalid;
		assign W_raddr	= W_rank_raddr;
		assign W_rdqm	= I_rdqm;
		assign O_rready	= W_rready;
	end
	else begin
		wire	W_inr_full;
		wire	W_inr_empty;

		wire W_rbatch_re;
		wire [ADDRWIDTH+PHYDQMWIDTH-1:0] W_rbatch_rdata;
		wire W_rbatch_empty;
		
		simple_sync_fifo_sdram_adapt #(
			.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH),
			.DATADEPTH		((INRBUFFERDEPTH < 4) ? 4 : INRBUFFERDEPTH),	//must be 2**n
			.SHOWAHEAD		("ENABLE"),	//"ENABLE" "DISABLE"
			.TIM_PRIOR		("ADDRESS")	//"DATA" "ADDRESS"
		) simple_sync_fifo_inr(
			.I_clk			(I_clk),
			.I_rstn			(I_rstn),

			.I_we			(O_rready),
			.I_wdata		({W_rank_raddr, I_rdqm}),
			.O_full			(W_inr_full),

			.I_re			(W_rbatch_re),
			.O_rdata		(W_rbatch_rdata),
			.O_empty		(W_rbatch_empty)
		);

		assign O_rready = (!W_inr_full) && I_rvalid;

		if((RDATABATCHLENGTH <= 1) || (RDATABATCHLENGTH >= INRBUFFERDEPTH))begin
			assign W_rbatch_re = W_rready;
			assign {W_raddr, W_rdqm} = W_rbatch_rdata;
			assign W_inr_empty = W_rbatch_empty;

			assign W_rvalid = !W_inr_empty;
		end
		else begin
			data_batch #(
				.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH),
				.BUFFERDEPTH	((INRBUFFERDEPTH < 4) ? 4 : INRBUFFERDEPTH),
				.BATCH_LENGTH	(RDATABATCHLENGTH),
				.MAX_DELAY		(RMAXBATCHDELAY)
			) data_rbatch_u(
				.I_clk			(I_clk),
				.I_rstn			(I_rstn),

				.I_we			(O_rready),

				.O_re			(W_rbatch_re),
				.I_rdata		(W_rbatch_rdata),
				.I_empty		(W_rbatch_empty),

				.O_valid		(W_rvalid),
				.O_data			({W_raddr, W_rdqm}),
				.I_ready		(W_rready)
			);
		end
	end
end


wire						W_all_precharged;
wire						W_precharge_valid;
wire	[BANKADDRWIDTH-1:0]	W_precharge_bank_addr;
wire						W_precharge_ready;

wire						W_active_valid;
wire	[BANKADDRWIDTH-1:0]	W_active_bank_addr;
wire	[ROWADDRWIDTH-1:0]	W_active_row_addr;
wire						W_active_ready;

wire						W_wr_rd_valid;
wire						W_wr_rd_cmden;
wire						W_wr_rd_is_rd;
wire	[ADDRWIDTH-1:0]		W_wr_rd_addr;
wire	[DATAWIDTH-1:0]		W_wr_rd_data;
wire	[PHYDQMWIDTH-1:0]	W_wr_rd_dqm;
wire						W_wr_rd_ready;

sdram_bank_manage #(
	.CLK_FREQ				(CLK_FREQ),
	.ADDRWIDTH				(ADDRWIDTH),
	.DATAWIDTH				(DATAWIDTH),
	.BANKNUM				(BANKNUM),
	.PHYDQMWIDTH			(PHYDQMWIDTH),
	.BANKADDRWIDTH			(BANKADDRWIDTH),
	.ROWADDRWIDTH			(ROWADDRWIDTH),
	.COLADDRWIDTH			(COLADDRWIDTH),
	.BURSTLENGTH			(BURSTLENGTH),
	.BURSTTYPE				(BURSTTYPE),
	.WPREACTIVEDEPTH		(WPREACTIVEDEPTH),
	.RPREACTIVEDEPTH		(RPREACTIVEDEPTH),
	.RWBUFFERDEPTH			(RWBUFFERDEPTH)
) sdram_bank_manage_u(
	.I_clk						(I_clk),
	.I_rstn						(I_rstn),

	.I_wvalid					(W_wvalid),
	.I_waddr					(W_waddr),
	.I_wdata					(W_wdata),
	.I_wdqm						(W_wdqm),
	.O_wready					(W_wready),

	.I_rvalid					(W_rvalid),
	.I_raddr					(W_raddr),
	.I_rdqm						(W_rdqm),
	.O_rready					(W_rready),

	.O_all_precharged			(W_all_precharged),
	.O_precharge_valid			(W_precharge_valid),
	.O_precharge_bank_addr		(W_precharge_bank_addr),
	.I_precharge_ready			(W_precharge_ready),

	.O_active_valid				(W_active_valid),
	.O_active_bank_addr			(W_active_bank_addr),
	.O_active_row_addr			(W_active_row_addr),
	.I_active_ready				(W_active_ready),

	.O_wr_rd_valid				(W_wr_rd_valid),
	.O_wr_rd_cmden				(W_wr_rd_cmden),
	.O_wr_rd_is_rd				(W_wr_rd_is_rd),
	.O_wr_rd_addr				(W_wr_rd_addr),
	.O_wr_rd_data				(W_wr_rd_data),
	.O_wr_rd_dqm				(W_wr_rd_dqm),
	.I_wr_rd_ready				(W_wr_rd_ready)
);


sdram_operate #(
	.CLK_FREQ				(CLK_FREQ),
	.ADDRWIDTH				(ADDRWIDTH),
	.DATAWIDTH				(DATAWIDTH),
	.PHYADDRWIDTH			(PHYADDRWIDTH),
	.PHYBANKWIDTH			(PHYBANKWIDTH),
	.PHYDQMWIDTH			(PHYDQMWIDTH),
	.CASLATENCY				(CASLATENCY),
	.BANKADDRWIDTH			(BANKADDRWIDTH),
	.ROWADDRWIDTH			(ROWADDRWIDTH),
	.COLADDRWIDTH			(COLADDRWIDTH),
	.BURSTLENGTH			(BURSTLENGTH)
) sdram_operate_u(
	.I_clk						(I_clk),
	.I_dq_retclk				(I_dq_retclk),
	.I_rstn						(I_rstn),

	.I_init_done				(W_init_done),
	.I_init_cmd					(W_init_cmd),
	.I_init_bank				(W_init_bank),
	.I_init_addr				(W_init_addr),

	.I_refresh_immediately		(W_refresh_immediately),
	.I_refresh_no_immediately	(W_refresh_no_immediately),
	.O_refresh_ready			(W_refresh_ready),

	.I_all_precharged			(W_all_precharged),
	.I_precharge_valid			(W_precharge_valid),
	.I_precharge_bank_addr		(W_precharge_bank_addr),
	.O_precharge_ready			(W_precharge_ready),

	.I_active_valid				(W_active_valid),
	.I_active_bank_addr			(W_active_bank_addr),
	.I_active_row_addr			(W_active_row_addr),
	.O_active_ready				(W_active_ready),

	.I_wr_rd_valid				(W_wr_rd_valid),
	.I_wr_rd_cmden				(W_wr_rd_cmden),
	.I_wr_rd_is_rd				(W_wr_rd_is_rd),
	.I_wr_rd_addr				(W_wr_rd_addr),
	.I_wr_rd_data				(W_wr_rd_data),
	.I_wr_rd_dqm				(W_wr_rd_dqm),
	.O_wr_rd_ready				(W_wr_rd_ready),

	.O_out_valid				(O_out_valid),
	.O_out_addr					(W_rank_out_addr),
	.O_out_data					(O_out_data),
	.O_out_dqm					(O_out_dqm),

	.O_sdram_clk				(O_sdram_clk),
	.O_sdram_cke				(O_sdram_cke),
	.O_sdram_csn				(O_sdram_csn),
	.O_sdram_rasn				(O_sdram_rasn),
	.O_sdram_casn				(O_sdram_casn),
	.O_sdram_wen				(O_sdram_wen),
	.O_sdram_bank				(O_sdram_bank),
	.O_sdram_addr				(O_sdram_addr),
	.I_sdram_data				(I_sdram_data),
	.O_sdram_data_en			(O_sdram_data_en),
	.O_sdram_data				(O_sdram_data),
	.O_sdram_dqm				(O_sdram_dqm)
);



endmodule
