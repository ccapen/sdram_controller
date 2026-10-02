module sdram_bank_active #(
	parameter	ADDRWIDTH			= 21,
	parameter	DATAWIDTH			= 32,
	parameter	BANKNUM				= 4,
	parameter	PHYDQMWIDTH			= DATAWIDTH/8,
	parameter	BANKADDRWIDTH		= 2,
	parameter	ROWADDRWIDTH		= 11,
	parameter	COLADDRWIDTH		= 8,
	parameter	WPREACTIVEDEPTH		= 8,		//must be 2**n
	parameter	RPREACTIVEDEPTH		= 8,		//must be 2**n
	parameter	FLATROWADDRWIDTH	= (BANKNUM * ROWADDRWIDTH)
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

	input	[BANKNUM-1:0]		I_bank_precharge_prepared,
	input	[BANKNUM-1:0]		I_bank_active_prepared,
	input	[BANKNUM-1:0]		I_bank_is_active,
	input	[FLATROWADDRWIDTH-1:0]	I_bank_active_row_flat,
	output 						O_wr_inc,
	output 	[BANKADDRWIDTH-1:0]	O_wr_inc_ba,
	output 						O_rd_inc,
	output 	[BANKADDRWIDTH-1:0]	O_rd_inc_ba,

	output						O_logic_active_valid,
	output	[BANKADDRWIDTH-1:0]	O_logic_active_bank_addr,
	output	[ROWADDRWIDTH-1:0]	O_logic_active_row_addr,

	output						O_active_valid,
	output	[BANKADDRWIDTH-1:0]	O_active_bank_addr,
	output	[ROWADDRWIDTH-1:0]	O_active_row_addr,
	input						I_active_ready,

	output						O_wvalid,
	output	[ADDRWIDTH-1:0]		O_waddr,
	output	[DATAWIDTH-1:0]		O_wdata,
	output	[PHYDQMWIDTH-1:0]	O_wdqm,
	input						I_wready,

	output						O_rvalid,
	output	[ADDRWIDTH-1:0]		O_raddr,
	output	[PHYDQMWIDTH-1:0]	O_rdqm,
	input						I_rready
);

wire [ROWADDRWIDTH-1:0] W_bank_active_row[BANKNUM-1:0];
genvar i;
generate
	for(i = 0; i < BANKNUM; i = i + 1)
	begin:DEFLAT_BANK_ACTIVE_ROW
		assign W_bank_active_row[i] = I_bank_active_row_flat[ROWADDRWIDTH*(i+1)-1:ROWADDRWIDTH*i];
	end
endgenerate

wire						W_pre_wvalid;
wire	[ADDRWIDTH-1:0]		W_pre_waddr;
wire	[DATAWIDTH-1:0]		W_pre_wdata;
wire	[PHYDQMWIDTH-1:0]	W_pre_wdqm;
wire						W_pre_wready;

wire						W_pre_rvalid;
wire	[ADDRWIDTH-1:0]		W_pre_raddr;
wire	[PHYDQMWIDTH-1:0]	W_pre_rdqm;
wire						W_pre_rready;

timing_split #(
	.DATAWIDTH		(ADDRWIDTH+DATAWIDTH+PHYDQMWIDTH)
) timing_split_write(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_valid		(I_wvalid),
	.I_data			({I_waddr, I_wdata, I_wdqm}),
	.O_ready		(O_wready),

	.O_valid		(W_pre_wvalid),
	.O_data			({W_pre_waddr, W_pre_wdata, W_pre_wdqm}),
	.I_ready		(W_pre_wready)
);

timing_split #(
	.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH)
) timing_split_read(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_valid		(I_rvalid),
	.I_data			({I_raddr, I_rdqm}),
	.O_ready		(O_rready),

	.O_valid		(W_pre_rvalid),
	.O_data			({W_pre_raddr, W_pre_rdqm}),
	.I_ready		(W_pre_rready)
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

	.I_valid		(W_pre_wvalid),
	.I_data			({W_pre_waddr, W_pre_wdata, W_pre_wdqm}),
	.O_ready		(W_pre_wready),

	.O_valid		(W_wvalid),
	.O_data			({W_waddr, W_wdata, W_wdqm}),
	.I_ready		(W_wready)
);

buffer_delay #(
	.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH)
) buffer_delay_read(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_valid		(W_pre_rvalid),
	.I_data			({W_pre_raddr, W_pre_rdqm}),
	.O_ready		(W_pre_rready),

	.O_valid		(W_rvalid),
	.O_data			({W_raddr, W_rdqm}),
	.I_ready		(W_rready)
);

wire [BANKADDRWIDTH-1:0]	W_waddr_ba	= W_waddr[ADDRWIDTH-1 : ADDRWIDTH-BANKADDRWIDTH];
wire [BANKADDRWIDTH-1:0]	W_raddr_ba	= W_raddr[ADDRWIDTH-1 : ADDRWIDTH-BANKADDRWIDTH];
wire [ROWADDRWIDTH-1:0]		W_waddr_row	= W_waddr[ADDRWIDTH-BANKADDRWIDTH-1 : ADDRWIDTH-BANKADDRWIDTH-ROWADDRWIDTH];
wire [ROWADDRWIDTH-1:0]		W_raddr_row	= W_raddr[ADDRWIDTH-BANKADDRWIDTH-1 : ADDRWIDTH-BANKADDRWIDTH-ROWADDRWIDTH];
wire [ROWADDRWIDTH-1:0]		W_pre_waddr_row	= W_pre_waddr[ADDRWIDTH-BANKADDRWIDTH-1 : ADDRWIDTH-BANKADDRWIDTH-ROWADDRWIDTH];
wire [ROWADDRWIDTH-1:0]		W_pre_raddr_row	= W_pre_raddr[ADDRWIDTH-BANKADDRWIDTH-1 : ADDRWIDTH-BANKADDRWIDTH-ROWADDRWIDTH];

wire W_actfifo_wfull;
wire W_actfifo_rfull;
wire W_actfifo_wempty;
wire W_actfifo_rempty;

wire W_active_ready;
reg R_active_is_read_loop;
reg W_active_is_rd;
reg [BANKADDRWIDTH-1:0] W_active_bank_addr;
reg [ROWADDRWIDTH-1:0] W_active_row_addr;
wire W_active_wvalid	= W_wvalid && I_bank_active_prepared[W_waddr_ba] && (!W_actfifo_wfull);
wire W_active_rvalid	= W_rvalid && I_bank_active_prepared[W_raddr_ba] && (!W_actfifo_rfull);

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_active_is_read_loop <= 1'b0;
	else 
		R_active_is_read_loop <= !R_active_is_read_loop;
end

always @(*)begin
	case({W_active_wvalid, W_active_rvalid})
		2'b01:	W_active_is_rd <= 1'b1;
		2'b10:	W_active_is_rd <= 1'b0;
		default:W_active_is_rd <= R_active_is_read_loop;
	endcase

	case({W_active_wvalid, W_active_rvalid})
		2'b01:	W_active_bank_addr <= W_raddr_ba;
		2'b10:	W_active_bank_addr <= W_waddr_ba;
		default:W_active_bank_addr <= R_active_is_read_loop ? W_raddr_ba : W_waddr_ba;
	endcase

	case({W_active_wvalid, W_active_rvalid})
		2'b01:	W_active_row_addr <= W_raddr_row;
		2'b10:	W_active_row_addr <= W_waddr_row;
		default:W_active_row_addr <= R_active_is_read_loop ? W_raddr_row : W_waddr_row;
	endcase
end

timing_split #(
	.DATAWIDTH		(BANKADDRWIDTH+ROWADDRWIDTH)
) timing_split_active(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_valid		(W_active_rvalid || W_active_wvalid),
	.I_data			({W_active_bank_addr, W_active_row_addr}),
	.O_ready		(W_active_ready),

	.O_valid		(O_active_valid),
	.O_data			({O_active_bank_addr, O_active_row_addr}),
	.I_ready		(I_active_ready)
);

assign O_logic_active_valid		= W_active_ready;
assign O_logic_active_bank_addr	= W_active_bank_addr;
assign O_logic_active_row_addr	= W_active_row_addr;


reg R_wrow_inherit;
reg R_rrow_inherit;
reg R_wrow_match;
reg R_rrow_match;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_wrow_inherit <= 1'b0;
	else if(W_pre_wready)
		R_wrow_inherit <= (W_pre_waddr_row == W_waddr_row);
	else 
		R_wrow_inherit <= R_wrow_inherit;

	if(!I_rstn)
		R_rrow_inherit <= 1'b0;
	else if(W_pre_rready)
		R_rrow_inherit <= (W_pre_raddr_row == W_raddr_row);
	else 
		R_rrow_inherit <= R_rrow_inherit;

	if(!I_rstn)
		R_wrow_match <= 1'b0;
	else if(W_wvalid && (!W_wready))
		R_wrow_match <= (W_waddr_row == W_bank_active_row[W_waddr_ba]) && I_bank_is_active[W_waddr_ba];
	else 
		R_wrow_match <= (W_pre_waddr_row == W_bank_active_row[W_waddr_ba]) && I_bank_is_active[W_waddr_ba];

	if(!I_rstn)
		R_rrow_match <= 1'b0;
	else if(W_rvalid && (!W_rready))
		R_rrow_match <= (W_raddr_row == W_bank_active_row[W_raddr_ba]) && I_bank_is_active[W_raddr_ba];
	else 
		R_rrow_match <= (W_pre_raddr_row == W_bank_active_row[W_raddr_ba]) && I_bank_is_active[W_raddr_ba];
end

assign W_wready = W_wvalid && (!W_actfifo_wfull) && (!I_bank_precharge_prepared[W_waddr_ba]) && 
						(R_wrow_inherit || R_wrow_match || (W_active_ready && (!W_active_is_rd)));
assign W_rready = W_rvalid && (!W_actfifo_rfull) && (!I_bank_precharge_prepared[W_raddr_ba]) && 
						(R_rrow_inherit || R_rrow_match || (W_active_ready && ( W_active_is_rd)));
assign O_wr_inc		= W_wready;
assign O_wr_inc_ba	= W_waddr_ba;
assign O_rd_inc		= W_rready;
assign O_rd_inc_ba	= W_raddr_ba;

simple_sync_fifo_sdram_adapt #(
	.DATAWIDTH		(ADDRWIDTH+DATAWIDTH+PHYDQMWIDTH),
	.DATADEPTH		(WPREACTIVEDEPTH),	//must be 2**n
	.SHOWAHEAD		("ENABLE"),	//"ENABLE" "DISABLE"
	.TIM_PRIOR		("ADDRESS")	//"DATA" "ADDRESS"
) simple_sync_fifo_pre_active_write(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_we			(W_wready),
	.I_wdata		({W_waddr, W_wdata, W_wdqm}),
	.O_full			(W_actfifo_wfull),

	.I_re			(I_wready),
	.O_rdata		({O_waddr, O_wdata, O_wdqm}),
	.O_empty		(W_actfifo_wempty)
);

simple_sync_fifo_sdram_adapt #(
	.DATAWIDTH		(ADDRWIDTH+PHYDQMWIDTH),
	.DATADEPTH		(RPREACTIVEDEPTH),	//must be 2**n
	.SHOWAHEAD		("ENABLE"),	//"ENABLE" "DISABLE"
	.TIM_PRIOR		("ADDRESS")	//"DATA" "ADDRESS"
) simple_sync_fifo_pre_active_read(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_we			(W_rready),
	.I_wdata		({W_raddr, W_rdqm}),
	.O_full			(W_actfifo_rfull),

	.I_re			(I_rready),
	.O_rdata		({O_raddr, O_rdqm}),
	.O_empty		(W_actfifo_rempty)
);

assign O_wvalid = (!W_actfifo_wempty);
assign O_rvalid = (!W_actfifo_rempty);


endmodule
