class ImgDrv;

localparam PXL_N = ImgPkg::PXL_N;
// import img_pkg::*;
vImgIfTx m_img_vif;
ImgCfg m_cfg;

function new( ImgCfg pc_cfg, input vImgIfTx img_vif );
    // m_cfg = new();
    m_cfg = pc_cfg; //class pointer assigned
    m_img_vif = img_vif;
endfunction:new
extern function build();
extern task run();

extern task pic_config();
extern task pic_set_cut_wr();
extern task pic_set_cut_rd();
extern task pic_stim();

endclass //ImgDrv

function ImgDrv::build();
endfunction:build

task ImgDrv::pic_config();
    m_img_vif.cb.pic_width_m1  <= m_cfg.pic_width-1;
    m_img_vif.cb.pic_heigh_m1  <= m_cfg.pic_heigh-1;
    m_img_vif.cb.pixel_bitlen  <= m_cfg.pixel_bitlen;
    m_img_vif.cb.pic_base_addr <= m_cfg.pic_base_addr;
    m_img_vif.cb.line_stride   <= m_cfg.line_stride;

    m_img_vif.cb.img_cut_wr_vld <= 1'b0;
    m_img_vif.cb.img_cut_rd_vld <= 1'b0;
    m_img_vif.cb.img_cut_rd_pixel_ready <= 1'b1;
    repeat(10) @(m_img_vif.cb);
endtask:pic_config
task ImgDrv::pic_set_cut_wr();
    m_img_vif.cb.img_cut_wr_xpos     <= m_cfg.img_cut_wr_xpos;
    m_img_vif.cb.img_cut_wr_ypos     <= m_cfg.img_cut_wr_ypos;
    m_img_vif.cb.img_cut_wr_width_m1 <= m_cfg.img_cut_wr_width-1;
    m_img_vif.cb.img_cut_wr_heigh_m1 <= m_cfg.img_cut_wr_heigh-1;
    m_img_vif.cb.img_cut_wr_vld <= 1'b1;
    do
        @(m_img_vif.cb);
    while( !m_img_vif.cb.img_cut_wr_rdy );
    m_img_vif.cb.img_cut_wr_vld <= 1'b0;
    $display("NOTICE(), start img cut wr, x:%1d, y:%1d, cut_w:%1d, cut_h:%1d",m_cfg.img_cut_wr_xpos,m_cfg.img_cut_wr_ypos,m_cfg.img_cut_wr_width,m_cfg.img_cut_wr_heigh);
endtask:pic_set_cut_wr
task ImgDrv::pic_set_cut_rd();
    m_img_vif.cb.img_cut_rd_xpos      <= m_cfg.img_cut_rd_xpos;
    m_img_vif.cb.img_cut_rd_ypos      <= m_cfg.img_cut_rd_ypos;
    m_img_vif.cb.img_cut_rd_width_m1  <= m_cfg.img_cut_rd_width-1;
    m_img_vif.cb.img_cut_rd_heigh_m1  <= m_cfg.img_cut_rd_heigh-1;
    m_img_vif.cb.img_cut_rd_vld <= 1'b1;
    do
        @(m_img_vif.cb);
    while( !m_img_vif.cb.img_cut_rd_rdy );
    m_img_vif.cb.img_cut_rd_vld <= 1'b0;
    $display("NOTICE(), start img cut rd, x:%1d, y:%1d, cut_w:%1d, cut_h:%1d",m_cfg.img_cut_rd_xpos,m_cfg.img_cut_rd_ypos,m_cfg.img_cut_rd_width,m_cfg.img_cut_rd_heigh);
endtask:pic_set_cut_rd

task ImgDrv::pic_stim();
    m_img_vif.cb.pixel_sof <= 1'b1;
    @(m_img_vif.cb);
    m_img_vif.cb.pixel_sof <= 1'b0;
    repeat(4) @(m_img_vif.cb);
    for( int y=0; y<m_cfg.pic_heigh; y++ )
    for( int x=0; x<m_cfg.pic_width; x+=PXL_N )begin
        m_img_vif.cb.pixel_valid <= 1'b1;
        m_img_vif.cb.pixel_last  <= (x+PXL_N)>=m_cfg.pic_width;
        for( int i=0; i<PXL_N; i++ )
            m_img_vif.cb.pixel_data[i] <= (x+i)*(y+1);
        do
            @(m_img_vif.cb);
        while( !m_img_vif.cb.pixel_ready );
        m_img_vif.cb.pixel_valid <= 1'b0;
    end
endtask:pic_stim

task ImgDrv::run();
    top.reset();
    #100ns;
    // m_cfg.parse_cfgfile("../img_cut.cfg");

    pic_config();
    pic_set_cut_wr();
    pic_stim();
    wait( m_img_vif.cb.img_cut_wb_resp==1'b1 );
    $display("NOTICE(), img cut wr finish");
    pic_set_cut_rd();
    wait( m_img_vif.cb.img_cut_rd_pixel_eof==1'b1 );
    $display("NOTICE(), img cut rd finish");

    #2000;
    $finish;
endtask //run
