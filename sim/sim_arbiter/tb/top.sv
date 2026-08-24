`timescale 1ns/1ps

module top;

localparam REQ_N = 4;
localparam REQ_N_L2 = $clog2(REQ_N);

logic clk;
logic rst_n;
logic clear;
logic [REQ_N-1:0] req_vld;
logic [REQ_N-1:0][3:0] cfg_weight;
logic gnt_rdy;
wire [REQ_N-1:0] rr_req_rdy;
wire [REQ_N-1:0] rr_gnt_onehot;
wire [REQ_N_L2-1:0] rr_gnt_idx;
wire rr_gnt_vld;
wire [REQ_N-1:0] wrr_req_rdy;
wire [REQ_N-1:0] wrr_gnt_onehot;
wire [REQ_N_L2-1:0] wrr_gnt_idx;
wire wrr_gnt_vld;
wire [REQ_N-1:0] iwrr_req_rdy;
wire [REQ_N-1:0] iwrr_gnt_onehot;
wire [REQ_N_L2-1:0] iwrr_gnt_idx;
wire iwrr_gnt_vld;

clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output clear;
    output req_vld;
    output cfg_weight;
    output gnt_rdy;
    input  rr_req_rdy;
    input  rr_gnt_onehot;
    input  rr_gnt_idx;
    input  rr_gnt_vld;
    input  wrr_req_rdy;
    input  wrr_gnt_onehot;
    input  wrr_gnt_idx;
    input  wrr_gnt_vld;
    input  iwrr_req_rdy;
    input  iwrr_gnt_onehot;
    input  iwrr_gnt_idx;
    input  iwrr_gnt_vld;
endclocking

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    clear = 1'b0;
    req_vld = '0;
    cfg_weight[0] = 4'd2;
    cfg_weight[1] = 4'd0;
    cfg_weight[2] = 4'd1;
    cfg_weight[3] = 4'd3;
    gnt_rdy = 1'b0;
    repeat(5) @(drv_cb);
    drv_cb.rst_n <= 1'b1;

    @(drv_cb);
    drv_cb.req_vld <= 4'b1010;
    repeat(3) @(drv_cb);
    if( drv_cb.rr_gnt_idx !== 2'd1 )
        $fatal(1, "rr lock mismatch before ready");
    drv_cb.gnt_rdy <= 1'b1;
    repeat(12) @(drv_cb);
    drv_cb.req_vld <= 4'b1111;
    repeat(24) @(drv_cb);
    drv_cb.req_vld <= '0;
    drv_cb.gnt_rdy <= 1'b0;
    repeat(5) @(drv_cb);
    $display("SIM_ARBITER PASS");
    $finish;
end

com_arbiter_rr #(
    .REQ_N ( REQ_N )
)u_com_arbiter_rr
(
    .clk          ( clk           ),
    .rst_n        ( rst_n         ),
    .clear        ( clear         ),
    .i_req_vld    ( req_vld       ),
    .o_req_rdy    ( rr_req_rdy    ),
    .o_gnt_onehot ( rr_gnt_onehot ),
    .o_gnt_idx    ( rr_gnt_idx    ),
    .o_gnt_vld    ( rr_gnt_vld    ),
    .i_gnt_rdy    ( gnt_rdy       )
);

com_arbiter_wrr #(
    .REQ_N ( REQ_N )
)u_com_arbiter_wrr
(
    .clk          ( clk            ),
    .rst_n        ( rst_n          ),
    .clear        ( clear          ),
    .i_cfg_weight ( cfg_weight     ),
    .i_req_vld    ( req_vld        ),
    .o_req_rdy    ( wrr_req_rdy    ),
    .o_gnt_onehot ( wrr_gnt_onehot ),
    .o_gnt_idx    ( wrr_gnt_idx    ),
    .o_gnt_vld    ( wrr_gnt_vld    ),
    .i_gnt_rdy    ( gnt_rdy        )
);

com_arbiter_iwrr #(
    .REQ_N ( REQ_N )
)u_com_arbiter_iwrr
(
    .clk          ( clk             ),
    .rst_n        ( rst_n           ),
    .clear        ( clear           ),
    .i_cfg_weight ( cfg_weight      ),
    .i_req_vld    ( req_vld         ),
    .o_req_rdy    ( iwrr_req_rdy    ),
    .o_gnt_onehot ( iwrr_gnt_onehot ),
    .o_gnt_idx    ( iwrr_gnt_idx    ),
    .o_gnt_vld    ( iwrr_gnt_vld    ),
    .i_gnt_rdy    ( gnt_rdy         )
);

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
