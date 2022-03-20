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
module stl_img_bus_unpack#(
    parameter   BUS_W       = 32,
    parameter   PIX_W       = 12,
    parameter   PIX_NUM     = 2 ,
    parameter   WIN_W       = 10,
    parameter   WIN_H       = 10
)(
    //----------------------------------------------------------------------------//
    // global signal
    //----------------------------------------------------------------------------//
    input                                clk     ,
    input                                rst_n   ,
    input                                clear   ,
    //----------------------------------------------------------------------------//
    // cfg signal
    //----------------------------------------------------------------------------//
    input                                cfg_en_p ,
    input        [WIN_W-1:0]             win_width,
    input        [WIN_H-1:0]             win_height,
    input        [WIN_W-1:0]             win_xpos,
    input        [$clog2(PIX_W+1)-1:0]   cfg_pix_w,
    //----------------------------------------------------------------------------//
    // output data stream
    //----------------------------------------------------------------------------//
    output  logic                        out_first,
    output  logic                        out_vld ,
    input                                out_rdy ,
    output  logic[PIX_NUM-1:0][PIX_W-1:0]out_data,
    output  logic                        out_last,
    //----------------------------------------------------------------------------//
    // bus signal
    //----------------------------------------------------------------------------//
    input                                bus_vld ,
    output  logic                        bus_rdy ,
    input        [BUS_W-1:0]             bus_data
);

    logic   [$clog2(PIX_W+1)-1:0]   cfg_pix_w_lock;
    logic   [WIN_W-1:0]             win_width_lock;
    logic   [WIN_H-1:0]             win_height_lock;
    logic   [WIN_W-1:0]             win_xpos_lock ;

    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        cfg_pix_w_lock <= '0;
        win_width_lock <= '0;
        win_xpos_lock  <= '0;
        win_height_lock<= '0;
    end else if(clear) begin
        cfg_pix_w_lock <= '0;
        win_width_lock <= '0;
        win_xpos_lock  <= '0;
        win_height_lock<= '0;
    end else if(cfg_en_p) begin
        cfg_pix_w_lock <= cfg_pix_w;
        win_width_lock <= win_width;
        win_height_lock<= win_height;
        win_xpos_lock  <= win_xpos ;
    end

    wire    bus_op = bus_vld && bus_rdy;
    wire    out_op = out_vld && out_rdy;

    logic   [1:0]   bus_cnt;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        bus_cnt <= '0;
    end else if (clear || out_last) begin
        bus_cnt <= '0;
    end else if (bus_op) begin
        if(bus_cnt <= 'd1)
            bus_cnt <= bus_cnt + 1'b1;
    end

    logic   [$clog2(BUS_W+1):0]     start_idx;
    //wire    [WIN_W+$clog2(PIX_W+1)-1:0]     xpos_idx = (win_xpos_lock+1)*cfg_pix_w_lock;
    //assign start_idx = xpos_idx - (xpos_idx[WIN_W+$clog2(PIX_W+1)-1:$clog2(BUS_W)])*BUS_W - cfg_pix_w_lock;
    wire    [WIN_W+$clog2(PIX_W+1)-1:0]     xpos_idx = (win_xpos_lock)*cfg_pix_w_lock;
    assign start_idx = xpos_idx - (xpos_idx[WIN_W+$clog2(PIX_W+1)-1:$clog2(BUS_W)])*BUS_W;

    logic   [WIN_W+$clog2(PIX_W+1)-1:0]  win_bit_cnt;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        win_bit_cnt <= '0;
    end else if (clear || out_last) begin
        win_bit_cnt <= '0;
    end else if (bus_op) begin
        if(bus_cnt == 'd0)
            win_bit_cnt <= BUS_W - start_idx;
        else
            win_bit_cnt <= win_bit_cnt + BUS_W;
    end


    logic   [PIX_W-1:0] remain_cnt;


    logic               first_trans;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        first_trans <= 1'b1;
    end else if (clear) begin
        first_trans <= 1'b1;
    end else if (cfg_en_p) begin
        first_trans <= 1'b0;
    end else if(bus_op && ~first_trans)
        first_trans <= 1'b1;

    logic   cfg_en_p_dly;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        cfg_en_p_dly <= '0;
    end else if (cfg_en_p_dly != cfg_en_p) begin
        cfg_en_p_dly <= cfg_en_p;
    end

    logic   [$clog2(BUS_W*2+1)-1:0] idx;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        idx <= '0;
    end else if(clear) begin
        idx <= '0;
    end else if(cfg_en_p_dly || (out_op && out_last)) begin
        idx <= start_idx;
    end else begin
        idx <= idx + out_op*cfg_pix_w_lock*PIX_NUM - (bus_op && (bus_cnt>'d1))*BUS_W;
    end

    always@(posedge clk or negedge rst_n)
    if(!rst_n)
        remain_cnt <= '0;
    else if(clear || (out_last && out_op))
        remain_cnt <= '0;
    else
        remain_cnt <= remain_cnt + (bus_cnt == 'd0 && bus_op)*(BUS_W - start_idx) +
                                   (bus_cnt != 'd0 && bus_op)*(BUS_W) - 
                                   out_op*PIX_NUM*cfg_pix_w_lock;

    logic   [WIN_H:0] out_ypos;
    logic   [WIN_W:0] out_xpos;

    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        out_xpos <= '0;
        out_ypos <= '0;
    end else if(clear || cfg_en_p) begin
        out_xpos <= '0;
        out_ypos <= '0;
    end else if(out_op) begin
        if(out_last) begin
            out_xpos <= '0;
            if(out_ypos == win_height_lock - 1)
                out_ypos <= '0;
            else
                out_ypos <= out_ypos + 1'b1;
        end else
            out_xpos <= out_xpos + PIX_NUM;
    end


    logic   [BUS_W*2-1:0]   data_use;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        data_use <= '0;
    end else if(clear) begin
        data_use <= '0;
    end else if (bus_op) begin
        if(bus_cnt == 'd0)
            data_use <= {{BUS_W{1'b0}},bus_data};
        else if(bus_cnt == 'd1)
            data_use <= {bus_data,data_use[BUS_W-1:0]};
        else
            data_use <= {bus_data,data_use[BUS_W*2-1:BUS_W]};
    end

    logic   invld_time;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        invld_time <= '0;
    end else if (clear) begin
        invld_time <= '0;
    end else if (out_op && out_last && out_ypos == (win_height_lock - 1))
        invld_time <= 1'b1;
    else if (cfg_en_p)
        invld_time <= '0;


    assign  bus_rdy = (cfg_en_p || cfg_en_p_dly) ? 1'b0 : 
                      (~first_trans) ? 1'b1 : 
                      (invld_time)   ? 1'b0 : 
                      ( (remain_cnt <= BUS_W) || 
                        (out_op && (remain_cnt > BUS_W && remain_cnt - cfg_pix_w_lock*PIX_NUM <= BUS_W)) ) 
                      && ((win_bit_cnt) < cfg_pix_w_lock*win_width_lock) && (out_ypos < win_height_lock); 

    logic   [PIX_W*PIX_NUM-1:0] out_data_tmp;
    assign  out_data_tmp = data_use>>idx;
    genvar pix_idx;
    logic   [PIX_NUM-1:0][PIX_W-1:0] out_data_pre;
    generate
        for(pix_idx=0; pix_idx<PIX_NUM; pix_idx++) begin
            assign  out_data_pre[pix_idx] = out_data_tmp>>cfg_pix_w_lock*pix_idx;
            assign  out_data[pix_idx] = (out_data_pre[pix_idx]<<(PIX_W-cfg_pix_w_lock))>>(PIX_W-cfg_pix_w_lock);
        end
    endgenerate

    wire out_sol;
    wire out_eol;
    assign out_sol  = out_vld && (out_xpos == '0);
    assign out_eol  = out_vld && (out_xpos >= (win_width_lock - PIX_NUM));
    assign out_first = out_sol;
    assign out_last = out_eol;
    assign out_vld  = (remain_cnt >= cfg_pix_w_lock*PIX_NUM) && |remain_cnt;

endmodule
