class ImgScb;
    //param
    localparam PXL_N = ImgPkg::PXL_N;
    //vars
    vImgIfMon m_img_vif;
    ImgCfg m_cfg;

function new( ImgCfg pc_cfg, input vImgIfMon img_vif );
    m_cfg = pc_cfg;  //class pointer assigned
    m_img_vif = img_vif;
endfunction:new

extern task watch_dog();
extern task img_score_borad();
extern task run();

endclass:ImgScb //--------------------------------------------

task ImgScb::img_score_borad();
    int x_s=m_cfg.img_cut_rd_xpos;
    int y_s=m_cfg.img_cut_rd_ypos;
    int cut_w = (x_s+m_cfg.img_cut_rd_width)>m_cfg.pic_width ? m_cfg.pic_width-x_s : m_cfg.img_cut_rd_width;
    int cut_h = (y_s+m_cfg.img_cut_rd_heigh)>m_cfg.pic_heigh ? m_cfg.pic_heigh-y_s : m_cfg.img_cut_rd_heigh;
    int xcnt=0;
    int ycnt=0;
    bit [31:0] pixel_avl_mask = (1<<m_cfg.pixel_bitlen)-1;
    forever begin
        @(m_img_vif.mcb);
        if( m_img_vif.mcb.img_cut_rd_pixel_valid && m_img_vif.mcb.img_cut_rd_pixel_ready )begin
            int golden;
            int x = x_s+xcnt;
            int y = y_s+ycnt;
            for( int i=0; i<PXL_N; i++ )begin
                bit b_pxl_avl_flag = (xcnt+i)<cut_w;
                golden = (x+i)*(y+1);
                golden = golden & pixel_avl_mask;
                if( m_img_vif.mcb.img_cut_rd_pixel_data[i]!=golden && b_pxl_avl_flag )begin
                    $display( "NOTICE(), ###compare fail!!!##########################, the position is x:%1d, y:%1d; rtl_data:0x%1h, golden:0x%1h",x+i,y, m_img_vif.mcb.img_cut_rd_pixel_data[i],golden );
                    #100;
                    $finish;
                end
            end

            xcnt = xcnt+PXL_N;
            if( xcnt>=cut_w )begin
                xcnt=0;
                ycnt++;
                if( ycnt>=cut_h )begin
                    $display( "NOTICE(), ###compare pass!!!##########################" );
                end
            end
        end//end if(pixel_valid)
    end //end forever
endtask:img_score_borad

task ImgScb::watch_dog();
    int cnt;
    int cnt_timeout = 10_0000;
    forever begin
        @(m_img_vif.mcb);
        cnt++;
        if( m_img_vif.mcb.pixel_valid&&m_img_vif.mcb.pixel_ready || m_img_vif.mcb.img_cut_rd_pixel_valid&&m_img_vif.mcb.img_cut_rd_pixel_ready  )begin
            cnt = 0;
            repeat(cnt_timeout) @(m_img_vif.mcb);
        end
        if( cnt>=cnt_timeout )begin
            $display( "NOTICE(), ###compare time_out!!!##########################");
            #100;
            $finish;
        end
    end
endtask:watch_dog

task ImgScb::run();
    fork
        watch_dog(); //thread1

        begin:thread2
            wait( m_img_vif.mcb.img_cut_wb_resp==1'b1 );
            img_score_borad();
        end:thread2
    join
endtask:run
