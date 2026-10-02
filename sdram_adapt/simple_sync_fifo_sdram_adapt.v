module simple_sync_fifo_sdram_adapt #(
	parameter	DATAWIDTH	= 8,
	parameter	DATADEPTH	= 256,		//must be 2**n
	parameter	SHOWAHEAD	= "ENABLE",	//"ENABLE" "DISABLE"
	parameter	TIM_PRIOR	= "DATA"	//"DATA" "ADDRESS"
) (
	input					I_clk,
	input					I_rstn,

	input					I_we,
	input	[DATAWIDTH-1:0]	I_wdata,
	output					O_full,

	input					I_re,
	output	[DATAWIDTH-1:0]	O_rdata,
	output					O_empty
);

simple_sync_fifo_lut_anlogic #(
	.DATAWIDTH		(DATAWIDTH),
	.DATADEPTH		(DATADEPTH),	//must be 2**n
	.SHOWAHEAD		(SHOWAHEAD),	//"ENABLE" "DISABLE"
	.TIM_PRIOR		(TIM_PRIOR)		//"DATA" "ADDRESS"
) simple_sync_fifo_u(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_we			(I_we),
	.I_wdata		(I_wdata),
	.O_full			(O_full),

	.I_re			(I_re),
	.O_rdata		(O_rdata),
	.O_empty		(O_empty)
);

endmodule
