/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/06-13:57:57
*
*  Description:
*   common data path ram buffer;
*   -assume the data have already writed to dp_sram,
*   -this module function is: send rd_addr to dp_sram, and deal the rd_data with sync_fifo_reg,
     make ovld and odata output synchronously
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_dp_ram_v
`define com_dp_ram_v
module com_dp_ram #( parameter
    AW   = 8,
    DW   = 8,
    DEPTH= 2
)(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     ivld                ,
output wire                     irdy                ,
input  wire [AW-1:0]            iaddr               ,
output wire                     ovld                ,
input  wire                     ordy                ,
output wire [DW-1:0]            odata               ,

output wire                     ram_rd_vld          ,
input  wire                     ram_rd_rdy          ,
output wire [AW-1:0]            ram_rd_addr         ,
input  wire                     ram_rd_ack          ,
input  wire [DW-1:0]            ram_rd_data         //,
);
//localparam-----------------------------------------------------------------
localparam CW = $clog2(DEPTH+1);
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

wire          wr_en    = ram_rd_ack;
wire [DW-1:0] wr_data  = ram_rd_data;
wire          wr_full  ;
wire          rd_en    ;
wire [DW-1:0] rd_data  ;
wire          rd_empty ;
wire [CW-1:0] wl       ;
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
    .water_level          ( wl                   )  //spyglass disable PartConnPort-ML //o,
);

reg  [CW-1:0] rc_otf_cnt;
wire [CW-0:0] otf_cnt_nxt = rc_otf_cnt + (ram_rd_vld&&ram_rd_rdy) - ram_rd_ack;  //spyglass disable W164b
wire upen = (ram_rd_vld&&ram_rd_rdy) || ram_rd_ack;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_otf_cnt <= 'b0;
    else if( clear )
        rc_otf_cnt <= 'b0;
    else if( upen )
        rc_otf_cnt <= otf_cnt_nxt;
end

wire [CW-0:0] wl_t = wl+rd_en;  //spyglass disable W164b
wire b_rd_avl_flag = {1'b0,rc_otf_cnt}<wl_t;

//out--
assign ram_rd_vld = ivld && b_rd_avl_flag;
assign ram_rd_addr= iaddr;
assign irdy = ram_rd_rdy && b_rd_avl_flag;

assign ovld = !rd_empty;
assign odata= rd_data;
assign rd_en= ovld&&ordy;

endmodule //end of com_dp_ram
`endif //end of com_dp_ram_v

