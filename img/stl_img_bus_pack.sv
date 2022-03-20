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
module stl_img_bus_pack#(
    parameter   PIX_W       = 12,
    parameter   PIX_NUM     = 2 ,
    parameter   BUS_W       = 128,
    parameter   WIN_W       = 10
)(
    //----------------------------------------------------------------------------//
    // global signal
    //----------------------------------------------------------------------------//
    input                                       clk          ,
    input                                       rst_n        ,
    `STL_MCFG_IF(0)                             mem_cfg      ,
    //----------------------------------------------------------------------------//
    // cfg signal
    //----------------------------------------------------------------------------//
    input                                       cfg_en_p     ,
    input                                       clear        ,
    input       [$clog2(PIX_W+1)-1:0]           cfg_pix_w    ,
    //----------------------------------------------------------------------------//
    // input data stream
    //----------------------------------------------------------------------------//    
    input                                       in_sob       ,
    input                                       in_vld       ,
    input                                       in_eol       ,
    output                                      in_rdy       ,
    input       [PIX_NUM-1:0][PIX_W-1:0]        in_data      ,
    //----------------------------------------------------------------------------//
    // bus signal
    //----------------------------------------------------------------------------//    
    output logic                                bus_vld      ,
    input                                       bus_rdy      ,
    output logic[BUS_W-1:0]                     bus_data     
);
    
    logic   [$clog2(PIX_W+1)-1:0]             cfg_pix_w_lock;
    always@(posedge clk or negedge rst_n)
    if(~rst_n)
        cfg_pix_w_lock <= '0;
    else if(clear)
        cfg_pix_w_lock <= '0;
    else if(cfg_en_p)
        cfg_pix_w_lock <= cfg_pix_w;


    logic   [PIX_NUM*PIX_W-1:0]    in_data_fnl;
    generate
        if(PIX_NUM == 1)
            assign  in_data_fnl = in_data;
        else if(PIX_NUM == 2)
            assign in_data_fnl = {in_data[1],in_data[0]<<(PIX_W-cfg_pix_w_lock)}>>(PIX_W-cfg_pix_w_lock);
        else if(PIX_NUM == 3)
            assign in_data_fnl = {in_data[2],{in_data[1],in_data[0]<<(PIX_W-cfg_pix_w_lock)}<<(PIX_W-cfg_pix_w_lock)}>>((PIX_W-cfg_pix_w_lock)*2);
        else if(PIX_NUM == 4)
            assign in_data_fnl = {in_data[3],{in_data[2],{in_data[1],in_data[0]<<(PIX_W-cfg_pix_w_lock)}<<(PIX_W-cfg_pix_w_lock)}<<(PIX_W-cfg_pix_w_lock)}>>((PIX_W-cfg_pix_w_lock)*3);
    endgenerate


    localparam      INST_NUM    =   BUS_W/(PIX_W*PIX_NUM) + 2;
    localparam      INST_NUM_W  =   $clog2(INST_NUM);

    logic   [$clog2(BUS_W+PIX_W)-1:0]  high_idx;
    logic   last_bus_op;
    logic   last_bus_op_dly;
    always@(posedge clk or negedge rst_n)
    if(~rst_n)
        last_bus_op_dly <= '0;
    else if(last_bus_op && bus_rdy)
        last_bus_op_dly <= 1'b1;
    else if (last_bus_op_dly && bus_rdy)
        last_bus_op_dly <= 1'b0;
        
    //----------------------------------------------------------------------------//
    // ram inst and ctrl signal
    //----------------------------------------------------------------------------//
    logic   wr,rd,empty,full;
    logic   [PIX_NUM*PIX_W-1:0] wdata,rdata;
    stl_syncfifo_lite#(
        .DATA_W     (PIX_W*PIX_NUM ),        //Data width of both din&dout
        .DEPTH      (INST_NUM),      //Memory depth of fifo
        .FIFO_TYPE  (1  ),           //Bit0: 0->STD, 1->FWFT. Bit1: Add output reg.
        .MEM_TYPE   (0  )
    )U_fifo(
        .clk       (clk    ),
        .rst_n     (rst_n  ),
        .mem_cfg   (mem_cfg),
        .wr_en     (wr     ),
        .wr_data   (wdata  ),
        .wr_full   (full   ),
        .rd_en     (rd     ),   
        .rd_data   (rdata  ),
        .rd_empty  (empty  )
    );

    logic   [WIN_W-1:0] in_data_cnt,out_data_cnt;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        in_data_cnt  <= '0;
        out_data_cnt <= '0;
    end else if(clear) begin
        in_data_cnt  <= '0;
        out_data_cnt <= '0;
    end else if(last_bus_op && bus_rdy) begin
        in_data_cnt  <= '0;
        out_data_cnt <= '0;
    end else begin
        if(wr) begin
            in_data_cnt <= in_data_cnt + PIX_NUM;
        end 
        if (rd) begin
            out_data_cnt <= out_data_cnt + PIX_NUM;
        end
    end

    logic   in_eol_dly;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        in_eol_dly <= '0;
    end else if(clear) begin
        in_eol_dly <= '0;
    end else if(last_bus_op && bus_rdy) begin
        in_eol_dly <= '0;
    end else if (in_vld && in_eol && in_rdy) begin
        in_eol_dly <= 1'b1;
    end

    //wr
    assign  wr    = in_vld && in_rdy;
    assign  wdata = in_data_fnl;
    //rd
    assign  rd    = ~empty && (high_idx < BUS_W + PIX_W*PIX_NUM) && bus_rdy;

    logic   [PIX_NUM*PIX_W-1:0] rdata_dly;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        rdata_dly <= '0;
    end else if(clear) begin
        rdata_dly <= '0;
    end else if (in_sob) begin
        rdata_dly <= '0;
    end else if(rd)
        rdata_dly <= rdata;

    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        high_idx <= '0;
    end else if(clear) begin
        high_idx <= '0;
    end else if(last_bus_op_dly && (|high_idx) && bus_rdy) begin
        high_idx <= '0;
    end else if(last_bus_op && bus_rdy) begin
        if(high_idx >= BUS_W)
            high_idx <= high_idx - BUS_W;
        else
            high_idx <= '0;
    end else if (rd) begin
        if((high_idx >= BUS_W) && bus_rdy)
            high_idx <= high_idx + cfg_pix_w_lock*PIX_NUM - BUS_W;
        else 
            high_idx <= high_idx + cfg_pix_w_lock*PIX_NUM;
    end else if(bus_vld && bus_rdy)
        high_idx <= high_idx - BUS_W;

    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        bus_data <= '0;
    end else if (rd || (bus_vld && bus_rdy)) begin
        if(high_idx >= BUS_W) begin
            bus_data <= {rdata,rdata_dly<<(PIX_W-cfg_pix_w_lock)*PIX_NUM}>>( BUS_W + PIX_W*PIX_NUM - high_idx);
        end else begin
            bus_data <= {rdata,bus_data<<(BUS_W-high_idx)}>>(BUS_W-high_idx);
        end
    end

    assign  last_bus_op = (in_data_cnt == out_data_cnt && in_eol_dly);

    assign  bus_vld = (high_idx >= BUS_W) || last_bus_op || (last_bus_op_dly && (|high_idx));

    logic   in_last_to_bus_last;
    always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        in_last_to_bus_last <= '0;
    end else if(clear) begin
        in_last_to_bus_last <= '0;
    end else if(last_bus_op_dly && (|high_idx) && bus_rdy) begin
        in_last_to_bus_last <= '0;
    end else if(last_bus_op && bus_rdy && (high_idx <= BUS_W)) begin
        in_last_to_bus_last <= '0;
    end else if (in_vld && in_eol && in_rdy) begin
        in_last_to_bus_last <= 1'b1;
    end

    assign  in_rdy = in_last_to_bus_last ? 1'b0 : ~full;

endmodule
