/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/21
*
*  Description:
*  - Asynchronous FIFO with exact logical water level semantics.
*  - Fetch pointer loads out_dff, read pointer advances on external read.
*  - Write domain uses synchronized read pointer for full and water level.
*
******************************************************************************/

module com_async_fifo_reg_exactwl #( parameter
    DW     = 8,
    DEPTH  = 4, //range=[1::]
    SYNC_S = 3, //freq>1.5G ? 4 : freq>1G ? 3 : 2
    localparam CW = $clog2(DEPTH+1)
)
(
input  wire                     wr_clk              ,
input  wire                     wr_rst_n            ,
input  wire                     rd_clk              ,
input  wire                     rd_rst_n            ,

input  wire                     i_wr_en             ,
input  wire [DW-1:0]            i_wr_data           ,
output wire                     o_wr_full           ,
input  wire                     i_rd_en             ,
output wire [DW-1:0]            o_rd_data           ,
output wire                     o_rd_empty          ,
output wire [CW-1:0]            o_water_level       //,
);
//localparam-----------------------------------------------------------------
localparam AW = $clog2((DEPTH>2?DEPTH:2));
localparam            PTR_NUM    = 1 << (AW+1);
localparam [AW-0:0]   PTR_LOW_E  = DEPTH - 1'b1;
localparam [AW-0:0]   PTR_HIGH_S = PTR_NUM - DEPTH;
localparam [AW-0:0]   DEPTH_PTR  = DEPTH;
//signal declare-------------------------------------------------------------
reg  [DEPTH-1:0][DW-1:0] r_ckwr_arr_mem;
reg  [AW-0:0]            r_ckwr_wr_ptr;
reg  [AW-0:0]            r_ckwr_wr_ptr_gray;
reg  [AW-0:0]            r_ckrd_fetch_ptr;
reg  [AW-0:0]            r_ckrd_rd_ptr;
reg  [AW-0:0]            r_ckrd_rd_ptr_gray;
reg                      r_ckrd_out_vld;
reg  [DW-1:0]            r_ckrd_out_data;

wire                     ckwr_wr_hs;
wire                     ckwr_wr_full;
wire [AW-0:0]            ckwr_wr_ptr_nxt;
wire [AW-0:0]            ckwr_wr_ptr_gray_nxt;
wire [AW-0:0]            ckwr_rd_ptr_bin;
wire                     ckwr_ptr_wrap_equ;
wire [AW-0:0]            ckwr_used_cnt_equ;
wire [AW-0:0]            ckwr_used_cnt_neq;
wire [AW-0:0]            ckwr_used_cnt;
wire [AW-0:0]            ckwr_water_level;
wire [AW-1:0]            ckwr_wr_addr;
wire [AW-1:0]            ckwr_rd_addr;
wire                     ckrd_rd_hs;
wire                     ckrd_mem_rd_en;
wire                     ckrd_mem_empty;
wire [AW-0:0]            ckrd_fetch_ptr_nxt;
wire [AW-0:0]            ckrd_rd_ptr_nxt;
wire [AW-0:0]            ckrd_rd_ptr_gray_nxt;
wire [AW-0:0]            ckrd_wr_ptr_bin;
wire [AW-1:0]            ckrd_fetch_addr;
wire [DW-1:0]            ckrd_mem_rd_data;

//instance signal--
wire [AW-0:0]            u_ckwr_rdptr_sync_i_src_data;
wire [AW-0:0]            u_ckwr_rdptr_sync_o_dst_data;
wire [AW-0:0]            u_ckrd_wrptr_sync_i_src_data;
wire [AW-0:0]            u_ckrd_wrptr_sync_o_dst_data;
//statement------------------------------------------------------------------
//output assign---
assign o_wr_full = ckwr_wr_full;
assign o_rd_data = r_ckrd_out_data;
assign o_rd_empty = !r_ckrd_out_vld;
assign o_water_level = ckwr_water_level[CW-1:0];

//body---
assign ckwr_wr_hs = i_wr_en && !o_wr_full;
assign ckwr_wr_ptr_nxt = F_ptr_next(r_ckwr_wr_ptr);
assign ckwr_wr_ptr_gray_nxt = F_bin2gray(ckwr_wr_ptr_nxt);
assign ckwr_rd_ptr_bin = F_gray2bin(u_ckwr_rdptr_sync_o_dst_data);
assign ckwr_wr_addr = F_ptr2addr(r_ckwr_wr_ptr);
assign ckwr_rd_addr = F_ptr2addr(ckwr_rd_ptr_bin);
assign ckwr_ptr_wrap_equ = r_ckwr_wr_ptr[AW]==ckwr_rd_ptr_bin[AW];
assign ckwr_used_cnt_equ = {1'b0,ckwr_wr_addr} - {1'b0,ckwr_rd_addr};
assign ckwr_used_cnt_neq = DEPTH_PTR + {1'b0,ckwr_wr_addr} - {1'b0,ckwr_rd_addr};
assign ckwr_used_cnt = ckwr_ptr_wrap_equ ? ckwr_used_cnt_equ : ckwr_used_cnt_neq;
assign ckwr_wr_full = ckwr_used_cnt==DEPTH_PTR;
assign ckwr_water_level = DEPTH_PTR - ckwr_used_cnt;

assign ckrd_rd_hs = i_rd_en && !o_rd_empty;
assign ckrd_mem_rd_en = !ckrd_mem_empty && (!r_ckrd_out_vld || ckrd_rd_hs);
assign ckrd_fetch_ptr_nxt = F_ptr_next(r_ckrd_fetch_ptr);
assign ckrd_rd_ptr_nxt = F_ptr_next(r_ckrd_rd_ptr);
assign ckrd_rd_ptr_gray_nxt = F_bin2gray(ckrd_rd_ptr_nxt);
assign ckrd_wr_ptr_bin = F_gray2bin(u_ckrd_wrptr_sync_o_dst_data);
assign ckrd_mem_empty = r_ckrd_fetch_ptr==ckrd_wr_ptr_bin;
assign ckrd_fetch_addr = F_ptr2addr(r_ckrd_fetch_ptr);
assign ckrd_mem_rd_data = r_ckwr_arr_mem[ckrd_fetch_addr];

//write memory
always @(posedge wr_clk) begin
    if( ckwr_wr_hs )
        r_ckwr_arr_mem[ckwr_wr_addr] <= i_wr_data;
end

//write pointer
always @(posedge wr_clk or negedge wr_rst_n) begin
    if( !wr_rst_n ) begin
        r_ckwr_wr_ptr <= '0;
        r_ckwr_wr_ptr_gray <= '0;
    end
    else if( ckwr_wr_hs ) begin
        r_ckwr_wr_ptr <= ckwr_wr_ptr_nxt;
        r_ckwr_wr_ptr_gray <= ckwr_wr_ptr_gray_nxt;
    end
end

//read fetch pointer
always @(posedge rd_clk or negedge rd_rst_n) begin
    if( !rd_rst_n )
        r_ckrd_fetch_ptr <= '0;
    else if( ckrd_mem_rd_en )
        r_ckrd_fetch_ptr <= ckrd_fetch_ptr_nxt;
end

//read pointer
always @(posedge rd_clk or negedge rd_rst_n) begin
    if( !rd_rst_n ) begin
        r_ckrd_rd_ptr <= '0;
        r_ckrd_rd_ptr_gray <= '0;
    end
    else if( ckrd_rd_hs ) begin
        r_ckrd_rd_ptr <= ckrd_rd_ptr_nxt;
        r_ckrd_rd_ptr_gray <= ckrd_rd_ptr_gray_nxt;
    end
end

//read output valid
always @(posedge rd_clk or negedge rd_rst_n) begin
    if( !rd_rst_n )
        r_ckrd_out_vld <= 1'b0;
    else if( ckrd_mem_rd_en )
        r_ckrd_out_vld <= 1'b1;
    else if( ckrd_rd_hs )
        r_ckrd_out_vld <= 1'b0;
end

//read output data
always @(posedge rd_clk) begin
    if( ckrd_mem_rd_en )
        r_ckrd_out_data <= ckrd_mem_rd_data;
end

//instance----
assign u_ckwr_rdptr_sync_i_src_data = r_ckrd_rd_ptr_gray;
com_cdc_sig #(
    .SYNC_S              ( SYNC_S                    ), //3
    .DATA_W              ( AW+1                      )  //3
)u_com_cdc_sig_ckwr_rdptr_sync
(
    .i_dst_clk           ( wr_clk                       ), //i
    .i_dst_rst_n         ( wr_rst_n                     ), //i
    .i_src_data          ( u_ckwr_rdptr_sync_i_src_data ), //i
    .o_dst_data          ( u_ckwr_rdptr_sync_o_dst_data )  //o
);

assign u_ckrd_wrptr_sync_i_src_data = r_ckwr_wr_ptr_gray;
com_cdc_sig #(
    .SYNC_S              ( SYNC_S                     ), //3
    .DATA_W              ( AW+1                       )  //3
)u_com_cdc_sig_ckrd_wrptr_sync
(
    .i_dst_clk           ( rd_clk                        ), //i
    .i_dst_rst_n         ( rd_rst_n                      ), //i
    .i_src_data          ( u_ckrd_wrptr_sync_i_src_data  ), //i
    .o_dst_data          ( u_ckrd_wrptr_sync_o_dst_data  )  //o
);

//function------------------------------------------------------------------
function [AW-0:0] F_ptr_next;
input [AW-0:0] ptr;
begin
    if( ptr==PTR_LOW_E )
        F_ptr_next = PTR_HIGH_S;
    else
        F_ptr_next = ptr + 1'b1;
end
endfunction

function [AW-1:0] F_ptr2addr;
input [AW-0:0] ptr;
begin
    if( ptr[AW]==1'b0 )
        F_ptr2addr = ptr[AW-1:0];
    else
        F_ptr2addr = ptr[AW-1:0] - PTR_HIGH_S[AW-1:0];
end
endfunction

function [AW-0:0] F_bin2gray;
input [AW-0:0] bin;
begin
    F_bin2gray = bin ^ (bin >> 1);
end
endfunction

function [AW-0:0] F_gray2bin;
input [AW-0:0] gray;
reg   [AW-0:0] bin;
begin
    bin[AW] = gray[AW];
    for( int i=AW-1; i>=0; i-- )
        bin[i] = bin[i+1] ^ gray[i];

    F_gray2bin = bin;
end
endfunction

//assert--------------------------------------------------------------------
`COM_PARAM_ASSERT( DEPTH>=1, "fifo depth must larger than 0" )
`COM_SIGNAL_ASSERT( a0, wr_clk,wr_rst_n,i_wr_en,!o_wr_full , "async fifo write when full" )
`COM_SIGNAL_ASSERT( a1, rd_clk,rd_rst_n,i_rd_en,!o_rd_empty, "async fifo read when empty" )
`COM_SIGNAL_ASSERT( a2, wr_clk,wr_rst_n,$past(wr_rst_n)&&$past(ckwr_wr_hs),$onehot(r_ckwr_wr_ptr_gray^$past(r_ckwr_wr_ptr_gray)), "write gray pointer does not step one bit after handshake" )
`COM_SIGNAL_ASSERT( a3, rd_clk,rd_rst_n,$past(rd_rst_n)&&$past(ckrd_rd_hs),$onehot(r_ckrd_rd_ptr_gray^$past(r_ckrd_rd_ptr_gray)), "read gray pointer does not step one bit after handshake" )

endmodule //end of com_async_fifo_reg_exactwl
