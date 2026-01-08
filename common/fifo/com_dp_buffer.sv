/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2019/11/07-10:01:49
*
*  Description:
*   datapath buffer
*
*  Modify:
*  -
*
******************************************************************************/

//`include "com_sync_fifo_reg.v"

`ifndef com_dp_buffer_v
`define com_dp_buffer_v
module com_dp_buffer #( parameter
    DW    = 8,
    DEPTH = 4
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [DW-1:0]            i_rx_data           ,
input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,
output wire [DW-1:0]            o_tx_data           ,
output wire                     o_tx_vld            ,
input  wire                     i_tx_rdy            //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

wire          wr_en   = i_rx_vld && o_rx_rdy;
wire [DW-1:0] wr_data = i_rx_data;
wire          rd_en   = o_tx_vld && i_tx_rdy;
wire [DW-1:0] rd_data ;
wire          wr_full ;
wire          rd_empty;

com_sync_fifo_reg #(
    .DW         ( DW          ), //8
    .DEPTH      ( DEPTH       )  //4
)r_com_sync_fifo_reg
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wr_en                ), //i
    .wr_data              ( wr_data              ), //i
    .wr_full              ( wr_full              ), //o
    .rd_en                ( rd_en                ), //i
    .rd_data              ( rd_data              ), //o
    .rd_empty             ( rd_empty             ), //o
    .water_level          (                      )  //spyglass disable PartConnPort-ML,W287b //o,
);
assign o_rx_rdy = !wr_full;
assign o_tx_vld = !rd_empty;
assign o_tx_data = rd_data;

endmodule //end of com_dp_buffer
`endif //end of com_dp_buffer_v

