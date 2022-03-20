/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/13-09:42:42
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_rch_clr_v
`define com_emi_rch_clr_v
module com_emi_rch_clr #( parameter
    MAX_OSD = 16        //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     ps_emi_terminate    ,
//cfg&status---
output wire                     clr_ongoing         ,
//dp---
input  wire                     rx_arvalid          ,
output wire                     rx_arready          ,
input  wire [7:0]               rx_arlen            ,

output wire                     rx_rvalid           ,
input  wire                     rx_rready           ,

output wire                     tx_arvalid          ,
input  wire                     tx_arready          ,

input  wire                     tx_rvalid           ,
output wire                     tx_rready           ,
input  wire                     tx_rlast            //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  rc_clr_flag;
reg  [15:0] rc_otf_req_cnt;
reg  [15:0] rc_otf_dat_cnt;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------
wire clr_done = rc_clr_flag && rc_otf_dat_cnt==16'b0 && rc_otf_req_cnt==16'b0;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_clr_flag <= 1'b0;
    end
    else if( clr_done )begin
        rc_clr_flag <= 1'b0;
    end
    else if( ps_emi_terminate )begin
        rc_clr_flag <= 1'b1;
    end
end

wire [7:0] ra_px = (tx_arvalid&&tx_arready) ? (rx_arlen+1'b1) : 8'b0;
wire [7:0] rd_m1 = (tx_rvalid&&tx_rready) ? 8'd1 : 8'b0;
wire [15:0] otf_cnt_dat_nxt = rc_otf_dat_cnt + ra_px - rd_m1;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_otf_dat_cnt <= 'b0;
    end
    else if( (tx_arvalid&&tx_arready) || (tx_rvalid&&tx_rready) )begin
        rc_otf_dat_cnt <= otf_cnt_dat_nxt;
    end
end

wire [7:0] ra_p1 = (tx_arvalid&&tx_arready) ? 8'd1 : 8'b0;
wire [7:0] rd_req_m1 = (tx_rvalid&&tx_rready&&tx_rlast) ? 8'd1 : 8'b0;
wire [15:0] otf_cnt_req_nxt = rc_otf_req_cnt + ra_p1 - rd_req_m1;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_otf_req_cnt <= 'b0;
    end
    else if( (tx_arvalid&&tx_arready) || (tx_rvalid&&tx_rready&&tx_rlast) )begin
        rc_otf_req_cnt <= otf_cnt_req_nxt;
    end
end

//out---
assign clr_ongoing = rc_clr_flag;
assign tx_arvalid  = rc_clr_flag ? 1'b0 : rx_arvalid;
assign rx_arready  = rc_clr_flag ? 1'b0 : tx_arready;

assign tx_rready   = rc_clr_flag ? 1'b1 : rx_rready;
assign rx_rvalid   = rc_clr_flag ? 1'b0 : tx_rvalid;

endmodule //end of com_emi_rch_clr
`endif //end of com_emi_rch_clr_v

