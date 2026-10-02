//------------ CHIP PARAMETERS -----------//
//EM638325-5
//unit: ns
`define tRC		55	/*row active to row active_same bank*/
`define tRRD	10	/*row active to row active_different bank*/
`define tRCD	18	/*row active to column select_same bank*/
`define tRP		15	/*precharge to refresh/row active_same bank*/
`define tRAS	35	/*row active to precharge_same bank, max(100us)*/
`define tRFC    55    /*refresh cycle time*/
`define tWR_clk		2	/*last write to precharge_same bank*/
`define tCCD_clk	1	/*column change_same bank*/
`define tMRD_clk	2	/*mode register set cycle time*/


// //Timing Parameters for -7
// //unit: ns
// `define tRC		70	/*row active to row active_same bank*/
// `define tRRD	14	/*row active to row active_different bank*/
// `define tRCD	21	/*row active to column select_same bank*/
// `define tRP		21	/*precharge to row active_same bank*/
// `define tRAS	49	/*row active to precharge_same bank, max(100us)*/
// `define tRFC    `tRC    /*refresh cycle time*/
// `define tWR_clk		2	/*last write to precharge_same bank*/
// `define tCCD_clk	1	/*column change_same bank*/
// `define tMRD_clk	2	/*mode register set cycle time*/
// //end Timing Parameters for -7


`define tCK3	5		/*clk-T*/
`define tAC3	4.5	/**/
`define tOH		2		/**/
`define tCH		2		/**/
`define tCL		2		/**/
`define tIS		1.5	/**/
`define tIH		1		/**/
`define tLZ		1		/**/
`define tHZ3	4.5	/**/

`define tREFRESH    64ms
`define tcREFRESH   4096cycle

//------------ END CHIP PARAMETERS -----------//

	
