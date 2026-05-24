/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/03/31-17:17:29
*
*  Description:
*   single input channel, multiple output channel, input valid to output valid has no delay
*
*  Modify:
*  -
*
******************************************************************************/

module com_simo_no_delay #( parameter
    CH_NUM = 1
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,
output wire [CH_NUM-1:0]        o_tx_vld            ,
input  wire [CH_NUM-1:0]        i_tx_rdy            //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  [CH_NUM-1:0] r_outed_flag;
wire [CH_NUM-1:0] out_all_hs;
//statement------------------------------------------------------------------
//output assign---
assign o_tx_vld = {CH_NUM{i_rx_vld}} & ~r_outed_flag;
assign o_rx_rdy = &out_all_hs;

//body---
assign out_all_hs = r_outed_flag | ({CH_NUM{i_rx_vld}}&i_tx_rdy);
wire rx_hs = i_rx_vld && o_rx_rdy;
wire [CH_NUM-1:0] a1_tx_hs = o_tx_vld & i_tx_rdy;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_outed_flag <= '0;
    else if( clear || rx_hs  )
        r_outed_flag <= '0;
    else begin
        for( int i=0; i<CH_NUM; i++ ) begin
            if( a1_tx_hs[i] )
                r_outed_flag[i] <= 1'b1;
        end
    end
end

endmodule //end of com_simo_no_delay
