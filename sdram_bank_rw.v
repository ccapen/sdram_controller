module sdram_bank_rw #(
	parameter	ADDRWIDTH			= 21,
	parameter	DATAWIDTH			= 32,
	parameter	BANKNUM				= 4,
	parameter	PHYDQMWIDTH			= DATAWIDTH/8,
	parameter	BANKADDRWIDTH		= 2,
	parameter	BURSTLENGTH			= 4,
	parameter	BURSTTYPE			= "SEQUENTIAL",		//"SEQUENTIAL" "INTERLEAVE"
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

	input	[BANKNUM-1:0]		I_bank_wr_rd_prepared,

	output						O_wr_rd_valid,
	output						O_wr_rd_cmden,
	output						O_wr_rd_is_rd,
	output	[ADDRWIDTH-1:0]		O_wr_rd_addr,
	output	[DATAWIDTH-1:0]		O_wr_rd_data,
	output	[PHYDQMWIDTH-1:0]	O_wr_rd_dqm,
	input						I_wr_rd_ready
);

wire						W_wvalid;
wire	[ADDRWIDTH-1:0]		W_waddr;
wire	[DATAWIDTH-1:0]		W_wdata;
wire	[PHYDQMWIDTH-1:0]	W_wdqm;
wire						W_wready;

wire						W_rvalid;
wire	[ADDRWIDTH-1:0]		W_raddr;
wire	[PHYDQMWIDTH-1:0]	W_rdqm;
wire						W_rready;

buffer_delay #(
	.DATAWIDTH		(ADDRWIDTH+DATAWIDTH+PHYDQMWIDTH)
) buffer_delay_write(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_valid		(I_wvalid),
	.I_data			({I_waddr, I_wdata, I_wdqm}),
	.O_ready		(O_wready),

	.O_valid		(W_wvalid),
	.O_data			({W_waddr, W_wdata, W_wdqm}),
	.I_ready		(W_wready)
);

buffer_delay #(
	.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH)
) buffer_delay_read(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_valid		(I_rvalid),
	.I_data			({I_raddr, I_rdqm}),
	.O_ready		(O_rready),

	.O_valid		(W_rvalid),
	.O_data			({W_raddr, W_rdqm}),
	.I_ready		(W_rready)
);


localparam BURSTCNTWIDTH	= $clog2(BURSTLENGTH);

wire W_rwfifo_full;
wire W_rwfifo_empty;

reg R_current_is_rd;
reg R_last_is_rd;
reg R_is_same_wblock;
reg R_is_same_rblock;

wire 					W_burst_valid	= R_current_is_rd ? W_rvalid : W_wvalid;
wire [ADDRWIDTH-1:0]	W_burst_addr	= R_current_is_rd ? W_raddr : W_waddr;
wire [DATAWIDTH-1:0]	W_burst_data	= R_current_is_rd ? {DATAWIDTH{1'b0}} : W_wdata;
wire [PHYDQMWIDTH-1:0]	W_burst_dqm		= R_current_is_rd ? W_rdqm : W_wdqm;
wire					W_is_same_block	= R_current_is_rd ? R_is_same_rblock : R_is_same_wblock;

reg [BURSTCNTWIDTH-1:0] R_cnt_burst;
reg [BURSTCNTWIDTH-1:0] R_burst_saddr;	//start addr
wire [BURSTCNTWIDTH-1:0] W_seq_caddr = (R_burst_saddr + (~R_cnt_burst) + 1'b1);
wire [BURSTCNTWIDTH-1:0] W_int_caddr = (R_burst_saddr ~^ R_cnt_burst);
wire [BURSTCNTWIDTH-1:0] W_burst_caddr = (BURSTTYPE == "SEQUENTIAL") ? W_seq_caddr : W_int_caddr;	//current addr
reg [ADDRWIDTH-1:0] R_last_addr;

wire W_burst_addr_match = (R_current_is_rd == R_last_is_rd) && W_is_same_block && (W_burst_addr[BURSTCNTWIDTH-1:0] == W_burst_caddr);
wire W_burst_cmden = ((!W_burst_addr_match) || (R_cnt_burst == {BURSTCNTWIDTH{1'b0}}) || W_rwfifo_empty);

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_current_is_rd <= 1'b0;
	else if(W_rwfifo_full || W_wready || W_rready)
		R_current_is_rd <= R_current_is_rd;
	else 
		R_current_is_rd <= !R_current_is_rd;

	if(!I_rstn)
		R_last_is_rd <= 1'b0;
	else if(W_wready || W_rready)
		R_last_is_rd <= R_current_is_rd;
	else 
		R_last_is_rd <= R_last_is_rd;

	if(!I_rstn)
		R_is_same_wblock <= 1'b0;
	else if(O_wready)
		R_is_same_wblock <= (I_waddr[ADDRWIDTH-1:BURSTCNTWIDTH] == W_waddr[ADDRWIDTH-1:BURSTCNTWIDTH]);
	else 
		R_is_same_wblock <= R_is_same_wblock;

	if(!I_rstn)
		R_is_same_rblock <= 1'b0;
	else if(O_rready)
		R_is_same_rblock <= (I_raddr[ADDRWIDTH-1:BURSTCNTWIDTH] == W_raddr[ADDRWIDTH-1:BURSTCNTWIDTH]);
	else 
		R_is_same_rblock <= R_is_same_rblock;

	if(!I_rstn)
		R_cnt_burst <= {BURSTCNTWIDTH{1'b0}};
	else if(!(W_wready || W_rready))
		R_cnt_burst <= R_cnt_burst;
	else if(W_burst_cmden)
		R_cnt_burst <= (BURSTLENGTH - 1'b1);
	else if(R_cnt_burst == {BURSTCNTWIDTH{1'b0}})
		R_cnt_burst <= {BURSTCNTWIDTH{1'b0}};
	else 
		R_cnt_burst <= R_cnt_burst - 1'b1;

	if(!I_rstn)
		R_burst_saddr <= {BURSTCNTWIDTH{1'b0}};
	else if((W_wready || W_rready) && W_burst_cmden)
		R_burst_saddr <= W_burst_addr[BURSTCNTWIDTH-1:0];
	else 
		R_burst_saddr <= R_burst_saddr;

	if(!I_rstn)
		R_last_addr <= {ADDRWIDTH{1'b0}};
	else if(W_wready || W_rready)
		R_last_addr <= W_burst_addr;
	else 
		R_last_addr <= R_last_addr;
end

assign W_wready = W_wvalid && (!W_rwfifo_full) && (!R_current_is_rd);
assign W_rready = W_rvalid && (!W_rwfifo_full) && ( R_current_is_rd);


wire						W_wr_rd_valid;
wire						W_wr_rd_cmden;
wire						W_wr_rd_is_rd;
wire	[ADDRWIDTH-1:0]		W_wr_rd_addr;
wire	[DATAWIDTH-1:0]		W_wr_rd_data;
wire	[PHYDQMWIDTH-1:0]	W_wr_rd_dqm;
wire						W_wr_rd_ready;

simple_sync_fifo_sdram_adapt #(
	.DATAWIDTH		(2+ADDRWIDTH+PHYDQMWIDTH+DATAWIDTH),
	.DATADEPTH		(RWBUFFERDEPTH),	//must be 2**n
	.SHOWAHEAD		("ENABLE"),	//"ENABLE" "DISABLE"
	.TIM_PRIOR		("ADDRESS")	//"DATA" "ADDRESS"
) simple_sync_fifo_rw(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_we			(W_wready || W_rready),
	.I_wdata		({W_burst_cmden, R_current_is_rd, W_burst_addr, W_burst_dqm, W_burst_data}),
	.O_full			(W_rwfifo_full),

	.I_re			(W_wr_rd_ready),
	.O_rdata		({W_wr_rd_cmden, W_wr_rd_is_rd, W_wr_rd_addr, W_wr_rd_dqm, W_wr_rd_data}),
	.O_empty		(W_rwfifo_empty)
);

assign W_wr_rd_valid = (!W_rwfifo_empty);
wire	W_wr_rd_out_valid;

buffer_delay #(
	.DATAWIDTH		(2+ADDRWIDTH+PHYDQMWIDTH+DATAWIDTH)
) buffer_delay_wr_rd_out(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_valid		(W_wr_rd_valid),
	.I_data			({W_wr_rd_cmden, W_wr_rd_is_rd, W_wr_rd_addr, W_wr_rd_dqm, W_wr_rd_data}),
	.O_ready		(W_wr_rd_ready),

	.O_valid		(W_wr_rd_out_valid),
	.O_data			({O_wr_rd_cmden, O_wr_rd_is_rd, O_wr_rd_addr, O_wr_rd_dqm, O_wr_rd_data}),
	.I_ready		(I_wr_rd_ready)
);

assign O_wr_rd_valid = W_wr_rd_out_valid && I_bank_wr_rd_prepared[O_wr_rd_addr[ADDRWIDTH-1:ADDRWIDTH-BANKADDRWIDTH]];



endmodule
