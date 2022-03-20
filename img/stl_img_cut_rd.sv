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
module stl_img_cut_rd#(
    parameter   IMGW_W    = 10,
    parameter   IMGH_W    = 10,
    parameter   PIX_W     = 16,
    parameter   PIX_NUM   = 2 ,
    parameter   BUS_W     = 32,
    parameter   ADDR_W    = 32,
    parameter   LEN_W     = 32
)(
    //----------------------------------------------------------------------------//
    // global signal
    //----------------------------------------------------------------------------//
    input                               clk               ,
    input                               rst_n             ,
    //----------------------------------------------------------------------------//
    // cfg signal
    //----------------------------------------------------------------------------//
    input       [IMGW_W-1:0]            cfg_img_width     ,
    input       [IMGH_W-1:0]            cfg_img_height    ,
    input       [ADDR_W-1:0]            cfg_img_start_addr,
    input       [$clog2(PIX_W+1)-1:0]   cfg_pix_w         ,
    input       [ADDR_W-1:0]            cfg_line_stride   ,
    input                               cfg_en_p          ,

    input       [IMGW_W-1:0]            cfg_cut_xpos      ,
    input       [IMGH_W-1:0]            cfg_cut_ypos      ,
    input       [IMGW_W-1:0]            cfg_cut_width     ,
    input       [IMGH_W-1:0]            cfg_cut_height    ,
    input                               cfg_vld           ,
    output logic                        cfg_rdy           ,
    //----------------------------------------------------------------------------//
    // EMI signal
    //----------------------------------------------------------------------------//
    output logic                        bus_ra_vld        ,
    input                               bus_ra_rdy        ,
    output logic[ADDR_W-1:0]            bus_ra_addr       ,
    output logic[LEN_W-1:0]             bus_ra_byte_len   ,
    input                               bus_rd_vld        ,
    output                              bus_rd_rdy        ,
    input       [BUS_W-1:0]             bus_rd_data       ,
    //----------------------------------------------------------------------------//
    // input data stream
    //----------------------------------------------------------------------------//
    output logic                        out_sob           ,
    output logic                        out_vld           ,
    output logic[PIX_NUM-1:0][PIX_W-1:0]out_data          ,
    output logic                        out_sol           ,
    output logic                        out_eol           ,
    output logic                        out_eob           ,
    input                               out_rdy
);

    
    logic       [IMGW_W-1:0]            lock_cfg_img_width     ;
    logic       [IMGH_W-1:0]            lock_cfg_img_height    ;
    logic       [ADDR_W-1:0]            lock_cfg_img_start_addr;
    logic       [$clog2(PIX_W+1)-1:0]   lock_cfg_pix_w         ;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        lock_cfg_img_width      <= '0;
        lock_cfg_img_height     <= '0;
        lock_cfg_img_start_addr <= '0;
        lock_cfg_pix_w          <= '0;
    end else if (cfg_en_p) begin
        lock_cfg_img_width      <= cfg_img_width     ;
        lock_cfg_img_height     <= cfg_img_height    ;
        lock_cfg_img_start_addr <= cfg_img_start_addr;
        lock_cfg_pix_w          <= cfg_pix_w         ;
    end

    wire    cmd_hs = cfg_vld && cfg_rdy;
    logic   [IMGW_W-1:0]            lock_cfg_cut_xpos      ;
    logic   [IMGH_W-1:0]            lock_cfg_cut_ypos      ;
    logic   [IMGW_W-1:0]            lock_cfg_cut_width     ;
    logic   [IMGH_W-1:0]            lock_cfg_cut_height    ;
    logic   [ADDR_W-1:0]            lock_cfg_line_stride   ;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        lock_cfg_cut_xpos    <= '0;
        lock_cfg_cut_ypos    <= '0;
        lock_cfg_cut_width   <= '0;
        lock_cfg_cut_height  <= '0;
        lock_cfg_line_stride <= '0;
    end else if (cmd_hs) begin
        lock_cfg_cut_xpos    <= cfg_cut_xpos   ;
        lock_cfg_cut_ypos    <= cfg_cut_ypos   ;
        lock_cfg_cut_width   <= cfg_cut_width  ;
        lock_cfg_cut_height  <= cfg_cut_height ;
        lock_cfg_line_stride <= cfg_line_stride;

    end


    wire    [$clog2(PIX_W+1)+IMGW_W-1:0]  start_bit = lock_cfg_pix_w*lock_cfg_cut_xpos;
    wire    [ADDR_W-1:0]  init_addr = lock_cfg_img_start_addr + (start_bit>>3);

    logic   [IMGW_W-1:0]    out_xpos;
    logic   [IMGH_W-1:0]    out_ypos;
    logic                   out_eob_pre;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        out_xpos <= '0;
        out_ypos <= '0;
        bus_ra_addr <= '0;
        out_eob_pre <= '0;
    end else if (cmd_hs || out_sob) begin
        out_xpos <= '0;
        out_ypos <= '0;
        bus_ra_addr <= ((lock_cfg_pix_w*cfg_cut_xpos)>>3) + lock_cfg_img_start_addr + lock_cfg_line_stride*cfg_cut_ypos;
        out_eob_pre <= '0;
    end else if(out_vld && out_rdy) begin
        if(out_xpos*PIX_NUM + PIX_NUM >= lock_cfg_cut_width) begin
            out_xpos <= '0;
            if(out_ypos == (lock_cfg_cut_height - 1'b1)) begin
                out_ypos <= '0;
                out_eob_pre <= 1'b1;
            end else begin
                out_ypos    <= out_ypos + 1'b1;
                bus_ra_addr <= init_addr + lock_cfg_line_stride*(out_ypos+1);
            end
        end else 
            out_xpos <= out_xpos + 1'b1;
    end else
        out_eob_pre <= 1'b0;

    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        bus_ra_vld <= '0;
    end else if (cmd_hs) begin
        bus_ra_vld <= 1'b1;
    end else if(out_eol && (out_ypos < (lock_cfg_cut_height - 1'b1)))
        bus_ra_vld <= 1'b1;
    else if(bus_ra_vld && bus_ra_rdy)
        bus_ra_vld <= 1'b0;

    wire [$clog2(PIX_W+1)+IMGW_W-1:0]  total_bit;
    assign total_bit = lock_cfg_pix_w*lock_cfg_cut_width;
    //assign  [$clog2(PIX_W+1)+IMGW_W-1:0]  total_bit = cfg_pix_w*cfg_cut_width;
    assign  bus_ra_byte_len = total_bit[$clog2(PIX_W+1)+IMGW_W-1:3] + |total_bit[0+:3];

    stl_img_bus_unpack#(
        .BUS_W       (BUS_W    ),
        .PIX_W       (PIX_W    ),
        .PIX_NUM     (PIX_NUM  ),
        .WIN_W       (IMGW_W   ),
        .WIN_H       (IMGH_W   )
    )U_unpack(
        .clk         (clk          ),
        .rst_n       (rst_n        ),
        .clear       (clear        ),
        .cfg_en_p    (cmd_hs       ),
        .win_width   (cfg_cut_width),
        .win_height  (cfg_cut_height),
        .win_xpos    (cfg_cut_xpos ),
        .cfg_pix_w   (cfg_pix_w    ),
        .out_vld     (out_vld      ),
        .out_first   (out_sol      ),
        .out_last    (out_eol      ),
        .out_rdy     (out_rdy      ),
        .out_data    (out_data     ),
        .bus_vld     (bus_rd_vld   ),
        .bus_rdy     (bus_rd_rdy   ),
        .bus_data    (bus_rd_data  )
    );

    assign  out_sob = cmd_hs;

    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        out_eob <= '0;
    end else if (out_eob_pre != out_eob) begin
        out_eob <= out_eob_pre;
    end


    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        cfg_rdy <= 1'b1;
    end else if (cmd_hs) begin
        cfg_rdy <= 1'b0;
    end else if (out_eob)
        cfg_rdy <= 1'b1;


endmodule
