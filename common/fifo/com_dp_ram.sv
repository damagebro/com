/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/06-13:57:57
*
*  Description:
*   common data path ram buffer;
*   -assume the data have already writed to sram,
*   -this module function is: send rd_addr to sram, and deal the rd_data with sync_fifo_reg,
     make o_tx_vld and o_tx_data output synchronously
*
*  Modify:
*  -
*
******************************************************************************/

module com_dp_ram #( parameter
    AW   = 8,
    DW   = 8,
    DEPTH= 2,
    RX_RDY_REG_OUT = 0//,  if RX_RDY_REG_OUT=1, o_rx_rdy is reg_out, and DEPTH need more 1;
)(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [AW-1:0]            i_rx_addr           ,
input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,  //if RX_RDY_REG_OUT=0, timing effect by i_tx_rdy;
output wire [DW-1:0]            o_tx_data           ,
output wire                     o_tx_vld            ,
input  wire                     i_tx_rdy            ,

output wire                     o_ram_rd_vld        ,
input  wire                     i_ram_rd_rdy        ,
output wire [AW-1:0]            o_ram_rd_addr       ,
input  wire                     i_ram_rd_ack        ,
input  wire [DW-1:0]            i_ram_rd_data       //,
);
//localparam-----------------------------------------------------------------
localparam CW = $clog2(DEPTH+1);
//signal declare-------------------------------------------------------------
reg  [CW-1:0] r_otf_cnt;
wire tie_rx_rdy_reg_out;
wire b_rd_avl_flag;

//instance signal--
wire          u_fifo_i_wr_en;
wire [DW-1:0] u_fifo_i_wr_data;
wire          u_fifo_o_wr_full;
wire          u_fifo_i_rd_en;
wire [DW-1:0] u_fifo_o_rd_data;
wire          u_fifo_o_rd_empty;
wire [CW-1:0] u_fifo_o_water_level;
//statement------------------------------------------------------------------
//output assign---
assign o_ram_rd_vld = i_rx_vld && b_rd_avl_flag;
assign o_ram_rd_addr = i_rx_addr;
assign o_rx_rdy = i_ram_rd_rdy && b_rd_avl_flag;

assign o_tx_vld = !u_fifo_o_rd_empty;
assign o_tx_data = u_fifo_o_rd_data;

//body---
assign tie_rx_rdy_reg_out = RX_RDY_REG_OUT>0;

wire ram_rd_hs = o_ram_rd_vld && i_ram_rd_rdy;
wire [CW-1:0] otf_cnt_nxt = r_otf_cnt + ram_rd_hs - i_ram_rd_ack;
wire upen = ram_rd_hs || i_ram_rd_ack;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_otf_cnt <= '0;
    else if( clear )
        r_otf_cnt <= '0;
    else if( upen )
        r_otf_cnt <= otf_cnt_nxt;
end

wire [CW-1:0] wl_t = u_fifo_o_water_level + u_fifo_i_rd_en;
assign b_rd_avl_flag = tie_rx_rdy_reg_out ? r_otf_cnt<u_fifo_o_water_level : r_otf_cnt<wl_t;

//instance----
assign u_fifo_i_wr_en = i_ram_rd_ack;
assign u_fifo_i_wr_data = i_ram_rd_data;
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
    .o_water_level        ( u_fifo_o_water_level)  //o
);

endmodule //end of com_dp_ram
