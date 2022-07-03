class ImgWinDrv;

// import img_win_pkg::*;
vImgWinIf m_img_win_vif;

extern function new( input vImgWinIf img_win_vif );
extern function build();
extern task run();

extern task pic_config();
extern task pic_stim();
extern task win_resp();

endclass //ImgWinDrv

function ImgWinDrv::new( input vImgWinIf img_win_vif );
    m_img_win_vif = img_win_vif;
endfunction:new
function ImgWinDrv::build();
endfunction:build

task ImgWinDrv::pic_config();
    @(m_img_win_vif.cb );
    m_img_win_vif.cb.pic_width <= ImgWinPkg::PIC_W;
    m_img_win_vif.cb.pic_heigh <= ImgWinPkg::PIC_H;
endtask
task ImgWinDrv::pic_stim();
    bit vld;

    m_img_win_vif.cb.in_sof <= 1'b1;
    @(m_img_win_vif.cb );
    m_img_win_vif.cb.in_sof <= 1'b0;
    for( int y=0; y<ImgWinPkg::PIC_H; y++ )
    for( int x=0; x<ImgWinPkg::PIC_W; )begin
        // @(m_img_win_vif.cb );
        vld = $random%2;
        if( vld )begin
            m_img_win_vif.cb.in_valid <= 1'b1;
            m_img_win_vif.cb.in_data <= y+x;
            m_img_win_vif.cb.in_last <= x>=ImgWinPkg::PIC_W-1;
            do
                @(m_img_win_vif.cb );
            while( !m_img_win_vif.cb.in_ready );
            m_img_win_vif.cb.in_valid <= 1'b0;
            x++;
        end
    end
endtask //rd_fifo
task ImgWinDrv::win_resp();
    forever begin
        @(m_img_win_vif.cb );
        m_img_win_vif.cb.win_ready <= $random()%2;
        // m_img_win_vif.cb.win_ready <= 1;
    end
endtask //wr_fifo

task ImgWinDrv::run();
    top.reset();
    pic_config();
    fork
        pic_stim();
        win_resp();
    join_none

    #20000;
    $finish;
endtask //run
