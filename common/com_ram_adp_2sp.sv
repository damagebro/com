/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/30
*
*  Description:
*  - Adapt one logical RAM interface to two interleaved single-port SRAM banks.
*  - Allow concurrent read and write when their bank addresses are different.
*  - Resolve same-bank read/write conflicts with configurable priority.
*
******************************************************************************/

module com_ram_adp_2sp #( parameter
    AW           = 8,
    DW           = 8,
    STRB_W       = 1, //range=[1::]
    RAM_RD_DELAY = 1, //range=[1:16:], fixed SRAM read latency
    WR_PRIORITY  = 1  //1: write priority, 0: read priority
)
(
input  wire                         clk                 ,
input  wire                         rst_n               ,
input  wire                         clear               ,

input  wire [AW-1:0]                i_rx_wr_addr        ,
input  wire [DW-1:0]                i_rx_wr_data        ,
input  wire [STRB_W-1:0]            i_rx_wr_vld         ,
output wire                         o_rx_wr_rdy         ,
input  wire [AW-1:0]                i_rx_rd_addr        ,
input  wire                         i_rx_rd_vld         ,
output wire                         o_rx_rd_rdy         ,
output wire                         o_rx_rd_ack         ,
output wire [DW-1:0]                o_rx_rd_data        ,

output wire [1:0]                   o_ram_ce_n          ,
output wire [1:0][STRB_W-1:0]       o_ram_we_n          ,
output wire [1:0][AW-2:0]           o_ram_addr          ,
output wire [1:0][DW-1:0]           o_ram_wr_data       ,
input  wire [1:0][DW-1:0]           i_ram_rd_data       //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  [RAM_RD_DELAY-1:0] r_ram_rd_vld_pipe;
reg  [RAM_RD_DELAY-1:0] r_ram_rd_bank_pipe;

wire                    tie_wr_priority;
wire                    wr_req;
wire                    wr_bank;
wire                    rd_bank;
wire                    same_bank;
wire                    wr_block;
wire                    rd_block;
wire                    wr_hs;
wire                    rd_hs;
wire [1:0]              ram_wr_en;
wire [1:0]              ram_rd_en;
//statement------------------------------------------------------------------
//output assign---
assign o_rx_wr_rdy = !wr_block;
assign o_rx_rd_rdy = !rd_block;
assign o_rx_rd_ack = r_ram_rd_vld_pipe[RAM_RD_DELAY-1];
assign o_rx_rd_data = i_ram_rd_data[r_ram_rd_bank_pipe[RAM_RD_DELAY-1]];

assign o_ram_ce_n = ~(ram_wr_en | ram_rd_en);
for( genvar gi=0; gi<2; gi++ ) begin:gen_ram_bank_output
    assign o_ram_we_n[gi] = ram_wr_en[gi] ? ~i_rx_wr_vld : '1;
    assign o_ram_addr[gi] = ram_wr_en[gi] ? i_rx_wr_addr[AW-1:1] :
                                               i_rx_rd_addr[AW-1:1];
    assign o_ram_wr_data[gi] = i_rx_wr_data;
end

//body---
assign tie_wr_priority = WR_PRIORITY>0;
assign wr_req = |i_rx_wr_vld;
assign wr_bank = i_rx_wr_addr[0];
assign rd_bank = i_rx_rd_addr[0];
assign same_bank = wr_bank==rd_bank;

assign wr_block = !tie_wr_priority && i_rx_rd_vld && same_bank;
assign rd_block = tie_wr_priority && wr_req && same_bank;
assign wr_hs = wr_req && o_rx_wr_rdy;
assign rd_hs = i_rx_rd_vld && o_rx_rd_rdy;

assign ram_wr_en[0] = wr_hs && !wr_bank;
assign ram_wr_en[1] = wr_hs &&  wr_bank;
assign ram_rd_en[0] = rd_hs && !rd_bank;
assign ram_rd_en[1] = rd_hs &&  rd_bank;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ram_rd_vld_pipe <= '0;
    else if( clear )
        r_ram_rd_vld_pipe <= '0;
    else begin
        r_ram_rd_vld_pipe[0] <= rd_hs;
        for( int i=1; i<RAM_RD_DELAY; i++ )
            r_ram_rd_vld_pipe[i] <= r_ram_rd_vld_pipe[i-1];
    end
end

always @(posedge clk) begin
    r_ram_rd_bank_pipe[0] <= rd_bank;
    for( int i=1; i<RAM_RD_DELAY; i++ )
        r_ram_rd_bank_pipe[i] <= r_ram_rd_bank_pipe[i-1];
end

//instance----
//assert---------------------------------------------------------------------
`COM_PARAM_ASSERT( STRB_W>=1 && DW%STRB_W==0, "DW must be divisible by STRB_W" )
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "ram read delay range is [1:16]" )
`COM_PARAM_ASSERT( WR_PRIORITY==0 || WR_PRIORITY==1, "WR_PRIORITY must be 0 or 1" )

endmodule //end of com_ram_adp_2sp
