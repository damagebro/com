/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/07-09:17:18
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include "com_dp_ram.sv"
//`include "com_img_lb_rd.sv"
`ifndef com_img_lb_cut_rd_v
`define com_img_lb_cut_rd_v
module com_img_lb_cut_rd #( parameter
    XW       = 12  ,
    PW       = 8   ,//{1:16:}
    DP_DEPTH = 2   ,//{2::}
    LINE_N   = 1   ,//{1::}
    RD_PXL_N = 1   ,//{1:LB_PXL_N:}
    LB_PXL_N = 8   ,//{1:16:2^2}
    LB_DEPTH = 32  ,//{2::}

    LB_AW = $clog2(LB_DEPTH),
    LB_DW = LB_PXL_N*PW     //,
)
(
input  wire                         clk                 ,
input  wire                         rst_n               ,
input  wire                         clear               ,
//cfg
input  wire                         lb_flush_p          ,
input  wire [XW-1:0]                pic_width_m1        ,
//dp
input  wire                         ra_cut_vld          ,
output wire                         ra_cut_rdy          ,
input  wire [XW-1:0]                ra_cut_xpos         ,
input  wire [XW-1:0]                ra_cut_width_m1     ,
output wire [LINE_N-1:0][RD_PXL_N-1:0][PW-1:0]  rd_data ,
output wire [LINE_N-1:0]                        rd_last ,
output wire [LINE_N-1:0]                        rd_vld  ,
input  wire [LINE_N-1:0]                        rd_rdy  ,
//mem
output wire [LINE_N-1:0]            lb_rd_vld           ,
input  wire [LINE_N-1:0]            lb_rd_rdy           ,
output wire [LINE_N-1:0][LB_AW-1:0] lb_rd_addr          ,
input  wire [LINE_N-1:0]            lb_rd_ack           ,
input  wire [LINE_N-1:0][LB_DW-1:0] lb_rd_data          //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  rc_ra_busy_flag;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

wire ra_hs = ra_cut_vld&&ra_cut_rdy;
wire ra_done;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_ra_busy_flag <= 1'b0;
    else if( clear || ra_done )
        rc_ra_busy_flag <= 1'b0;
    else if( ra_hs )
        rc_ra_busy_flag <= 1'b1;
end
assign ra_cut_rdy = !rc_ra_busy_flag;

reg  [XW-1:0] rc_cut_xpos;
reg  [XW-1:0] rc_cut_width_m1;
reg  [XW-1:0] rc_pic_width_m1;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        {rc_cut_xpos,rc_cut_width_m1,rc_pic_width_m1} <= 'b0;
    else if( ra_hs )
        {rc_cut_xpos,rc_cut_width_m1,rc_pic_width_m1} <= {ra_cut_xpos,ra_cut_width_m1,pic_width_m1};
end

reg  [XW-1:0] rc_xcnt;
wire [XW-0:0] xcnt_nxt = rc_xcnt+RD_PXL_N; //spyglass disable W164b
wire xcnten;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_xcnt <= 'b0;
    else if( ra_hs )
        rc_xcnt <= 'b0;
    else if( xcnten )
        rc_xcnt <= xcnt_nxt;
end
wire [XW-1:0] xpos = rc_cut_xpos+rc_xcnt;
wire [XW-0:0] xpos_nxt = rc_cut_xpos+xcnt_nxt;
wire b_xend = xcnt_nxt>{1'b0,rc_cut_width_m1} || xpos_nxt>{1'b0,rc_pic_width_m1};
assign ra_done = xcnten && b_xend;

//com_dp_ram+com_img_lb_rd
wire [LINE_N-1:0]                       lb_ivld       ;
wire [LINE_N-1:0]                       lb_irdy       ;
wire [LINE_N-1:0][XW-1:0]               lb_iaddr      = {LINE_N{xpos}};
wire [LINE_N-1:0]                       lb_ovld       ;
wire [LINE_N-1:0]                       lb_ordy       ;
wire [LINE_N-1:0][RD_PXL_N-1:0][PW-1:0] lb_odata      ;
wire [LINE_N-1:0]                       lb_tmp_rd_vld ;
wire [LINE_N-1:0]                       lb_tmp_rd_rdy ;
wire [LINE_N-1:0][XW-1:0]               lb_tmp_rd_addr;
wire [LINE_N-1:0]                       lb_tmp_rd_ack ;
wire [LINE_N-1:0][RD_PXL_N-1:0][PW-1:0] lb_tmp_rd_data;
com_dp_ram #(
    .AW         ( XW         ), //8
    .DW         ( PW*RD_PXL_N), //8
    .DEPTH      ( DP_DEPTH   )//, //2
)r_com_dp_ram_lb[LINE_N-1:0]
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( lb_ivld              ), //i
    .irdy                 ( lb_irdy              ), //o
    .iaddr                ( lb_iaddr             ), //i
    .ovld                 ( lb_ovld              ), //o
    .ordy                 ( lb_ordy              ), //i
    .odata                ( lb_odata             ), //o

    .ram_rd_vld           ( lb_tmp_rd_vld        ), //o
    .ram_rd_rdy           ( lb_tmp_rd_rdy        ), //i
    .ram_rd_addr          ( lb_tmp_rd_addr       ), //o
    .ram_rd_ack           ( lb_tmp_rd_ack        ), //i
    .ram_rd_data          ( lb_tmp_rd_data       )  //i
);
wire all_hs;
reg  [LINE_N-1:0] arc_busy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_busy <= 'b0;
    else if( clear )
        arc_busy <= 'b0;
    else begin
        for( int i=0; i<LINE_N; i++ )begin
            if( all_hs )
                arc_busy[i] <= 1'b0;
            else if( lb_ivld[i]&&lb_irdy[i] )
                arc_busy[i] <= 1'b1;
        end
    end
end


wire [LINE_N-1:0] arr_all_hs = ({LINE_N{rc_ra_busy_flag}}&lb_irdy) | arc_busy;
assign lb_ivld = {LINE_N{rc_ra_busy_flag}} & ~arc_busy;
assign all_hs = &arr_all_hs;
assign xcnten = all_hs;

com_img_lb_rd #(
    .XW         ( XW         ), //12
    .PW         ( PW         ), //8
    .RD_PXL_N   ( RD_PXL_N   ), //1
    .LB_PXL_N   ( LB_PXL_N   ), //8
    .LB_DEPTH   ( LB_DEPTH   )
)r_com_img_lb_rd[LINE_N-1:0]
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .lb_flush_p           ( lb_flush_p           ), //i
    .pic_width_m1         ( rc_pic_width_m1      ), //i

    .rd_vld               ( lb_tmp_rd_vld        ), //i
    .rd_rdy               ( lb_tmp_rd_rdy        ), //o
    .rd_xpos_s            ( lb_tmp_rd_addr       ), //i
    .rd_ack               ( lb_tmp_rd_ack        ), //o
    .rd_data              ( lb_tmp_rd_data       ), //o

    .lb_rd_vld            ( lb_rd_vld            ), //o
    .lb_rd_rdy            ( lb_rd_rdy            ), //i
    .lb_rd_addr           ( lb_rd_addr           ), //o
    .lb_rd_ack            ( lb_rd_ack            ), //i
    .lb_rd_data           ( lb_rd_data           )  //i
);

wire [LINE_N-1:0][XW-1:0] out_xcnt;
wire [LINE_N-1:0] out_cnt_done;
com_counter #( .DW(XW), .STEP(RD_PXL_N) ) zr_com_counter_out_xcnt[LINE_N-1:0] ( clk,rst_n,clear||lb_flush_p||ra_hs,
    rc_cut_width_m1,rd_vld&rd_rdy ,out_xcnt,out_cnt_done );
reg  [LINE_N-1:0] arb_out_last;
always @*
begin
    for( int i=0; i<LINE_N; i++ )
        arb_out_last[i] = rd_vld[i] && out_xcnt[i]>=rc_cut_width_m1;
end

assign rd_vld = lb_ovld;
assign rd_data= lb_odata;
assign rd_last= arb_out_last;
assign lb_ordy= rd_rdy;

//debug only begin------------------------------------------
//synopsys translate_off
wire [LINE_N-1:0][XW-1:0] dbg_out_xcnt;
wire [LINE_N-1:0] dbg_out_cnt_done;
com_counter #( .DW(XW), .STEP(RD_PXL_N) ) dbg_com_counter_out_xcnt[LINE_N-1:0] ( clk,rst_n,clear||lb_flush_p,
    rc_pic_width_m1,rd_vld&rd_rdy ,dbg_out_xcnt,dbg_out_cnt_done );
//synopsys translate_on
//debug only end  ------------------------------------------

endmodule //end of com_img_lb_cut_rd
`endif //end of com_img_lb_cut_rd_v

