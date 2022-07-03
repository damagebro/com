class ImgWinEnv;

// mailbox mbx_gen2drv;
// event evt_gen2drv;
vImgWinIf m_img_win_vif;
ImgWinDrv cImgWinDrv;

extern function new( input vImgWinIf img_win_vif );
extern function build();
extern task run();

endclass //ImgWinEnv

function ImgWinEnv::new( input vImgWinIf img_win_vif );
    m_img_win_vif = img_win_vif;
endfunction:new
function ImgWinEnv::build();
    cImgWinDrv = new( m_img_win_vif );
endfunction:build

task ImgWinEnv::run();
    cImgWinDrv.run();
endtask:run

