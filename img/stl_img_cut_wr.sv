//////////////////////////////////////////////////////////////////////////////
//
//  Description: . 
//               
//  Authors:   Xuhui
//  Version:   1.0
//  
//  Note: 1. 
//  
//////////////////////////////////////////////////////////////////////////////
module stl_img_cut_wr#(
    parameter   IMGW_W    = 10,
    parameter   IMGH_W    = 10,
    parameter   PIX_W     = 16,
    parameter   PIX_NUM   = 2 , 
    parameter   BUS_W     = 32,
    parameter   ADDR_W    = 32,
    parameter   LEN_W     = 16//,
)(
    //----------------------------------------------------------------------------//
    // global signal
    //----------------------------------------------------------------------------//    
    input                               clk               ,
    input                               rst_n             ,
    `STL_MCFG_IF(0)                     mem_cfg           ,
    //----------------------------------------------------------------------------//
    // cfg signal
    //----------------------------------------------------------------------------//
    input       [IMGW_W-1:0]            cfg_img_width     , // 'd544
    input       [IMGH_W-1:0]            cfg_img_height    , // 'd544
    input       [ADDR_W-1:0]            cfg_img_start_addr, // 
    input       [ADDR_W-1:0]            cfg_img_addr_stride,
    input       [IMGW_W-1:0]            cfg_cut_xpos      , // 'd16
    input       [IMGH_W-1:0]            cfg_cut_ypos      , // 'd16
    input       [IMGW_W-1:0]            cfg_cut_width     , // 'd512
    input       [IMGH_W-1:0]            cfg_cut_height    , // 'd512
    input       [$clog2(PIX_W+1)-1:0]   cfg_pix_w         , //

    input                               cfg_en_p          , // 
    //----------------------------------------------------------------------------//
    // status signal
    //----------------------------------------------------------------------------//
    output logic                        cut_wr_done       ,
    //----------------------------------------------------------------------------//
    // EMI signal
    //----------------------------------------------------------------------------//
    output logic                        bus_wa_vld        ,
    input                               bus_wa_rdy        ,
    output logic[ADDR_W-1:0]            bus_wa_addr       ,
    output logic[LEN_W-1:0]             bus_wa_byte_len   ,
    output logic                        bus_wd_vld        ,
    input                               bus_wd_rdy        ,
    output logic[BUS_W-1:0]             bus_wd_data       ,
    input                               bus_wb_resp       ,
    //----------------------------------------------------------------------------//
    // input data stream
    //----------------------------------------------------------------------------//    
    input                               in_sof            ,
    input                               in_vld            ,
    input       [PIX_NUM-1:0][PIX_W-1:0]in_data           ,
    input                               in_sol            , //not used
    input                               in_eol            ,
    input                               in_eof            , //not used
    output logic                        in_rdy

);

    logic       [IMGW_W-1:0]            lock_cfg_img_width      ;
    logic       [IMGH_W-1:0]            lock_cfg_img_height     ;
    logic       [ADDR_W-1:0]            lock_cfg_img_start_addr ;
    logic       [ADDR_W-1:0]            lock_cfg_img_addr_stride;
    logic       [IMGW_W-1:0]            lock_cfg_cut_xpos       ;
    logic       [IMGH_W-1:0]            lock_cfg_cut_ypos       ;
    logic       [IMGW_W-1:0]            lock_cfg_cut_width      ;
    logic       [IMGH_W-1:0]            lock_cfg_cut_height     ;
    logic       [$clog2(PIX_W+1)-1:0]   lock_cfg_pix_w          ;

    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        lock_cfg_img_width      <= '0;
        lock_cfg_img_height     <= '0;
        lock_cfg_img_start_addr <= '0;
        lock_cfg_img_addr_stride<= '0;
        lock_cfg_cut_xpos       <= '0;
        lock_cfg_cut_ypos       <= '0;
        lock_cfg_cut_width      <= '0;
        lock_cfg_cut_height     <= '0;
        lock_cfg_pix_w          <= '0;
    end else if (cfg_en_p) begin
        lock_cfg_img_width      <= cfg_img_width      ;
        lock_cfg_img_height     <= cfg_img_height     ;
        lock_cfg_img_start_addr <= cfg_img_start_addr ;
        lock_cfg_img_addr_stride<= cfg_img_addr_stride;
        lock_cfg_cut_xpos       <= cfg_cut_xpos       ;
        lock_cfg_cut_ypos       <= cfg_cut_ypos       ;
        lock_cfg_cut_width      <= cfg_cut_width      ;
        lock_cfg_cut_height     <= cfg_cut_height     ;
        lock_cfg_pix_w          <= cfg_pix_w          ;
    end


    logic   [IMGW_W-1:0]    in_xpos;
    logic   [IMGH_W-1:0]    in_ypos;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        in_xpos <= '0;
        in_ypos <= '0;
    end else if (in_sof) begin
        in_xpos <= '0;
        in_ypos <= '0;
    end else if(in_vld && in_rdy) begin
        if(in_xpos >= (lock_cfg_img_width - PIX_NUM)) begin
            in_xpos <= '0;
            if(in_ypos == (lock_cfg_img_height - 1'b1))
                in_ypos <= '0;
            else
                in_ypos <= in_ypos + 1;
        end else begin
            in_xpos <= in_xpos + PIX_NUM;
        end
    end

    wire    start = in_vld && in_rdy && (in_xpos == 'd0) && ((in_ypos >= lock_cfg_cut_ypos) && (in_ypos < (lock_cfg_cut_ypos + lock_cfg_cut_height)));

    logic   [IMGH_W-1:0]    start_cnt;
    always@(posedge clk or negedge rst_n)
    if(~rst_n)
        start_cnt <= '0;
    else if (cfg_en_p)
        start_cnt <= '0;
    else if(start) begin
        start_cnt <= start_cnt + 1'b1;
    end

    logic   pack_vld,pack_rdy,pack_eol;
    assign  pack_vld = ((in_xpos >= lock_cfg_cut_xpos) && (in_xpos < lock_cfg_cut_xpos + lock_cfg_cut_width)) && ((in_ypos >= lock_cfg_cut_ypos) && (in_ypos < lock_cfg_cut_ypos + lock_cfg_cut_height)) && in_vld;
    assign  pack_eol = (in_xpos - lock_cfg_cut_xpos + PIX_NUM) >= lock_cfg_cut_width;
    assign  in_rdy   = pack_vld ? pack_rdy : 1'b1;


    stl_img_bus_pack#(
        .PIX_W       (PIX_W    ),
        .PIX_NUM     (PIX_NUM  ),
        .BUS_W       (BUS_W    ),
        .WIN_W       (IMGW_W   )
    )U_pack(
        .clk         (clk        ),
        .rst_n       (rst_n      ),
        .cfg_pix_w   (cfg_pix_w  ),
        .cfg_en_p    (cfg_en_p   ),
        .clear       (1'b0       ),
        .mem_cfg     (mem_cfg    ),
        .in_sob      (in_sof     ),
        .in_vld      (pack_vld   ),
        .in_eol      (pack_eol   ),
        .in_rdy      (pack_rdy   ),
        .in_data     (in_data    ),
        .bus_vld     (bus_wd_vld ),
        .bus_rdy     (bus_wd_rdy ),
        .bus_data    (bus_wd_data)
    );

    always@(posedge clk or negedge rst_n) begin
    if(~rst_n)
        bus_wa_vld <= 1'b0;
    else if (start)
        bus_wa_vld <= 1'b1;
    else if (bus_wa_vld && bus_wa_rdy) 
        bus_wa_vld <= 1'b0;
    end 

    assign  bus_wa_addr = lock_cfg_img_start_addr + (start_cnt-1)*lock_cfg_img_addr_stride;

    logic   [IMGH_W+IMGW_W+$clog2(PIX_W+1)-1:0] total_data;
    assign  total_data = lock_cfg_cut_width*lock_cfg_pix_w;
    assign  bus_wa_byte_len = total_data[IMGH_W+IMGW_W+$clog2(PIX_W+1)-1:3] + |total_data[0+:3];

    logic   [IMGH_W-1:0]    b_resp_cnt;
    always@(posedge clk or negedge rst_n)
    if(~rst_n)
        b_resp_cnt <= '0;
    else if(bus_wb_resp) begin
        if(b_resp_cnt == (lock_cfg_cut_height - 1'b1))
            b_resp_cnt <= '0;
        else
            b_resp_cnt <= b_resp_cnt + 1'b1;
    end
        
    assign      cut_wr_done = (b_resp_cnt == (lock_cfg_cut_height - 1'b1)) && bus_wb_resp;

endmodule
