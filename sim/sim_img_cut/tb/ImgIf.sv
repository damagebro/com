interface ImgIf(
    input clk
);
    import ImgPkg::*;

    wire [XW-1:0]  pic_width_m1        ;
    wire [XW-1:0]  pic_heigh_m1        ;
    wire [4:0]     pixel_bitlen        ;
    wire [31:0]    pic_base_addr       ;
    wire [15:0]    line_stride         ;

    logic [XW-1:0] img_cut_wr_xpos     ;
    logic [XW-1:0] img_cut_wr_ypos     ;
    logic [XW-1:0] img_cut_wr_width_m1 ;
    logic [XW-1:0] img_cut_wr_heigh_m1 ;
    logic          img_cut_wr_vld      ;
    logic          img_cut_wr_rdy      ;
    logic          img_cut_wb_resp     ;
    logic [XW-1:0] img_cut_rd_xpos     ;
    logic [XW-1:0] img_cut_rd_ypos     ;
    logic [XW-1:0] img_cut_rd_width_m1 ;
    logic [XW-1:0] img_cut_rd_heigh_m1 ;
    logic          img_cut_rd_vld      ;
    logic          img_cut_rd_rdy      ;

    logic                     pixel_sof           ;
    logic                     pixel_last          ;
    logic [PXL_N-1:0][PW-1:0] pixel_data          ;
    logic                     pixel_valid         ;
    logic                     pixel_ready         ;

    logic                     img_cut_rd_pixel_sof   ;
    logic                     img_cut_rd_pixel_last  ;
    logic [PXL_N-1:0][PW-1:0] img_cut_rd_pixel_data  ;
    logic                     img_cut_rd_pixel_valid ;
    logic                     img_cut_rd_pixel_ready ;
    logic                     img_cut_rd_pixel_eof   ;

    clocking cb @ (posedge clk);
        output pic_width_m1,pic_heigh_m1,pixel_bitlen,pic_base_addr,line_stride;
        output img_cut_wr_xpos,img_cut_wr_ypos,img_cut_wr_width_m1,img_cut_wr_heigh_m1,img_cut_wr_vld;
        input  img_cut_wr_rdy,img_cut_wb_resp;
        output img_cut_rd_xpos,img_cut_rd_ypos,img_cut_rd_width_m1,img_cut_rd_heigh_m1,img_cut_rd_vld;
        input  img_cut_rd_rdy;

        output pixel_sof,pixel_last, pixel_data, pixel_valid;
        input  pixel_ready;
        input  img_cut_rd_pixel_sof,img_cut_rd_pixel_eof,img_cut_rd_pixel_last, img_cut_rd_pixel_data, img_cut_rd_pixel_valid;
        output img_cut_rd_pixel_ready;
    endclocking
    clocking mcb @ (posedge clk);
        input  img_cut_wb_resp;

        input  pixel_sof,pixel_last, pixel_data, pixel_valid;
        input  pixel_ready;
        input  img_cut_rd_pixel_sof,img_cut_rd_pixel_eof,img_cut_rd_pixel_last, img_cut_rd_pixel_data, img_cut_rd_pixel_valid;
        input  img_cut_rd_pixel_ready;
    endclocking
    modport tx(clocking cb);
    modport mon(clocking mcb);
endinterface //ImgIf

typedef virtual ImgIf vImgIf;
typedef virtual ImgIf.tx vImgIfTx;
typedef virtual ImgIf.mon vImgIfMon;