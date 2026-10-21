module top_tb ();



reg R_mclk;
reg R_mclk_shift;
reg R_mclk_rstn;

// always begin
// 	#4 R_mclk = !R_mclk;
// end

parameter CLK_PERIOD = 8;

initial begin
	R_mclk = 0;
    #20;
    forever #(CLK_PERIOD/2) R_mclk = ~R_mclk;
end

initial begin
	R_mclk_shift = 0;
    #19;
    forever #(CLK_PERIOD/2) R_mclk_shift = ~R_mclk_shift;
end

initial begin
	R_mclk_rstn = 1'b0;
	#55;
	R_mclk_rstn = 1'b1;
end


wire W_mclk = R_mclk;


wire			W_wvalid;
wire	[20:0]	W_waddr;
wire	[31:0]	W_wdata;
wire	[3:0]	W_wdqm;
wire			W_wready;

wire			W_rvalid;
wire	[20:0]	W_raddr;
wire	[3:0]	W_rdqm;
wire			W_rready;

wire			W_out_valid;
wire	[20:0]	W_out_addr;
wire	[31:0]	W_out_data;
wire	[3:0]	W_out_dqm;


reg R_rwmix_wr;
reg R_rwmix_rd;
reg [21:0] R_test_waddr;
reg [20:0] R_test_raddr;

// reg [21:0] R_test_addr;

always @(posedge W_mclk or negedge R_mclk_rstn) begin
	if(!R_mclk_rstn)
		R_rwmix_wr <= 1'b1;
	else if(W_wready || W_rready)
		R_rwmix_wr <= !R_rwmix_wr;
	else 
		R_rwmix_wr <= R_rwmix_wr;

	if(!R_mclk_rstn)
		R_rwmix_rd <= 1'b0;
	else if(W_wready || W_rready)
		R_rwmix_rd <= !R_rwmix_rd;
	else 
		R_rwmix_rd <= R_rwmix_rd;
	
	// if(!R_mclk_rstn)
	// 	R_wvalid <= 1'b0;
	// else 
	// 	R_wvalid <= ;
	
	// if(!R_mclk_rstn)
	// 	R_rvalid <= 1'b0;
	// else 
	// 	R_rvalid <= ;
	
	if(!R_mclk_rstn)
		R_test_waddr <= 22'b0;// + 21'd1024;
	else if(W_wready)
		R_test_waddr <= R_test_waddr + 1'b1;
	else 
		R_test_waddr <= R_test_waddr;

	if(!R_mclk_rstn)
		R_test_raddr <= 21'b0;
	else if(W_rready)
		R_test_raddr <= R_test_raddr + 1'b1;
	else 
		R_test_raddr <= R_test_raddr;
end

// //continuous read
// assign W_wvalid	= (R_test_waddr != {21{1'b1}});
// assign W_waddr	= R_test_waddr;
// assign W_wdata	= {11'b0 ,R_test_waddr};
// assign W_wdqm	= 4'b0;

// assign W_rvalid	= (R_test_waddr == {21{1'b1}});
// assign W_raddr	= R_test_raddr;
// assign W_rdqm	= 4'b0;
// //end continuous read

//bank interleave read
assign W_wvalid	= (!R_test_waddr[21]);
assign W_waddr	= R_test_waddr[20:0];
assign W_wdata	= {11'b0 ,R_test_waddr[20:0]};
assign W_wdqm	= 4'b0;

assign W_rvalid	= R_test_waddr[21];
assign W_raddr	= {R_test_raddr[2], R_test_raddr[20:3], R_test_raddr[1:0]};
assign W_rdqm	= 4'b0;
//end bank interleave read

// //read write mix
// assign W_wvalid	= R_rwmix_wr;
// assign W_waddr	= R_test_waddr;
// assign W_wdata	= {11'b0 ,R_test_waddr};
// assign W_wdqm	= 4'b0;

// assign W_rvalid	= R_rwmix_rd;
// assign W_raddr	= R_test_raddr;
// // assign W_raddr	= {R_test_raddr[1], R_test_raddr[20:2], R_test_raddr[0]};
// assign W_rdqm	= 4'b0;
// //end read write mix



reg R_is_error;
reg R_have_error;

always @(posedge W_mclk or negedge R_mclk_rstn) begin
	if(!R_mclk_rstn)
		R_is_error <= 1'b0;
	else 
		R_is_error <= W_out_valid && (!(W_out_addr === W_out_data));

	if(!R_mclk_rstn)
		R_have_error <= 1'b0;
	else if(R_have_error)
		R_have_error <= 1'b1;
	else 
		R_have_error <= R_is_error;
end

integer write_valid;
integer write_ready;
integer read_valid;
integer read_ready;
integer total_valid;
integer total_ready;
real write_efficiency;
real read_efficiency;
real total_efficiency;
always @(posedge W_mclk or negedge R_mclk_rstn) begin
	if(!R_mclk_rstn)
		write_valid <= 0;
	else 
		write_valid <= write_valid + W_wvalid;

	if(!R_mclk_rstn)
		write_ready <= 0;
	else 
		write_ready <= write_ready + W_wready;

	if(!R_mclk_rstn)
		read_valid <= 0;
	else 
		read_valid <= read_valid + W_rvalid;

	if(!R_mclk_rstn)
		read_ready <= 0;
	else 
		read_ready <= read_ready + W_rready;

	if(!R_mclk_rstn)
		total_valid <= 0;
	else 
		total_valid <= total_valid + W_wvalid + W_rvalid;

	if(!R_mclk_rstn)
		total_ready <= 0;
	else 
		total_ready <= total_ready + W_wready + W_rready;

	if(!R_mclk_rstn)
		write_efficiency <= 1;
	else 
		write_efficiency <= (write_valid == 0) ? 1 : ($itor(write_ready) / write_valid);

	if(!R_mclk_rstn)
		read_efficiency <= 1;
	else 
		read_efficiency <= (read_valid == 0) ? 1 : ($itor(read_ready) / read_valid);

	if(!R_mclk_rstn)
		total_efficiency <= 1;
	else 
		total_efficiency <= (total_valid == 0) ? 1 : ($itor(total_ready) / total_valid);
end



wire			W_sdram_clk;
wire			W_sdram_cke;
wire			W_sdram_rasn;
wire			W_sdram_casn;
wire			W_sdram_wen;
wire			W_sdram_csn;
wire [1:0]		W_sdram_bank;
wire [10:0]		W_sdram_addr;
wire [31:0]		W_sdram_data_i;
wire			W_sdram_data_en;
wire [31:0]		W_sdram_data_o;
wire [3:0]		W_sdram_dqm;

wire [31:0]		W_dq = W_sdram_data_en ? W_sdram_data_o : 32'bz;
assign			W_sdram_data_i = W_dq;


wire W_sdram_clk_shift;
sdram_oddr sdram_oddr_u(
	.I_clk		(R_mclk),
	.I_rstn		(R_mclk_rstn),
	.I_d0		(1'b0),
	.I_d1		(1'b1),
	.O_q		(W_sdram_clk_shift)
);

IS42s32200 sdram(
	.Clk	(R_mclk_shift),
	.Ras_n	(W_sdram_rasn),
	.Cas_n	(W_sdram_casn),
	.We_n	(W_sdram_wen),
	.Addr	(W_sdram_addr),
	.Ba		(W_sdram_bank),
	.Dq		(W_dq),
	.Cs_n	(W_sdram_csn),
	.Dqm	(W_sdram_dqm),
	.Cke	(W_sdram_cke)
);

sdram_controller #(
	.CLK_FREQ				(125_000_000),
	.ADDRRANK				("BRC"),	//"BRC" "RBC"	//{BANK, ROW, COLUMN} or {ROW, BANK, COLUMN}
	.ADDRWIDTH				(21),
	.DATAWIDTH				(32),
	.BANKNUM				(4),
	.ROWNUM					(2048),
	.COLNUM					(256),
	.PHYADDRWIDTH			(11),
	.PHYBANKWIDTH			(2),
	.PHYDQMWIDTH			(4),
	.CASLATENCY				(3),
	.POWERUP_DELAYMS		(1),
	.BURSTLENGTH			(4),
	.BURSTTYPE				("SEQUENTIAL"),		//"SEQUENTIAL" "INTERLEAVE"

	.INWBUFFERDEPTH			(0),		//must be 2**n or 0
	.WDATABATCHLENGTH		(0),		//must < INWBUFFERDEPTH, or be 0
	.WMAXBATCHDELAY			(0),		//if it == 0, means infinity
	.INRBUFFERDEPTH			(0),		//must be 2**n or 0
	.RDATABATCHLENGTH		(0),		//must < INRBUFFERDEPTH, or be 0
	.RMAXBATCHDELAY			(0),		//if it == 0, means infinity

	.WPREACTIVEDEPTH		(8),		//must be 2**n and should >= 8
	.RPREACTIVEDEPTH		(8),		//must be 2**n and should >= 8
	.RWBUFFERDEPTH			(4),		//must be 2**n and >= 4
	.AUTO_REFRESH			("ENABLE"),
	.REFRESH_TIME_MS		(64),
	.REFRESH_LINE			(4096),
	.REFRESH_SLICE			(16)		//suggest >= 4, must >= 2, must <= REFRESH_TIME_MS
) sdram_controller_u(
	.I_clk					(W_mclk),
	.I_dq_retclk			(W_mclk),
	.I_rstn					(R_mclk_rstn),// && W_powerup_rstn),

	.I_wvalid				(W_wvalid),
	.I_waddr				(W_waddr),
	.I_wdata				(W_wdata),
	.I_wdqm					(W_wdqm),
	.O_wready				(W_wready),

	.I_rvalid				(W_rvalid),
	.I_raddr				(W_raddr),
	.I_rdqm					(W_rdqm),
	.O_rready				(W_rready),

	.O_out_valid			(W_out_valid),
	.O_out_addr				(W_out_addr),
	.O_out_data				(W_out_data),
	.O_out_dqm				(W_out_dqm),

	.O_sdram_clk			(W_sdram_clk),
	.O_sdram_cke			(W_sdram_cke),
	.O_sdram_csn			(W_sdram_csn),
	.O_sdram_rasn			(W_sdram_rasn),
	.O_sdram_casn			(W_sdram_casn),
	.O_sdram_wen			(W_sdram_wen),
	.O_sdram_bank			(W_sdram_bank),
	.O_sdram_addr			(W_sdram_addr),
	.I_sdram_data			(W_sdram_data_i),
	.O_sdram_data_en		(W_sdram_data_en),
	.O_sdram_data			(W_sdram_data_o),
	.O_sdram_dqm			(W_sdram_dqm)
);


endmodule
