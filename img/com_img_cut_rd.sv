/******************************************************************************
*
*  Authors:   xh
*    Email:   xh@sensetime.com
*     Date:   2021/04/16-10:26:46
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_cut_rd_v
`define com_img_cut_rd_v
module com_img_cut_rd #( parameter
    IMGW_W    = 10,
    IMGH_W    = 10,
    PIX_W     = 16,
    BUS_W     = 32,
    ADDR_W    = 32,
    LEN_W     = 32,
    PIX_NUM   = 2 //,
)(
    //----------------------------------------------------------------------------//
    // global signal
    //----------------------------------------------------------------------------//
    input                               clk               ,
    input                               rst_n             ,
    input                               clear             ,
    //----------------------------------------------------------------------------//
    // cfg signal
    //----------------------------------------------------------------------------//
    input       [IMGW_W-1:0]            cfg_img_width     ,
    input       [IMGH_W-1:0]            cfg_img_height    ,
    input       [ADDR_W-1:0]            cfg_img_start_addr,
    input       [$clog2(PIX_W+1)-1:0]   cfg_pix_w         ,
    input       [15    -1:0]            cfg_line_stride   ,

    input       [IMGW_W-1:0]            cut_xpos          ,
    input       [IMGH_W-1:0]            cut_ypos          ,
    input       [IMGW_W-1:0]            cut_width         ,
    input       [IMGH_W-1:0]            cut_heigh         ,
    input                               cut_rd_vld        ,
    output                              cut_rd_rdy        ,
    //----------------------------------------------------------------------------//
    // EMI signal
    //----------------------------------------------------------------------------//
    output logic                        bus_ra_vld        ,
    input                               bus_ra_rdy        ,
    output logic[ADDR_W-1:0]            bus_ra_addr       ,
    output logic[LEN_W-1:0]             bus_ra_bytelen    ,

    input                               bus_rd_vld        ,
    output                              bus_rd_rdy        ,
    input       [BUS_W-1:0]             bus_rd_data       ,
    input                               bus_rd_done       ,
    //----------------------------------------------------------------------------//
    // input data stream
    //----------------------------------------------------------------------------//
    output wire                          out_sob         ,
    output wire                          out_vld         ,
    input  wire                          out_rdy         ,
    output wire [PIX_NUM-1:0][PIX_W-1:0] out_data        ,
    output wire                          out_last        //,
);
//localparam-----------------------------------------------------------------
localparam AW = ADDR_W;
localparam PW = PIX_W ;
localparam XW = IMGW_W;
localparam YW = IMGH_W;
localparam LW = XW+PW-3; //local length width
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

//com_img_cut_rd_req---
wire               dat_dec_vld   ;
wire               dat_dec_rdy   ;
wire [IMGW_W-1:0]  dat_dec_xpos  ;
wire [IMGW_W-1:0]  dat_dec_width ;
wire [IMGH_W-1:0]  dat_dec_heigh ;
wire [LW-1:0]      dat_dec_line_wordlen;

wire [LW-1:0] bus_ra_bytelen_t;

com_img_cut_rd_req #(
    .IMGW_W     ( IMGW_W     ), //10
    .IMGH_W     ( IMGH_W     ), //10
    .PIX_W      ( PIX_W      ), //16
    .BUS_W      ( BUS_W      ), //128
    .ADDR_W     ( ADDR_W     ), //32
    .LEN_W      ( LW         )  //32
)u_com_img_cut_rd_req
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .pic_width            ( cfg_img_width        ), //i
    .pic_heigh            ( cfg_img_height       ), //i
    .pic_start_addr       ( cfg_img_start_addr   ), //i
    .pixel_bitdepth       ( cfg_pix_w            ), //i
    .line_stride          ( cfg_line_stride      ), //i

    .cut_xpos             ( cut_xpos             ), //i
    .cut_ypos             ( cut_ypos             ), //i
    .cut_width            ( cut_width            ), //i
    .cut_heigh            ( cut_heigh            ), //i
    .cut_rd_vld           ( cut_rd_vld           ), //i
    .cut_rd_rdy           ( cut_rd_rdy           ), //o

    .dat_dec_vld          ( dat_dec_vld          ), //o
    .dat_dec_rdy          ( dat_dec_rdy          ), //i
    .dat_dec_xpos         ( dat_dec_xpos         ), //o
    .dat_dec_width        ( dat_dec_width        ), //o
    .dat_dec_heigh        ( dat_dec_heigh        ), //o
    .dat_dec_line_wordlen ( dat_dec_line_wordlen ), //o

    .bus_ra_vld           ( bus_ra_vld           ), //o
    .bus_ra_rdy           ( bus_ra_rdy           ), //i
    .bus_ra_addr          ( bus_ra_addr          ), //o
    .bus_ra_bytelen       ( bus_ra_bytelen_t     )  //o
);
assign bus_ra_bytelen = bus_ra_bytelen_t + LEN_W'(0);

//cut_dat dp_buffer---
wire                    cut_dat_ivld  = dat_dec_vld;
wire                    cut_dat_irdy  ;
wire [XW*2+YW*1+LW-1:0] cut_dat_idata = {dat_dec_xpos,dat_dec_width,dat_dec_heigh,dat_dec_line_wordlen};
wire                    cut_dat_ovld  ;
wire                    cut_dat_ordy  ;
wire [XW*2+YW*1+LW-1:0] cut_dat_odata ;
com_dp_buffer #(
    .DW         ( XW*2+YW*1+LW      ), //8
    .DEPTH      ( 4                 )  //4
)r_com_dp_buffer_cut_dat
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( cut_dat_ivld         ), //i
    .irdy                 ( cut_dat_irdy         ), //o
    .idata                ( cut_dat_idata        ), //i
    .ovld                 ( cut_dat_ovld         ), //o
    .ordy                 ( cut_dat_ordy         ), //i
    .odata                ( cut_dat_odata        )  //o
);
assign dat_dec_rdy = cut_dat_irdy;

//dec cnt---
wire cut_dat_dec_start;
wire cut_dat_dec_done ;
reg  rc_cut_dat_dec_busy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_cut_dat_dec_busy <= 1'b0;
    else if( clear || (cut_dat_dec_done&&!cut_dat_dec_start) )
        rc_cut_dat_dec_busy <= 1'b0;
    else if( cut_dat_dec_start )
        rc_cut_dat_dec_busy <= 1'b1;
end
wire bus_rd_hs = bus_rd_vld&&bus_rd_rdy;
assign cut_dat_ordy = cut_dat_dec_done;

wire [XW-1:0]  cut_dat_xpos  ;
wire [XW-1:0]  cut_dat_width ;
wire [YW-1:0]  cut_dat_heigh ;
wire [LW-1:0]  cut_dat_line_wordlen;
assign {cut_dat_xpos,cut_dat_width,cut_dat_heigh,cut_dat_line_wordlen} = cut_dat_odata;
wire [LW+YW-1:0] cut_dat_wordlen = cut_dat_line_wordlen * cut_dat_heigh;

wire out_hs = out_vld&&out_rdy;
reg  [XW-1:0] rc_dec_ycnt;
reg  [LW+YW-1:0] rc_bus_dat_cnt;

always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_dec_ycnt <= 'b0;
    else if( cut_dat_dec_start )
        rc_dec_ycnt <= 'b0;
    else if( out_hs&&out_last )
        rc_dec_ycnt <= rc_dec_ycnt + 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_dat_cnt <= 'b0;
    else if( clear || cut_dat_dec_done )
        rc_bus_dat_cnt <= 'b0;
    else if( bus_rd_hs )
        rc_bus_dat_cnt <= rc_bus_dat_cnt + 1'b1;
end

wire [YW-1:0] cut_dat_heigh_m1 = cut_dat_heigh-1'b1;
assign cut_dat_dec_done = out_hs && out_last && rc_dec_ycnt==cut_dat_heigh_m1;
assign cut_dat_dec_start= (cut_dat_ovld&&bus_rd_vld) && !rc_cut_dat_dec_busy;

//dec bus dat---
wire bus_unpack_cfg_en = cut_dat_dec_start;
wire bus_rd_vld_t = bus_rd_vld && rc_cut_dat_dec_busy;
wire bus_rd_rdy_t;
com_img_bus_unpack #(
    .BUS_W      ( BUS_W      ), //32
    .PIX_W      ( PIX_W      ), //12
    .PIX_NUM    ( PIX_NUM    ), //2
    .WIN_W      ( XW         ),//, //10
    .WIN_H      ( YW         )//, //10
)u_img_bus_unpack
(
    //----------------------------------------------------------------------------//
    // global signal
    //----------------------------------------------------------------------------//
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //----------------------------------------------------------------------------//
    // cfg signal
    //----------------------------------------------------------------------------//
    .cfg_en_p             ( bus_unpack_cfg_en    ), //i
    .win_width            ( cut_dat_width        ), //i
    .win_height           ( cut_dat_heigh        ), //i
    .win_xpos             ( cut_dat_xpos         ), //i
    .cfg_pix_w            ( cfg_pix_w            ), //i
    //----------------------------------------------------------------------------//
    .out_vld              ( out_vld              ), //o
    .out_rdy              ( out_rdy              ), //i
    .out_data             ( out_data             ), //o
    .out_last             ( out_last             ), //o
    //----------------------------------------------------------------------------//
    // bus signal
    //----------------------------------------------------------------------------//
    .bus_vld              ( bus_rd_vld_t         ), //i
    .bus_rdy              ( bus_rd_rdy_t         ), //o
    .bus_data             ( bus_rd_data          )  //i
);

reg  cut_dat_dec_done_d;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        cut_dat_dec_done_d <= 'b0;
    else
        cut_dat_dec_done_d <= cut_dat_dec_done;
end

wire out_eob;
assign bus_rd_rdy = bus_rd_rdy_t && (rc_cut_dat_dec_busy && rc_bus_dat_cnt<cut_dat_wordlen);
assign out_sob  = cut_dat_dec_start;
assign out_eob = cut_dat_dec_done_d;


endmodule //end of com_img_cut_rd
`endif //end of com_img_cut_rd_v

