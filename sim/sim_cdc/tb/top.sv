`timescale 1ns/1ps

module top;

logic wr_clk;
logic rd_clk;
logic wr_rst_n;
logic rd_rst_n;

logic src_req_pulse;
wire  src_ack_pulse;
wire  src_busy_level;
wire  dst_req_pulse;
wire  rstn_o_dst_rst_n;
wire  pair_o_src_rst_n;
wire  pair_o_dst_rst_n;

clocking ckwr_drv_cb @(posedge wr_clk);
    default input #1step output #0;
    output wr_rst_n;
    output src_req_pulse;
    input  src_ack_pulse;
    input  src_busy_level;
    input  pair_o_src_rst_n;
endclocking

clocking ckrd_drv_cb @(posedge rd_clk);
    default input #1step output #0;
    output rd_rst_n;
    input  dst_req_pulse;
    input  rstn_o_dst_rst_n;
    input  pair_o_dst_rst_n;
endclocking

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
    src_req_pulse = 1'b0;
    repeat(5) @(ckwr_drv_cb);
    ckwr_drv_cb.wr_rst_n <= 1'b1;
    repeat(3) @(ckrd_drv_cb);
    ckrd_drv_cb.rd_rst_n <= 1'b1;

    @(ckwr_drv_cb);
    ckwr_drv_cb.src_req_pulse <= !ckwr_drv_cb.src_busy_level;
    @(ckwr_drv_cb);
    ckwr_drv_cb.src_req_pulse <= 1'b0;
    do @(ckwr_drv_cb); while( !ckwr_drv_cb.src_ack_pulse );

    repeat(20) @(ckwr_drv_cb);
    $display("SIM_CDC PASS");
    $finish;
end

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

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
