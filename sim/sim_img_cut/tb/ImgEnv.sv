class ImgEnv;

// mailbox mbx_gen2drv;
// event evt_gen2drv;
vImgIf m_img_vif;
ImgCfg cImgCfg;
ImgDrv cImgDrv;
ImgScb cImgScb;

extern function new( input vImgIf img_vif );
extern function build();
extern task run();

endclass //ImgEnv

function ImgEnv::new( input vImgIf img_vif );
    cImgCfg = new();
    m_img_vif = img_vif;
endfunction:new
function ImgEnv::build();
    cImgCfg.parse_cfgfile("../img_cut.cfg");
    cImgDrv = new( cImgCfg,m_img_vif );
    cImgScb = new( cImgCfg,m_img_vif );
endfunction:build

task ImgEnv::run();
    fork
        cImgDrv.run();
        cImgScb.run();
    join
endtask:run

