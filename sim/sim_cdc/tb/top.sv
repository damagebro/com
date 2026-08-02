`timescale 1ns/1ps

module top;

localparam DW = 8;
localparam DEPTH = 5;
localparam CW = $clog2(DEPTH+1);

logic wr_clk;
logic rd_clk;
logic wr_rst_n;
logic rd_rst_n;
logic i_wr_en;
logic [DW-1:0] i_wr_data;
wire  af_o_wr_full;
logic i_rd_en;
wire  [DW-1:0] af_o_rd_data;
wire  af_o_rd_empty;
wire  [CW-1:0] af_o_water_level;
wire  ex_o_wr_full;
wire  [DW-1:0] ex_o_rd_data;
wire  ex_o_rd_empty;
wire  [CW-1:0] ex_o_water_level;

logic src_req_pulse;
wire  src_ack_pulse;
wire  src_busy_level;
wire  dst_req_pulse;
wire  rstn_o_dst_rst_n;
wire  pair_o_src_rst_n;
wire  pair_o_dst_rst_n;

initial begin
    wr_clk = 1'b0;
    forever #4 wr_clk = ~wr_clk;
end

initial begin
    rd_clk = 1'b0;
    forever #7 rd_clk = ~rd_clk;
end

initial begin
    wr_rst_n = 1'b0;
    rd_rst_n = 1'b0;
    i_wr_en = 1'b0;
    i_wr_data = '0;
    i_rd_en = 1'b0;
    src_req_pulse = 1'b0;
    repeat(5) @(posedge wr_clk);
    wr_rst_n = 1'b1;
    repeat(3) @(posedge rd_clk);
    rd_rst_n = 1'b1;

    repeat(2) @(posedge wr_clk);
    for( int i=0; i<12; i++ ) begin
        @(posedge wr_clk);
        i_wr_en <= !af_o_wr_full;
        i_wr_data <= i[DW-1:0];
    end
    @(posedge wr_clk);
    i_wr_en <= 1'b0;

    repeat(5) @(posedge rd_clk);
    for( int i=0; i<12; i++ ) begin
        @(posedge rd_clk);
        i_rd_en <= !af_o_rd_empty;
    end
    @(posedge rd_clk);
    i_rd_en <= 1'b0;

    @(posedge wr_clk);
    src_req_pulse <= !src_busy_level;
    @(posedge wr_clk);
    src_req_pulse <= 1'b0;
    wait(src_ack_pulse);

    repeat(20) @(posedge wr_clk);
    $display("SIM_CDC PASS");
    $finish;
end

com_async_fifo_reg #(
    .DW    ( DW    ),
    .DEPTH ( DEPTH ),
    .SYNC_S( 2     )
)u_com_async_fifo_reg
(
    .wr_clk        ( wr_clk           ),
    .wr_rst_n      ( wr_rst_n         ),
    .rd_clk        ( rd_clk           ),
    .rd_rst_n      ( rd_rst_n         ),
    .i_wr_en       ( i_wr_en          ),
    .i_wr_data     ( i_wr_data        ),
    .o_wr_full     ( af_o_wr_full     ),
    .i_rd_en       ( i_rd_en          ),
    .o_rd_data     ( af_o_rd_data     ),
    .o_rd_empty    ( af_o_rd_empty    ),
    .o_water_level ( af_o_water_level )
);

com_async_fifo_reg_exactwl #(
    .DW    ( DW    ),
    .DEPTH ( DEPTH ),
    .SYNC_S( 2     )
)u_com_async_fifo_reg_exactwl
(
    .wr_clk        ( wr_clk           ),
    .wr_rst_n      ( wr_rst_n         ),
    .rd_clk        ( rd_clk           ),
    .rd_rst_n      ( rd_rst_n         ),
    .i_wr_en       ( i_wr_en          ),
    .i_wr_data     ( i_wr_data        ),
    .o_wr_full     ( ex_o_wr_full     ),
    .i_rd_en       ( i_rd_en          ),
    .o_rd_data     ( ex_o_rd_data     ),
    .o_rd_empty    ( ex_o_rd_empty    ),
    .o_water_level ( ex_o_water_level )
);

com_cdc_handshake #(
    .SYNC_S ( 2 )
)u_com_cdc_handshake
(
    .i_src_clk        ( wr_clk          ),
    .i_src_rst_n      ( wr_rst_n        ),
    .i_dst_clk        ( rd_clk          ),
    .i_dst_rst_n      ( rd_rst_n        ),
    .i_src_req_pulse  ( src_req_pulse   ),
    .o_src_ack_pulse  ( src_ack_pulse   ),
    .o_src_busy_level ( src_busy_level  ),
    .o_dst_req_pulse  ( dst_req_pulse   )
);

com_cdc_rstn #(
    .SYNC_S ( 2 )
)u_com_cdc_rstn
(
    .i_dst_clk     ( rd_clk          ),
    .i_async_rst_n ( wr_rst_n        ),
    .o_dst_rst_n   ( rstn_o_dst_rst_n )
);

com_cdc_rstn_pair #(
    .SYNC_S ( 2 )
)u_com_cdc_rstn_pair
(
    .i_rx_src_clk   ( wr_clk          ),
    .i_rx_src_rst_n ( wr_rst_n        ),
    .i_rx_dst_clk   ( rd_clk          ),
    .i_rx_dst_rst_n ( rd_rst_n        ),
    .o_tx_src_rst_n ( pair_o_src_rst_n ),
    .o_tx_dst_rst_n ( pair_o_dst_rst_n )
);

endmodule
