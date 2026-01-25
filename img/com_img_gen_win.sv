/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/04/28-11:04:12
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_gen_win_v
`define com_img_gen_win_v
module com_img_gen_win #( parameter
    XW       = 12  ,
    YW       = 12  ,
    PW       = 8   ,
    WIN_W    = 3   ,
    WIN_H    = 3   ,
    PIC_W    = 4096,
    LB_PXL_N = 8   ,
    PAD_MODE = "reflect"//, //reflect or fix
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
input  wire [`COM_SRAM_W-1:0]   mem_cfg             ,  //i_cfg_sram_ctrl

input  wire [XW-1:0]            pic_width_m1        ,
input  wire [YW-1:0]            pic_heigh_m1        ,

input  wire                     in_sof              ,
input  wire                     in_valid            ,
output wire                     in_ready            ,
input  wire [PW-1:0]            in_data             ,
input  wire                     in_last             ,

output wire                                 win_sof    ,
output wire                                 win_valid  ,
input  wire                                 win_ready  ,
output wire [WIN_H-1:0][WIN_W-1:0][PW-1:0]  win_data   ,
output wire                                 win_last   //,
);
//localparam-----------------------------------------------------------------
// localparam LB_PXL_N = 8   ;
localparam LB_DEPTH = (PIC_W+LB_PXL_N-1)/LB_PXL_N ;

localparam LB_AW = $clog2(LB_DEPTH);
localparam LB_DW = LB_PXL_N*PW     ;

localparam WIN_X_STEP = 1;
localparam WIN_Y_STEP = 1;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire [5:0] win_heigh_m1 = WIN_H-1; //spyglass disable W164b
wire [5:0] win_width = WIN_W; //spyglass disable W164b,W528 //5bit means win_size<32x32
wire [5:0] win_heigh = WIN_H; //spyglass disable W164b
// wire [5:0] win_width_half = {1'b0,win_width[5:1]}; //5/2=2, 6/2=3;
wire [5:0] win_heigh_half = {1'b0,win_heigh[5:1]};

wire [5:0] x_step = WIN_X_STEP; //spyglass disable W164b
wire [5:0] y_step = WIN_Y_STEP; //spyglass disable W164b
//statement------------------------------------------------------------------

wire                     lb_wr_eol ;
wire [YW-1:0]            lb_wr_ypos;
wire                     lb_rd_eol ;
wire [YW-1:0]            lb_rd_ypos;

wire                                 win_ram_wr_vld        ;
wire                                 win_ram_wr_rdy        ;
wire [LB_AW-1:0]                     win_ram_wr_addr       ;
wire [LB_DW-1:0]                     win_ram_wr_data       ;

wire [WIN_H-2:0]                     win_ram_rd_vld        ;
wire [WIN_H-2:0]                     win_ram_rd_rdy        ;
wire [WIN_H-2:0][LB_AW-1:0]          win_ram_rd_addr       ;
wire [WIN_H-2:0]                     win_ram_rd_ack        ;
wire [WIN_H-2:0][LB_DW-1:0]          win_ram_rd_data       ;
com_img_gen_win_core #(
    .XW         ( XW         ), //12
    .YW         ( YW         ), //12
    .PW         ( PW         ), //8
    .WIN_W      ( WIN_W      ), //3
    .WIN_H      ( WIN_H      ), //3
    .PAD_MODE   ( PAD_MODE   ), //reflect
    .LB_PXL_N   ( LB_PXL_N   ), //8
    .LB_DEPTH   ( LB_DEPTH   )//,
)u_com_img_gen_win_core
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg&stauts--
    .pic_width_m1         ( pic_width_m1         ), //i
    .pic_heigh_m1         ( pic_heigh_m1         ), //i
    .x_step               ( x_step               ), //i
    .y_step               ( y_step               ), //i
    .lb_wr_eol            ( lb_wr_eol            ), //o
    .lb_wr_ypos           ( lb_wr_ypos           ), //spyglass disable W528, //o
    .lb_rd_eol            ( lb_rd_eol            ), //o
    .lb_rd_ypos           ( lb_rd_ypos           ), //spyglass disable W528, //o
    //dp---
    .in_sof               ( in_sof               ), //i
    .in_valid             ( in_valid             ), //i
    .in_ready             ( in_ready             ), //o
    .in_data              ( in_data              ), //i
    .in_last              ( in_last              ), //i

    .win_sof              ( win_sof              ), //o
    .win_valid            ( win_valid            ), //o
    .win_ready            ( win_ready            ), //i
    .win_data             ( win_data             ), //o
    .win_last             ( win_last             ), //o
    //ram--
    .ram_wr_vld           ( win_ram_wr_vld       ), //o
    .ram_wr_rdy           ( win_ram_wr_rdy       ), //i
    .ram_wr_addr          ( win_ram_wr_addr      ), //o
    .ram_wr_data          ( win_ram_wr_data      ), //o

    .ram_rd_vld           ( win_ram_rd_vld       ), //o
    .ram_rd_rdy           ( win_ram_rd_rdy       ), //i
    .ram_rd_addr          ( win_ram_rd_addr      ), //o
    .ram_rd_ack           ( win_ram_rd_ack       ), //i
    .ram_rd_data          ( win_ram_rd_data      )  //i
);

reg  [5:0] rc_lb_wr_ycnt_rnd;
reg  [5:0] rc_lb_rd_ycnt_rnd;
wire [5:0] lb_wr_ycnt_rnd_nxt = rc_lb_wr_ycnt_rnd+1'b1;
wire [5:0] lb_rd_ycnt_rnd_nxt = rc_lb_rd_ycnt_rnd+y_step;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_lb_wr_ycnt_rnd <= 'b0;
    else if( in_sof )
        rc_lb_wr_ycnt_rnd <= 'b0;
    else if( lb_wr_eol )
        rc_lb_wr_ycnt_rnd <= lb_wr_ycnt_rnd_nxt>=win_heigh_m1 ? 6'b0 : lb_wr_ycnt_rnd_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_lb_rd_ycnt_rnd <= 'b0;
    else if( in_sof )
        rc_lb_rd_ycnt_rnd <= 'b0;
    else if( lb_rd_eol )
        rc_lb_rd_ycnt_rnd <= lb_rd_ycnt_rnd_nxt>=win_heigh_m1 ? 6'b0 : lb_rd_ycnt_rnd_nxt;
end

wire [5:0] lb_rd_cy = rc_lb_rd_ycnt_rnd;
wire [6:0] lb_rd_cy_t = lb_rd_cy - win_heigh_half;//spyglass disable W164b, //win top_line
wire [5:0] lb_rd_cy_t_rnd = lb_rd_cy_t[6] ? $signed({1'b0,win_heigh_m1})+$signed(lb_rd_cy_t) : lb_rd_cy_t;
wire b_conflict_flag;
// wire b_conflict_flag = lb_rd_cy_t_rnd==rc_lb_wr_ycnt_rnd && |(arb_lb_wr_vld&arb_lb_rd_vld);

//deal wr/rd conflict---
reg  [WIN_H-2:0] arb_lb_wr_vld;
reg  [WIN_H-2:0] arb_win_rd_rdy;
reg  [WIN_H-2:0] arc_win_rd_ack;
always@*
begin
    for( int i=0; i<WIN_H-1; i++ )
        arb_lb_wr_vld[i] = i==rc_lb_wr_ycnt_rnd ? win_ram_wr_vld : 1'b0;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_win_rd_ack <= 'b0;
    else
        arc_win_rd_ack <= win_ram_rd_vld & arb_win_rd_rdy;
end

assign win_ram_wr_rdy = 1'b1;
assign win_ram_rd_ack = arc_win_rd_ack;
assign win_ram_rd_rdy = arb_win_rd_rdy;

//ram_cell------------
wire [WIN_H-2:0]               lb_cen           ;
wire [WIN_H-2:0]               lb_we            ;
wire [WIN_H-2:0][LB_AW-1:0]    lb_addr          ;
wire [WIN_H-2:0][LB_DW-1:0]    lb_din           ;
wire [WIN_H-2:0][LB_DW-1:0]    lb_qout          ;
com_spram_shell #(
    .DATA_W     ( LB_DW ), //32
    .DEPTH      ( LB_DEPTH )//, //512
)t_com_spram_shell_lb[WIN_H-2:0]
(
    .clk                  ( clk              ), //i
    .mem_cfg              ( mem_cfg          ), //i

    .ce_n                 ( lb_cen           ), //i
    .we                   ( lb_we            ), //i
    .addr                 ( lb_addr          ), //i
    .wr_data              ( lb_din           ), //i
    .rd_data              ( lb_qout          )  //o
);

//win_rd_idx->lb_rd_idx--
reg  [WIN_H-2:0][7:0] arb_win2lb_rd_idx_t;
reg  [WIN_H-2:0][5:0] arb_win2lb_rd_idx;
reg  [WIN_H-2:0]            arb_lb_rd_vld;
reg  [WIN_H-2:0]            arb_lb_rd_rdy;
reg  [WIN_H-2:0][LB_AW-1:0] arb_lb_rd_addr;

reg  [WIN_H-2:0][7:0] arb_lb2win_rd_idx_t;
reg  [WIN_H-2:0][5:0] arb_lb2win_rd_idx;
reg  [WIN_H-2:0][LB_DW-1:0] arb_win_rd_data;
//lb[cy] = rd[win_t];
//rd[i] = lb[cy+i-win_t];
//lb[i] = rd[win_t+i-cy];
always@*
begin
    for( int i=0; i<WIN_H-1; i++ )begin
        //win_rd->lb
        arb_win2lb_rd_idx_t[i] = win_heigh_half + i - rc_lb_rd_ycnt_rnd;//spyglass disable W164b //U5+U6-U6=S8
        arb_win2lb_rd_idx[i] = arb_win2lb_rd_idx_t[i][7] ? $signed({1'b0,win_heigh_m1})+$signed(arb_win2lb_rd_idx_t[i]) :
                           arb_win2lb_rd_idx_t[i]>={2'b0,win_heigh_m1} ? (arb_win2lb_rd_idx_t[i]-win_heigh_m1) : arb_win2lb_rd_idx_t[i];

        arb_lb_rd_vld [i] = win_ram_rd_vld [ arb_win2lb_rd_idx[i] ];
        arb_lb_rd_addr[i] = win_ram_rd_addr[ arb_win2lb_rd_idx[i] ];

        //lb->win_rd
        arb_lb2win_rd_idx_t[i] = rc_lb_rd_ycnt_rnd + i - win_heigh_half;//spyglass disable W164b //U6+U6-U5=S8
        arb_lb2win_rd_idx[i] = arb_lb2win_rd_idx_t[i][7] ? $signed({1'b0,win_heigh_m1})+$signed(arb_lb2win_rd_idx_t[i]) :
                           arb_lb2win_rd_idx_t[i]>={2'b0,win_heigh_m1} ? (arb_lb2win_rd_idx_t[i]-win_heigh_m1) : arb_lb2win_rd_idx_t[i];

        arb_win_rd_data[i] = lb_qout[ arb_lb2win_rd_idx[i] ];
        arb_win_rd_rdy [i] = arb_lb_rd_rdy[ arb_lb2win_rd_idx[i] ];
    end
end

//lb port---
reg  [WIN_H-2:0]               arb_lb_cen ;
reg  [WIN_H-2:0]               arb_lb_we  ;
reg  [WIN_H-2:0][LB_AW-1:0]    arb_lb_addr;
always@*
begin
    for( int i=0; i<WIN_H-1; i++ )begin
        arb_lb_cen[i] = !(arb_lb_wr_vld[i] || arb_lb_rd_vld[i]);
        arb_lb_we [i] = arb_lb_wr_vld[i] ? 1'b1 : 1'b0;
        arb_lb_addr[i]= arb_lb_wr_vld[i] ? win_ram_wr_addr : arb_lb_rd_addr[i];
        arb_lb_rd_rdy[i] = (arb_lb_rd_vld[i]&&arb_lb_wr_vld[i]) ? 1'b0 : 1'b1;
    end
end
assign lb_cen = arb_lb_cen;
assign lb_we  = arb_lb_we;
assign lb_addr= arb_lb_addr;
assign lb_din = {(WIN_H-1){win_ram_wr_data}};
assign win_ram_rd_data = arb_win_rd_data;

assign b_conflict_flag = lb_rd_cy_t_rnd==rc_lb_wr_ycnt_rnd && |(arb_lb_wr_vld&arb_lb_rd_vld); //spyglass disable W528

endmodule //end of com_img_gen_win
`endif //end of com_img_gen_win_v

