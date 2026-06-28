/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/28
*
*  Description:
*  - Adapt independent RAM write/read handshakes to one single-port SRAM.
*  - Resolve same-cycle write/read conflicts with configurable priority.
*
******************************************************************************/

module com_ram_adp_sp #( parameter
    AW           = 8,
    DW           = 8,
    STRB_W       = 1,
    RAM_RD_DELAY = 1, //range=[1:16:], fixed delay from rx rd_hs to rd_ack
    WR_PRIORITY  = 1  //1: write priority, 0: read priority
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [AW-1:0]            i_rx_wr_addr        ,
input  wire [DW-1:0]            i_rx_wr_data        ,
input  wire [STRB_W-1:0]        i_rx_wr_vld         ,
output wire                     o_rx_wr_rdy         ,

input  wire [AW-1:0]            i_rx_rd_addr        ,
input  wire                     i_rx_rd_vld         ,
output wire                     o_rx_rd_rdy         ,
output wire                     o_rx_rd_ack         ,
output wire [DW-1:0]            o_rx_rd_data        ,

output wire                     o_sram_ce_n         ,
output wire [STRB_W-1:0]        o_sram_we_n         ,
output wire [AW-1:0]            o_sram_addr         ,
output wire [DW-1:0]            o_sram_wr_data      ,
input  wire [DW-1:0]            i_sram_rd_data      //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  [RAM_RD_DELAY-1:0] r_rd_vld_pipe;

wire                    tie_wr_priority;
wire                    wr_req;
wire                    wr_sel;
wire                    rd_sel;
wire                    rd_hs;
//statement------------------------------------------------------------------
//output assign---
assign o_rx_wr_rdy = tie_wr_priority ? 1'b1 : !i_rx_rd_vld;

assign o_rx_rd_rdy = tie_wr_priority ? !wr_req : 1'b1;
assign o_rx_rd_ack = r_rd_vld_pipe[RAM_RD_DELAY-1];
assign o_rx_rd_data = i_sram_rd_data;

assign o_sram_ce_n = !(wr_sel || rd_sel);
// Strobe bit i enables data bits [i*(DW/STRB_W) +: (DW/STRB_W)].
assign o_sram_we_n = wr_sel ? ~i_rx_wr_vld : '1;
assign o_sram_addr = wr_sel ? i_rx_wr_addr : i_rx_rd_addr;
assign o_sram_wr_data = i_rx_wr_data;

//body---
assign tie_wr_priority = WR_PRIORITY>0;
assign wr_req = |i_rx_wr_vld;
assign wr_sel = wr_req && o_rx_wr_rdy;
assign rd_sel = i_rx_rd_vld && o_rx_rd_rdy;
assign rd_hs = rd_sel;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_vld_pipe <= '0;
    else if( clear )
        r_rd_vld_pipe <= '0;
    else begin
        r_rd_vld_pipe[0] <= rd_hs;
        for( int i=1; i<RAM_RD_DELAY; i++ )
            r_rd_vld_pipe[i] <= r_rd_vld_pipe[i-1];
    end
end

//instance----
//assert---------------------------------------------------------------------
`COM_PARAM_ASSERT( STRB_W>=1 && DW%STRB_W==0, "DW must be divisible by STRB_W" );
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "ram read delay range is [1:16]" );
`COM_PARAM_ASSERT( WR_PRIORITY==0 || WR_PRIORITY==1, "WR_PRIORITY must be 0 or 1" );

endmodule //end of com_ram_adp_sp
