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

input  wire                     ivld                ,
output wire                     irdy                ,
input  wire [DW-1:0]            idata               ,
output wire                     ovld                ,
input  wire                     ordy                ,
output wire [DW-1:0]            odata               //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

wire          wr_en   = ivld && irdy;
wire [DW-1:0] wr_data = idata;
wire          rd_en   = ovld && ordy;
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
    .water_level          (                      )  //spyglass disable PartConnPort-ML //o,
);
assign irdy = !wr_full;
assign ovld = !rd_empty;
assign odata = rd_data;

endmodule //end of com_dp_buffer
`endif //end of com_dp_buffer_v

