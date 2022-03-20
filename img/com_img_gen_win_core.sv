/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/04/27-10:08:30
*
*  Description:
*  -common image module, generate window(such as 3x3, 5x3, 5x5..)
*  -datapath: in+wr_lb->rd_req->rd_dat->gen_win(genw)->pad+out
*  -the win_size must be odd number;
*  -max support win_size is (63x63);
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_gen_win_core_v
`define com_img_gen_win_core_v
module com_img_gen_win_core #( parameter
    XW       = 12  ,
    YW       = 12  ,
    PW       = 8   ,
    WIN_W    = 3   ,
    WIN_H    = 3   ,
    LB_PXL_N = 8   ,
    LB_DEPTH       ,
    PAD_MODE = "reflect", //reflect or fix

    LB_AW = $clog2(LB_DEPTH),
    LB_DW = LB_PXL_N*PW     //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg&stauts--
input  wire [XW-1:0]            pic_width_m1        ,
input  wire [YW-1:0]            pic_heigh_m1        ,
input  wire [5:0]               x_step              ,
input  wire [5:0]               y_step              ,
output wire                     lb_wr_eol           ,
output wire [YW-1:0]            lb_wr_ypos          ,
output wire                     lb_rd_eol           ,
output wire [YW-1:0]            lb_rd_ypos          ,
//dp---
input  wire                     in_sof              ,
input  wire                     in_valid            ,
output wire                     in_ready            ,
input  wire [PW-1:0]            in_data             ,
input  wire                     in_last             ,

output wire                                 win_sof           ,
output wire                                 win_valid         ,
input  wire                                 win_ready         ,
output wire [WIN_H-1:0][WIN_W-1:0][PW-1:0]  win_data          ,
output wire                                 win_last          ,
//ram--
output wire                                 ram_wr_vld        ,
input  wire                                 ram_wr_rdy        ,
output wire [LB_AW-1:0]                     ram_wr_addr       ,
output wire [LB_DW-1:0]                     ram_wr_data       ,

output wire [WIN_H-2:0]                     ram_rd_vld        ,
input  wire [WIN_H-2:0]                     ram_rd_rdy        ,
output wire [WIN_H-2:0][LB_AW-1:0]          ram_rd_addr       ,
input  wire [WIN_H-2:0]                     ram_rd_ack        ,
input  wire [WIN_H-2:0][LB_DW-1:0]          ram_rd_data       //,
);
//localparam-----------------------------------------------------------------
//assert( (WIN_H>=3 && WIN_W>=3) && (WIN_H<=63 && WIN_W<=63) );
//assert( WIN_H[0] && WIN_W[0] );//only odd number image_windows;
// localparam WW_L2 = $clog2(WIN_W);
// localparam WH_L2 = $clog2(WIN_H);

localparam RD_DEPTH = 6;
localparam RD_CW    = $clog2(RD_DEPTH+1);

localparam XDIFF = 1;
//reg  declare---------------------------------------------------------------
reg  rc_wr_lb_done_flag;
reg  rc_rd_req_done_flag;

reg  [XW-1:0] rc_wr_lb_xcnt;
reg  [YW-1:0] rc_wr_lb_ycnt;
reg  [YW-1:0] rc_rd_req_xcnt;
reg  [YW-1:0] rc_rd_req_ycnt;
reg  [XW-1:0] rc_genw_xcnt;
reg  [YW-1:0] rc_genw_ycnt;
reg  [XW-1:0] rc_out_xcnt;
reg  [XW-1:0] rc_out_ycnt;
//wire declare---------------------------------------------------------------
wire [XW-0:0] pic_width = pic_width_m1 + 1'b1; //spyglass disable W164b
wire [YW-0:0] pic_heigh = pic_heigh_m1 + 1'b1; //spyglass disable W164b

// wire [XW-1:0] x_step = XW'(2);
// wire [YW-1:0] y_step = YW'(2);
wire [5:0] win_width = WIN_W; //spyglass disable W164b, //6bit means win_size<64x64
wire [5:0] win_heigh = WIN_H; //spyglass disable W164b
wire [5:0] win_width_half = {1'b0,win_width[5:1]}; //5/2=2, 6/2=3;
wire [5:0] win_heigh_half = {1'b0,win_heigh[5:1]};

wire rd_req_sof;
wire rd_req_eof;
wire rd_req_sol;
wire rd_req_eol;
wire rd_dat_eol; //~=genw_eol

wire out_sol;
wire out_eol;
wire obuf_eol; //obuf_in_eol, obuf_out_eol=out_eol

wire b_in_hold_flag;
wire b_in_avl_line; //the input line need gen_win; //in_ycnt==win_heigh_half+y_step*n;
//statement------------------------------------------------------------------
//in+wr_lb->rd_req->rd_dat->gen_win(genw)->pad+out
//1.wr_lb---
wire in_hs = in_valid&&in_ready;
wire b_wr_lb_xend = rc_wr_lb_xcnt==pic_width_m1;
wire b_wr_lb_yend = rc_wr_lb_ycnt==pic_heigh_m1;
wire b_wr_lb_done = b_wr_lb_yend&&b_wr_lb_xend && in_hs;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_wr_lb_xcnt <= 'b0;
        rc_wr_lb_ycnt <= 'b0;
    end
    else if( clear || in_sof )begin
        rc_wr_lb_xcnt <= 'b0;
        rc_wr_lb_ycnt <= 'b0;
    end
    else if( in_hs )begin
        rc_wr_lb_xcnt <= in_last ? XW'(0) : rc_wr_lb_xcnt+1'b1;
        if( in_last )
            rc_wr_lb_ycnt <= rc_wr_lb_ycnt+1'b1;
    end
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_wr_lb_done_flag <= 1'b0;
    else if( clear || in_sof )
        rc_wr_lb_done_flag <= 1'b0;
    else if( b_wr_lb_done )
        rc_wr_lb_done_flag <= 1'b1;
end

wire in_valid_t = in_valid && !b_in_hold_flag;
wire lb_wr_in_valid;
wire lb_wr_in_ready;
wire in_dp_valid;
wire in_dp_ready;
assign in_ready = lb_wr_in_ready&&in_dp_ready && !b_in_hold_flag;
assign lb_wr_in_valid = in_valid_t && in_dp_ready;
assign in_dp_valid  = in_valid_t && lb_wr_in_ready;
com_img_lb_wr #(
    .XW         ( XW         ), //12
    .PW         ( PW         ), //8
    .WR_PXL_N   ( 1          ), //1
    .LB_PXL_N   ( LB_PXL_N   ), //8
    .LB_DEPTH   ( LB_DEPTH   )
)u_com_img_lb_wr
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .pic_width_m1         ( pic_width_m1         ), //i

    .in_sof               ( in_sof               ), //i
    .in_valid             ( lb_wr_in_valid       ), //i
    .in_ready             ( lb_wr_in_ready       ), //o
    .in_data              ( in_data              ), //i
    .in_last              ( in_last              ), //i

    .lb_wr_vld            ( ram_wr_vld           ), //o
    .lb_wr_rdy            ( ram_wr_rdy           ), //i
    .lb_wr_addr           ( ram_wr_addr          ), //o
    .lb_wr_data           ( ram_wr_data          )  //o
);

reg  [YW-1:0] rc_in_y;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_in_y <= 'b0;
    else if( clear || in_sof )
        rc_in_y <= 'b0;
    else if( rd_dat_eol )
        rc_in_y <= rc_in_y+1'b1;
end
wire [YW-1:0] in_avl_ypos = win_heigh_half + y_step*rc_in_y;
wire [YW-1:0] in_avl_ypos_m1 = in_avl_ypos-1'b1;
assign b_in_avl_line = y_step==6'b1 ? rc_wr_lb_ycnt>=(win_heigh_half+YW'(0)) : rc_wr_lb_ycnt==in_avl_ypos;

//2.rd_req---
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_req_done_flag <= 1'b0;
    else if( clear || in_sof )
        rc_rd_req_done_flag <= 1'b0;
    else if( rd_req_eof )
        rc_rd_req_done_flag <= 1'b1;
end

wire [YW-0:0] pic_heigh_lo = win_heigh_half + (YW+1)'(0);
wire [YW-0:0] pic_heigh_hi = win_heigh_half + pic_heigh;
reg  [WIN_H-1:0][YW-0:0] arb_rd_req_ycnt;
reg  [WIN_H-1:0] arb_line_active_flag; //(cy-half_t)>=0 && (cy+half_b)<h is active line;
reg  [WIN_H-1:0] arc_line_active_flag;
reg  [WIN_H-1:0] arc_outline_active_flag;
always @*
begin
    for( int i=0; i<WIN_H; i++ ) begin
        arb_rd_req_ycnt[i] = rc_rd_req_ycnt+i;
        arb_line_active_flag[i] = arb_rd_req_ycnt[i]>=pic_heigh_lo && arb_rd_req_ycnt[i]<pic_heigh_hi;
    end
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_line_active_flag <= 'b0;
    else if( clear || in_sof )
        arc_line_active_flag <= 'b0;
    else if( rd_req_sol )
        arc_line_active_flag <= arb_line_active_flag;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_outline_active_flag <= 'b0;
    else if( clear || in_sof )
        arc_outline_active_flag <= 'b0;
    else if( out_sol )
        arc_outline_active_flag <= arb_line_active_flag;
end

reg  rc_rd_req_line_flag;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_req_line_flag <= 1'b0;
    else if( clear || in_sof || rd_req_eol )
        rc_rd_req_line_flag <= 1'b0;
    else if( rd_req_sol )
        rc_rd_req_line_flag <= 1'b1;
end

wire [0:0]       rd_req_arr_ivld = rc_rd_req_line_flag;
wire [0:0]       rd_req_arr_irdy ;
wire [WIN_H-2:0] rd_req_arr_ovld ;
wire [WIN_H-2:0] rd_req_arr_ordy ;
com_mimo #(
    .ICH        ( 1        ), //1
    .OCH        ( WIN_H-1  )  //2
)r_com_mimo_rd_req
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .arr_ivld             ( rd_req_arr_ivld      ), //i
    .arr_irdy             ( rd_req_arr_irdy      ), //o
    .arr_ovld             ( rd_req_arr_ovld      ), //o
    .arr_ordy             ( rd_req_arr_ordy      )  //i
);

wire [WIN_H-2:0]          arr_rd_req_lb_vld    ;
wire [WIN_H-2:0]          arr_rd_req_lb_rdy    ;
wire [WIN_H-2:0][XW-1:0]  arr_rd_req_lb_xpos_s ;
wire [WIN_H-2:0]          arr_rd_req_lb_ack    ;
wire [WIN_H-2:0][PW-1:0]  arr_rd_req_lb_data   ;
com_img_lb_rd #(
    .XW         ( XW         ), //12
    .PW         ( PW         ), //8
    .RD_PXL_N   ( 1          ), //1
    .LB_PXL_N   ( LB_PXL_N   ), //8
    .LB_DEPTH   ( LB_DEPTH   )
)u_com_img_lb_rd[WIN_H-2:0]
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .lb_flush_p           ( rd_req_sol           ), //i
    .pic_width_m1         ( pic_width_m1         ), //i

    .rd_vld               ( arr_rd_req_lb_vld    ), //i
    .rd_rdy               ( arr_rd_req_lb_rdy    ), //o
    .rd_xpos_s            ( arr_rd_req_lb_xpos_s ), //i
    .rd_ack               ( arr_rd_req_lb_ack    ), //o
    .rd_data              ( arr_rd_req_lb_data   ), //o

    .lb_rd_vld            ( ram_rd_vld           ), //o
    .lb_rd_rdy            ( ram_rd_rdy           ), //i
    .lb_rd_addr           ( ram_rd_addr          ), //o
    .lb_rd_ack            ( ram_rd_ack           ), //i
    .lb_rd_data           ( ram_rd_data          )  //i
);


wire rd_ack_eol;//win top line rd ack; only win top lines will conflict;
reg  [XW-1:0] rc_rd_ack_xcnt;
wire [XW-0:0] rd_ack_xcnt_nxt = rc_rd_ack_xcnt + 1'b1; //spyglass disable W164b
wire ack_xcnten = arc_line_active_flag[0] ? arr_rd_req_lb_ack[0] : rd_req_arr_ovld[0]&&rd_req_arr_ordy[0];
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_ack_xcnt <= 'b0;
    else if( clear || in_sof || rd_ack_eol )
        rc_rd_ack_xcnt <= 'b0;
    else if( ack_xcnten )
        rc_rd_ack_xcnt <= rd_ack_xcnt_nxt;
end
wire b_rd_ack_xend = rd_ack_xcnt_nxt>=pic_width || rd_ack_xcnt_nxt[XW];
assign rd_ack_eol = b_rd_ack_xend && ack_xcnten;

reg  [XW-1:0] rc_rd_req_xpos;
wire [XW-0:0] rd_req_xcnt_nxt = rc_rd_req_xcnt + 1'b1; //spyglass disable W164b
wire [YW-0:0] rd_req_ycnt_nxt = rc_rd_req_ycnt + y_step; //spyglass disable W164b
wire b_rd_req_xend = rd_req_xcnt_nxt>=pic_width || rd_req_xcnt_nxt[XW];
wire b_rd_req_yend = rd_req_ycnt_nxt>=pic_heigh || rd_req_ycnt_nxt[YW];
wire rd_req_ihs = rd_req_arr_ivld&&rd_req_arr_irdy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_req_xcnt <= 'b0;
    else if( clear || in_sof || rd_ack_eol )
        rc_rd_req_xcnt <= 'b0;
    else if( rd_req_ihs )
        rc_rd_req_xcnt <= rd_req_xcnt_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_req_xpos <= 'b0;
    else if( rd_req_ihs )
        rc_rd_req_xpos <= rc_rd_req_xcnt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_req_ycnt <= 'b0;
    else if( clear || in_sof )
        rc_rd_req_ycnt <= 'b0;
    else if( rd_ack_eol )
        rc_rd_req_ycnt <= rd_req_ycnt_nxt[YW-1:0];
end
assign arr_rd_req_lb_xpos_s = { (WIN_H-1){rc_rd_req_xpos} };


wire [YW-1:0] rd_req_ycnt_sel = rd_ack_eol ? rd_req_ycnt_nxt[YW-1:0] : rc_rd_req_ycnt;
wire [6:0] rd_req_ydiff = rc_wr_lb_ycnt - rd_req_ycnt_sel;
wire b_rd_req_avl = rc_wr_lb_ycnt>=in_avl_ypos_m1 || rc_wr_lb_done_flag&&!rc_rd_req_done_flag;

wire [XW-0:0] rd_ack_xdiff = rc_rd_ack_xcnt - rc_wr_lb_xcnt; //spyglass disable W164b
assign b_in_hold_flag = !rc_wr_lb_done_flag && in_valid && (rd_req_ydiff[6] || rd_req_ydiff[5:0]>=win_heigh_half ) &&
                                                           (rd_ack_xdiff[XW]&&!b_rd_ack_xend || rd_ack_xdiff[XW-1:0]<XW'(XDIFF));
//assert(!b_in_hold_flag);

// reg  [WIN_H-2:0][RD_CW-1:0] arb_rd_req_otf_cnt_t;
reg  [WIN_H-2:0][RD_CW-1:0] arb_rd_req_otf_cnt;
reg  [WIN_H-2:0][RD_CW-1:0] arc_rd_req_otf_cnt;
always @*
begin
    for( int i=0; i<WIN_H-1; i++ ) begin
        arb_rd_req_otf_cnt[i] = arc_rd_req_otf_cnt[i] + (arr_rd_req_lb_vld[i]&&arr_rd_req_lb_rdy[i]) - arr_rd_req_lb_ack[i];
        // arb_rd_req_otf_cnt_t[i] = arc_rd_req_otf_cnt[i] + 1'b1;
    end
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_rd_req_otf_cnt <= 'b0;
    else if( clear || in_sof )
        arc_rd_req_otf_cnt <= 'b0;
    else begin
        for( int i=0; i<WIN_H-1; i++ )
          if( (arr_rd_req_lb_vld[i] & arr_rd_req_lb_rdy[i]) || arr_rd_req_lb_ack[i] )
            arc_rd_req_otf_cnt[i] <= arb_rd_req_otf_cnt[i];
    end
end

//3.rd_dat---
wire [WIN_H-2:0]              arr_rd_dat_wr_en    = arr_rd_req_lb_ack;
wire [WIN_H-2:0][PW-1:0]      arr_rd_dat_wr_data  = arr_rd_req_lb_data;
wire [WIN_H-2:0]              arr_rd_dat_wr_full  ;
wire [WIN_H-2:0]              arr_rd_dat_rd_en    ;
wire [WIN_H-2:0][PW-1:0]      arr_rd_dat_rd_data  ;
wire [WIN_H-2:0]              arr_rd_dat_rd_empty ;
wire [WIN_H-2:0][RD_CW-1:0]   arr_rd_dat_wl       ;//water_level = DEPTH-count
com_sync_fifo_reg #(
    .DW         ( PW        ), //8
    .DEPTH      ( RD_DEPTH  ), //4
    .FIFO_TYPE  ( StlCommon::FIFOTYPE_CWL )
)r_com_sync_fifo_reg_rd_dat[WIN_H-2:0]
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( arr_rd_dat_wr_en     ), //i
    .wr_data              ( arr_rd_dat_wr_data   ), //i
    .wr_full              ( arr_rd_dat_wr_full   ), //o
    .rd_en                ( arr_rd_dat_rd_en     ), //i
    .rd_data              ( arr_rd_dat_rd_data   ), //o
    .rd_empty             ( arr_rd_dat_rd_empty  ), //o
    .count                ( arr_rd_dat_wl        )  //o
);
reg  [WIN_H-2:0] arb_rd_req_arr_ovld;
reg  [WIN_H-2:0] arb_rd_req_arr_ordy;
always @*
begin
    for( int i=0; i<WIN_H-1; i++ ) begin
        arb_rd_req_arr_ovld[i] = arc_line_active_flag[i] ? (rd_req_arr_ovld[i]   && arc_rd_req_otf_cnt[i]<arr_rd_dat_wl[i] && !arr_rd_dat_wr_full[i]) : 1'b0;
        arb_rd_req_arr_ordy[i] = arc_line_active_flag[i] ? (arr_rd_req_lb_rdy[i] && arc_rd_req_otf_cnt[i]<arr_rd_dat_wl[i] && !arr_rd_dat_wr_full[i]) : 1'b1;
    end
end
assign arr_rd_req_lb_vld = arb_rd_req_arr_ovld;
assign rd_req_arr_ordy = arb_rd_req_arr_ordy;

//in_dp
wire b_in_dp_avl_flag = b_in_avl_line && arc_line_active_flag[WIN_H-1];
wire          in_dp_ivld  = b_in_dp_avl_flag && in_dp_valid;
wire          in_dp_irdy  ;
wire [PW-1:0] in_dp_idata = in_data;
wire          in_dp_ovld  ;
wire          in_dp_ordy  ;
wire [PW-1:0] in_dp_odata ;
com_dp_buffer #(
    .DW         ( PW         ), //8
    .DEPTH      ( LB_PXL_N+2 )  //4
)r_com_dp_buffer_in_dp
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( in_dp_ivld           ), //i
    .irdy                 ( in_dp_irdy           ), //o
    .idata                ( in_dp_idata          ), //i
    .ovld                 ( in_dp_ovld           ), //o
    .ordy                 ( in_dp_ordy           ), //i
    .odata                ( in_dp_odata          )  //o
);
assign in_dp_ready = b_in_dp_avl_flag ? in_dp_irdy : 1'b1;


//4.gen_win(all line data sync)---
wire rd_dat_centre_ovld = !arr_rd_dat_rd_empty[WIN_H/2];
reg  [WIN_H-1:0] arb_rd_dat_ovld;
always @*
begin
    for( int i=0; i<WIN_H-1; i++ )begin
        arb_rd_dat_ovld[i] = arc_line_active_flag[i] ? !arr_rd_dat_rd_empty[i] : rd_dat_centre_ovld;
    end
    arb_rd_dat_ovld[WIN_H-1] = arc_line_active_flag[WIN_H-1] ? in_dp_ovld : rd_dat_centre_ovld;
end

wire genw_vld = &arb_rd_dat_ovld;
wire genw_rdy ;
wire [WIN_H-1:0][PW-1:0] genw_arr_odat = {in_dp_odata,arr_rd_dat_rd_data};
assign arr_rd_dat_rd_en = ~arr_rd_dat_rd_empty & {(WIN_H-1){genw_rdy}};
assign in_dp_ordy = genw_rdy;

// win order #NOTICE()
// y order={cy+1, cy, cy-1};
// x order={cx+1, cx, cx-1};
wire genw_hs = genw_vld && genw_rdy;
wire genw_x_shift;
reg  [WIN_H-1:0][WIN_W-1:0][PW-1:0] aarc_genw_dat;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        aarc_genw_dat <= 'b0;
    else begin
        for( int y=0; y<WIN_H; y++ )begin
            if( genw_hs && arc_line_active_flag[y] )
                aarc_genw_dat[y][WIN_W-1] <= genw_arr_odat[y];
            if( genw_x_shift && arc_outline_active_flag[y] )
                aarc_genw_dat[y][WIN_W-2:0] <= aarc_genw_dat[y][WIN_W-1:1];
        end//end for(y)
    end//end else
end

wire [XW-0:0] genw_xcnt_nxt = rc_genw_xcnt+1'b1; //spyglass disable W164b
wire [YW-0:0] genw_ycnt_nxt = rc_genw_ycnt+y_step; //spyglass disable W164b
wire b_genw_xend = genw_xcnt_nxt>=(XW+1)'(pic_width);
wire b_genw_yend = genw_ycnt_nxt>=(YW+1)'(pic_heigh); //spyglass disable W528
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_genw_xcnt <= 'b0;
    else if( in_sof || obuf_eol )
        rc_genw_xcnt <= 'b0;
    else if( genw_hs )
        rc_genw_xcnt <= genw_xcnt_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_genw_ycnt <= 'b0;
    else if( in_sof )
        rc_genw_ycnt <= 'b0;
    else if( genw_hs && b_genw_xend )
        rc_genw_ycnt <= genw_ycnt_nxt;
end

reg  rc_genw_xpend_flag;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_genw_xpend_flag <= 1'b0;
    else if( clear || in_sof || obuf_eol )
        rc_genw_xpend_flag <= 1'b0;
    else if( b_genw_xend && genw_hs )
        rc_genw_xpend_flag <= 1'b1;
end


//5.obuf->win pad+out---
//5.1 obuf--
// wire [5:0] shift_cnt_tol_num = b_obuf_xfst_flag ? xfst_num : x_step;
wire [5:0] shift_cnt_tol_num;
wire [5:0] shift_cnt_tol_num_m1 = shift_cnt_tol_num - 1'b1;

reg  rc_outline_flag;//obuf
reg  rc_win_out_flag;
reg  [5:0] rc_shift_cnt;//obuf shift
wire shift_valid = rc_genw_xpend_flag ? rc_outline_flag : genw_vld;
wire shift_ready;
wire shift_cnten_hs = shift_valid&&shift_ready;
wire shift_cnt_done;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_outline_flag <= 1'b0;
    else if( clear || in_sof || obuf_eol )
        rc_outline_flag <= 1'b0;
    else if( out_sol )
        rc_outline_flag <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_win_out_flag <= 1'b0;
    else if( clear || in_sof || out_eol )
        rc_win_out_flag <= 1'b0;
    else if( out_sol )
        rc_win_out_flag <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_shift_cnt <= 'b0;
    else if( in_sof || shift_cnt_done )
        rc_shift_cnt <= 'b0;
    else if( shift_cnten_hs )
        rc_shift_cnt <= rc_shift_cnt+1'b1;
end
wire b_shift_cnt_end = rc_shift_cnt==shift_cnt_tol_num_m1;
assign shift_cnt_done = shift_cnten_hs && b_shift_cnt_end;
// assign win_valid = rc_shift_cnt==shift_cnt_tol_num_m1 && rc_outline_flag;

wire obuf_ivld     ;
wire obuf_irdy     ;
wire obuf_ovld     ;
wire obuf_ordy     = win_ready;
wire obuf_in_upen  ;
com_pipe_ctrl #( .NUM_PIPE(1) ) r_com_pipe_ctrl_obuf( clk, rst_n, clear, obuf_ivld, obuf_irdy, obuf_ovld, obuf_ordy, obuf_in_upen );
assign obuf_ivld = rc_shift_cnt==shift_cnt_tol_num_m1 && (rc_genw_xpend_flag ? rc_outline_flag : genw_vld);
assign shift_ready = (b_shift_cnt_end||rc_genw_xpend_flag) ? obuf_irdy : rc_outline_flag;

//obuf_ihs xcnt;
wire obuf_ihs = obuf_in_upen;
reg  [XW-1:0] rc_obuf_xcnt;
wire [XW-0:0] obuf_xcnt_nxt = rc_obuf_xcnt+x_step; //spyglass disable W164b
wire b_obuf_xend = obuf_xcnt_nxt>=(XW+1)'(pic_width);
assign obuf_eol = b_obuf_xend&&obuf_ihs;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_obuf_xcnt <= 'b0;
    else if( clear || in_sof || obuf_eol )
        rc_obuf_xcnt <= 'b0;
    else if( obuf_ihs )
        rc_obuf_xcnt <= obuf_xcnt_nxt;
end

wire [XW-0:0] obuf_cx_s = rc_obuf_xcnt - win_width_half; //spyglass disable W164b
wire [XW-0:0] obuf_cx_e = rc_obuf_xcnt + win_width_half; //spyglass disable W164b
wire [XW-1:0] obuf_cx_s_clp = obuf_cx_s[XW] ? XW'(0) : obuf_cx_s[XW-1:0];
wire [XW-1:0] obuf_cx_e_clp =(obuf_cx_e[XW] || obuf_cx_e[XW-1:0]>=pic_width_m1) ? pic_width_m1 : obuf_cx_e[XW-1:0];

wire b_obuf_xfst_flag = rc_obuf_xcnt==XW'(0);
wire [5:0] xfst_num = obuf_cx_e_clp - obuf_cx_s_clp + 1'b1;
assign shift_cnt_tol_num = b_obuf_xfst_flag ? xfst_num : x_step;

//5.2win pad+out--
// reg  [XW-1:0] rc_out_xcnt; //centre x
// reg  [XW-1:0] rc_out_ycnt;
wire [XW-0:0] cx_s = rc_out_xcnt - win_width_half; //spyglass disable W164b
wire [XW-0:0] cx_e = rc_out_xcnt + win_width_half; //spyglass disable W164b
wire [XW-1:0] cx_s_clp = cx_s[XW] ? XW'(0) : cx_s[XW-1:0]; //spyglass disable W528
wire [XW-1:0] cx_e_clp =(cx_e[XW] || cx_e[XW-1:0]>=pic_width_m1) ? pic_width_m1 : cx_e[XW-1:0]; //spyglass disable W528

wire [YW-0:0] cy_s = rc_out_ycnt - win_heigh_half; //spyglass disable W164b
wire [YW-0:0] cy_e = rc_out_ycnt + win_heigh_half; //spyglass disable W164b
wire [YW-1:0] cy_s_clp = cy_s[YW] ? YW'(0) : cy_s[YW-1:0]; //spyglass disable W528
wire [YW-1:0] cy_e_clp =(cy_e[YW] || cy_e[YW-1:0]>=pic_heigh_m1) ? pic_heigh_m1 : cy_e[YW-1:0]; //spyglass disable W528

wire win_hs = win_valid && win_ready;
wire [XW-0:0] out_xcnt_nxt = rc_out_xcnt+x_step; //spyglass disable W164b
wire [YW-0:0] out_ycnt_nxt = rc_out_ycnt+y_step; //spyglass disable W164b
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_out_xcnt <= 'b0;
    else if( clear || in_sof || out_eol )
        rc_out_xcnt <= 'b0;
    else if( win_hs )
        rc_out_xcnt <= out_xcnt_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_out_ycnt <= 'b0;
    else if( clear || in_sof )
        rc_out_ycnt <= 'b0;
    else if( out_eol )
        rc_out_ycnt <= out_ycnt_nxt;
end
wire b_out_xend = out_xcnt_nxt>=(XW+1)'(pic_width);
wire b_out_yend = out_ycnt_nxt>=(YW+1)'(pic_heigh); //spyglass disable W528

//pad-
/*
exmple pic_w*pic_h=10x10, win_x*win_y=5x5, reflect pad
2  1  0 -1 -2 //pad
3  2  1  0 -1 //pad
4  3  2  1  0
..
9  8  7  6  5
10 9  8  7  6 //pad
11 10 9  8  7 //pad

reflect pad: bnd_idx + (bnd_pos-pad_pos);
*/
//
//---------
// wire [WIN_W-1:0] arr_xpad_flag;
// wire [WIN_H-1:0] arr_ypad_flag;
// win order #NOTICE()
// y order={cy+1, cy, cy-1};
// x order={cx+1, cx, cx-1};
reg  [WIN_W-1:0] arb_xpad_flag;
reg  [WIN_H-1:0] arb_ypad_flag;
reg  [WIN_W-1:0][XW+1:0] arb_xpad_pos;
reg  [WIN_H-1:0][YW+1:0] arb_ypad_pos;
// reg  [WIN_W-1:0][XW-1:0] arb_xpad_pos_rnd;//not use
// reg  [WIN_H-1:0][YW-1:0] arb_ypad_pos_rnd;//not use

reg  [WIN_W-1:0]      arb_xbnd_flag;//boundary
reg  [WIN_H-1:0]      arb_ybnd_flag;
reg  [5:0] rb_xbnd_idx;
reg  [5:0] rb_ybnd_idx;
reg  rb_xbnd_find_flag;
reg  rb_ybnd_find_flag;

reg  [WIN_W-1:0][5:0] arb_xpad_idx;
reg  [WIN_H-1:0][5:0] arb_ypad_idx;
//rnd = mirror(x,0,pic_w) = x<0 ? -x : x>pic_w? x-pic_w : x;
always @*
begin
    rb_xbnd_find_flag = 1'b0;
    rb_ybnd_find_flag = 1'b0;
    rb_xbnd_idx = 6'b0;
    rb_ybnd_idx = 6'b0;
    for( int x=0; x<WIN_W; x++ )begin
        arb_xpad_pos[x] = $signed(cx_s) + $signed({1'b0,x});
        arb_xpad_flag[x] = arb_xpad_pos[x][XW+1] || arb_xpad_pos[x][XW] || arb_xpad_pos[x][XW-1:0]>pic_width_m1;
        arb_xbnd_flag[x] = arb_xpad_pos[x][XW-1:0]==XW'(0) || arb_xpad_pos[x][XW-1:0]==pic_width_m1&&!arb_xpad_pos[x][XW];
        // arb_xpad_pos_rnd[x] = arb_xpad_pos[x][XW+1] ? (~arb_xpad_pos[x][XW-1:0]+1) :
        //                       arb_xpad_pos[x][XW-1:0]>pic_width_m1 ? {pic_width_m1,1'b0}-arb_xpad_pos[x][XW-1:0] : arb_xpad_pos[x][XW-1:0];

        if( arb_xbnd_flag[x] && !rb_xbnd_find_flag )begin
            rb_xbnd_find_flag = 1'b1; //spyglass disable W415a
            rb_xbnd_idx = x; //spyglass disable W415a,W164b
        end
    end//end for(x)
    for( int y=0; y<WIN_H; y++ )begin
        arb_ypad_pos[y] = $signed(cy_s) + $signed({1'b0,y});
        arb_ypad_flag[y] = arb_ypad_pos[y][YW+1] || arb_ypad_pos[y][YW] || arb_ypad_pos[y][YW-1:0]>pic_heigh_m1;
        arb_ybnd_flag[y] = arb_ypad_pos[y][YW-1:0]==YW'(0) || arb_ypad_pos[y][YW-1:0]==pic_heigh_m1&&!arb_ypad_pos[y][YW];;
        // arb_ypad_pos_rnd[y] = arb_ypad_pos[y][YW+1] ? (~arb_ypad_pos[y][YW-1:0]+1) :
        //                       arb_ypad_pos[y][YW-1:0]>pic_heigh_m1 ? {pic_heigh_m1,1'b0}-arb_ypad_pos[y][YW-1:0] : arb_ypad_pos[y][YW-1:0];

        if( arb_ybnd_flag[y] && !rb_ybnd_find_flag )begin
            rb_ybnd_find_flag = 1'b1; //spyglass disable W415a
            rb_ybnd_idx = y; //spyglass disable W415a,W164b
        end
    end//end for(y)
end
generate
if( PAD_MODE=="reflect" )begin:gen_reflect_pad
    always @*
    begin
        for( int x=0; x<WIN_W; x++ )begin
            if( arb_xpad_flag[x] )
                arb_xpad_idx[x] = $signed({1'b0,rb_xbnd_idx}) + ($signed({arb_xpad_pos[rb_xbnd_idx]})-$signed({arb_xpad_pos[x]}));
            else
                arb_xpad_idx[x] = x; //spyglass disable W164b
            arb_xpad_idx[x] = arb_xpad_idx[x]>=win_width ? 6'b0 : arb_xpad_idx[x]; //spyglass disable SelfAssignment-ML //clip
        end//end for(x)
        for( int y=0; y<WIN_H; y++ )begin
            if( arb_ypad_flag[y] )
                arb_ypad_idx[y] = $signed({1'b0,rb_ybnd_idx}) + ($signed({arb_ypad_pos[rb_ybnd_idx]})-$signed({arb_ypad_pos[y]}));
            else
                arb_ypad_idx[y] = y; //spyglass disable W164b
            arb_ypad_idx[y] = arb_ypad_idx[y]>=win_heigh ? 6'b0 : arb_ypad_idx[y]; //spyglass disable SelfAssignment-ML //clip
        end//end for(y)
    end//always
end//if(PAD_MODE=="reflect")
else begin:gen_fix_pad  //if( PAD_MODE=="fix" )
    always @*
    begin
        for( int x=0; x<WIN_W; x++ )begin
            if( arb_xpad_flag[x] )
                arb_xpad_idx[x] = rb_xbnd_idx;
            else
                arb_xpad_idx[x] = x;
            arb_xpad_idx[x] = arb_xpad_idx[x]>=win_width ? 6'b0 : arb_xpad_idx[x]; //clip
        end//end for(x)
        for( int y=0; y<WIN_H; y++ )begin
            if( arb_ypad_flag[y] )
                arb_ypad_idx[y] = rb_ybnd_idx;
            else
                arb_ypad_idx[y] = y;
            arb_ypad_idx[y] = arb_ypad_idx[y]>=win_heigh ? 6'b0 : arb_ypad_idx[y]; //clip
        end//end for(y)
    end
end//else(PAD_MODE=="fix")
endgenerate

reg  [WIN_H-1:0][WIN_W-1:0][PW-1:0] aarb_win_odat;
always @*
begin
    for( int y=0; y<WIN_H; y++ )
    for( int x=0; x<WIN_W; x++ )
        aarb_win_odat[y][x] = aarc_genw_dat[ arb_ypad_idx[y] ][ arb_xpad_idx[x] ];
end

//6.out---
assign win_sof   = out_sol && rc_genw_ycnt==YW'(0);
assign win_valid = obuf_ovld;
assign win_data  = aarb_win_odat;
assign win_last  = win_valid && b_out_xend;

assign genw_x_shift = shift_cnten_hs;
assign genw_rdy = (rc_genw_xpend_flag||!rc_outline_flag||!genw_vld) ? 1'b0 : shift_ready;

assign out_sol = genw_vld && !rc_win_out_flag; //(genw_vld && rc_shift_cnt==0 && rc_out_xcnt==0;)
assign out_eol = win_hs && b_out_xend;

wire rd_req_sol_s1 = b_rd_req_avl && (in_hs&&in_last&&rc_wr_lb_ycnt==in_avl_ypos_m1 || rd_dat_eol&&!rc_rd_req_done_flag);
wire rd_req_sol_s2 = b_rd_req_avl && (in_hs&&in_last&&rc_wr_lb_ycnt==in_avl_ypos_m1 || rd_dat_eol&&rc_wr_lb_done_flag&&!rc_rd_req_done_flag);
assign rd_req_sol = y_step==6'd2 ? rd_req_sol_s2 : rd_req_sol_s1;
assign rd_req_eol = rd_req_ihs && b_rd_req_xend;
assign rd_dat_eol = genw_hs && b_genw_xend;
assign rd_req_eof = rd_req_ihs && b_rd_req_xend && b_rd_req_yend;
assign rd_req_sof = rd_req_sol && rc_rd_req_xcnt==XW'(0) && rc_rd_req_ycnt==YW'(0); //spyglass disable W528

assign lb_wr_eol = in_hs && b_wr_lb_xend;
assign lb_wr_ypos= rc_wr_lb_ycnt;
assign lb_rd_eol = rd_dat_eol;
assign lb_rd_ypos= rc_genw_ycnt;

endmodule //end of com_img_gen_win_core
`endif //end of com_img_gen_win_core_v


/*
win5x5, screen=6x6, x_step=1, y_step=1, examle:
x orient, x_step=1
     x1  x2  x3  x4  x5
t1:  -   -   1   2   3
t2:  -   1   2   3   4
t3:  1   2   3   4   5
t4:  2   3   4   5   6
t5:  3   4   5   6   -
t6:  4   5   6   -   -

y orient, y_step=1
     t1  t2  t3  t4  t5  t6
y1:  -   -   1   2   3   4
y2:  -   1   2   3   4   5
y3:  1   2   3   4   5   6
y4:  2   3   4   5   6   -
y5:  3   4   5   6   -   -


---
x orient, x_step=2
     x1  x2  x3  x4  x5
t1:  -   -   1   2   3
t2:  1   2   3   4   5
t3:  3   4   5   6   -

y orient, y_step=2
     t1  t2  t3
y1:  -   1   3
y2:  -   2   4
y3:  1   3   5
y4:  2   4   6
y5:  3   5   -
*/