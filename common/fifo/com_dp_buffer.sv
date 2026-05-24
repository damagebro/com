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
localparam CW = $clog2(DEPTH+1);
//signal declare-------------------------------------------------------------
//instance signal--
wire          u_fifo_i_wr_en;
wire [DW-1:0] u_fifo_i_wr_data;
wire          u_fifo_o_wr_full;
wire          u_fifo_i_rd_en;
wire [DW-1:0] u_fifo_o_rd_data;
wire          u_fifo_o_rd_empty;
//statement------------------------------------------------------------------
//output assign---
assign o_rx_rdy = !u_fifo_o_wr_full;
assign o_tx_vld = !u_fifo_o_rd_empty;
assign o_tx_data = u_fifo_o_rd_data;

//instance----
assign u_fifo_i_wr_en = i_rx_vld && o_rx_rdy;
assign u_fifo_i_wr_data = i_rx_data;
assign u_fifo_i_rd_en = o_tx_vld && i_tx_rdy;
com_sync_fifo_reg #(
    .DW                   ( DW                  ), //8
    .DEPTH                ( DEPTH               )  //4
)u_com_sync_fifo_reg_fifo
(
    .clk                  ( clk                 ), //i
    .rst_n                ( rst_n               ), //i
    .clear                ( clear               ), //i

    .i_wr_en              ( u_fifo_i_wr_en      ), //i
    .i_wr_data            ( u_fifo_i_wr_data    ), //i
    .o_wr_full            ( u_fifo_o_wr_full    ), //o
    .i_rd_en              ( u_fifo_i_rd_en      ), //i
    .o_rd_data            ( u_fifo_o_rd_data    ), //o
    .o_rd_empty           ( u_fifo_o_rd_empty   ), //o
    .o_water_level        (                     )  //o
);

endmodule //end of com_dp_buffer
