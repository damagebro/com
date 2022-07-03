interface ImgWinIf(
    input clk
);
    import ImgWinPkg::*;

    logic [XW-1:0]            pic_width           ;
    logic [YW-1:0]            pic_heigh           ;

    logic                     in_sof              ;
    logic                     in_valid            ;
    logic                     in_ready            ;
    logic [PW-1:0]            in_data             ;
    logic                     in_last             ;

    logic                                 win_sof    ;
    logic                                 win_valid  ;
    logic                                 win_ready  ;
    logic [WIN_H-1:0][WIN_W-1:0][PW-1:0]  win_data   ;
    logic                                 win_last   ;


    clocking cb @ (posedge clk);
        output pic_width,pic_heigh;
        output in_sof,in_data,in_last,in_valid;
        input  in_ready;
        input  win_sof,win_data,win_last,win_valid;
        output win_ready;
    endclocking
    // modport tx(clocking cb);
endinterface //ImgWinIf
typedef virtual ImgWinIf vImgWinIf;