`timescale 1ns/1ps

module csr_core_case
(
    output logic o_done
);

localparam REQ_N = 2;
localparam CSR_AW = 8;
localparam CSR_DW = 32;

logic src_clk;
logic src_rst_n;
logic dst_clk;
logic dst_rst_n;
logic clear;

logic [REQ_N-1:0]               m_req_write;
logic [REQ_N-1:0][CSR_AW-1:0]   m_req_addr;
logic [REQ_N-1:0][CSR_DW-1:0]   m_req_wdata;
logic [REQ_N-1:0][CSR_DW/8-1:0] m_req_wstrb;
logic [REQ_N-1:0]               m_req_valid;
wire  [REQ_N-1:0]               m_req_ready;
wire  [REQ_N-1:0][CSR_DW-1:0]   m_rsp_rdata;
wire  [REQ_N-1:0]               m_rsp_rvalid;

wire                 arb_req_write;
wire [CSR_AW-1:0]    arb_req_addr;
wire [CSR_DW-1:0]    arb_req_wdata;
wire [CSR_DW/8-1:0]  arb_req_wstrb;
wire                 arb_req_valid;
wire                 arb_req_ready;
wire [CSR_DW-1:0]    arb_rsp_rdata;
wire                 arb_rsp_rvalid;

wire                 to_req_write;
wire [CSR_AW-1:0]    to_req_addr;
wire [CSR_DW-1:0]    to_req_wdata;
wire [CSR_DW/8-1:0]  to_req_wstrb;
wire                 to_req_valid;
wire                 to_req_ready;
wire [CSR_DW-1:0]    to_rsp_rdata;
wire                 to_rsp_rvalid;
wire                 core_req_timeout;
wire                 core_rsp_timeout;

wire                 slice_req_write;
wire [CSR_AW-1:0]    slice_req_addr;
wire [CSR_DW-1:0]    slice_req_wdata;
wire [CSR_DW/8-1:0]  slice_req_wstrb;
wire                 slice_req_valid;
wire                 slice_req_ready;
wire [CSR_DW-1:0]    slice_rsp_rdata;
wire                 slice_rsp_rvalid;

wire                 dst_req_write;
wire [CSR_AW-1:0]    dst_req_addr;
wire [CSR_DW-1:0]    dst_req_wdata;
wire [CSR_DW/8-1:0]  dst_req_wstrb;
wire                 dst_req_valid;
wire                 dst_req_ready;
wire [CSR_DW-1:0]    dst_rsp_rdata;
wire                 dst_rsp_rvalid;

reg  [2:0]                 r_dst_rsp_vld_pipe;
reg  [2:0][CSR_DW-1:0]     r_dst_rsp_data_pipe;

logic                 mon_req_write;
logic [CSR_AW-1:0]    mon_req_addr;
logic [CSR_DW-1:0]    mon_req_wdata;
logic [CSR_DW/8-1:0]  mon_req_wstrb;
logic                 mon_req_valid;
logic                 mon_tx_ready;
logic [CSR_DW-1:0]    mon_tx_rdata;
logic                 mon_tx_rvalid;
wire                  mon_req_ready;
wire [CSR_DW-1:0]     mon_rsp_rdata;
wire                  mon_rsp_rvalid;
wire                  mon_tx_valid;
wire                  mon_req_timeout;
wire                  mon_rsp_timeout;

clocking src_cb @(posedge src_clk);
    default input #1step output #0;
    output src_rst_n;
    output clear;
    output m_req_write;
    output m_req_addr;
    output m_req_wdata;
    output m_req_wstrb;
    output m_req_valid;
    input  m_req_ready;
    input  m_rsp_rdata;
    input  m_rsp_rvalid;
endclocking

clocking dst_cb @(posedge dst_clk);
    default input #1step output #0;
    output dst_rst_n;
endclocking

initial begin
    src_clk = 1'b0;
    forever #5 src_clk = ~src_clk;
end

initial begin
    dst_clk = 1'b0;
    forever #7 dst_clk = ~dst_clk;
end

function automatic [CSR_DW-1:0] F_read_data;
input [CSR_AW-1:0] addr;
begin
    F_read_data = 32'hc500_0000 | addr;
end
endfunction

task automatic send_read_pair;
input [CSR_AW-1:0] addr0;
input [CSR_AW-1:0] addr1;
reg [REQ_N-1:0] pend;
begin
    @(src_cb);
    src_cb.m_req_write <= '0;
    src_cb.m_req_addr[0] <= addr0;
    src_cb.m_req_addr[1] <= addr1;
    src_cb.m_req_valid <= '1;
    pend = '1;
    while( |pend ) begin
        @(src_cb);
        for( int i=0; i<REQ_N; i=i+1 ) begin
            if( pend[i] && src_cb.m_req_ready[i] ) begin
                pend[i] = 1'b0;
                src_cb.m_req_valid[i] <= 1'b0;
            end
        end
    end
end
endtask

initial begin
    o_done = 1'b0;
    src_rst_n = 1'b0;
    dst_rst_n = 1'b0;
    clear = 1'b0;
    m_req_write = '0;
    m_req_addr = '0;
    m_req_wdata = '0;
    m_req_wstrb = '1;
    m_req_valid = '0;
    mon_req_write = 1'b0;
    mon_req_addr = '0;
    mon_req_wdata = '0;
    mon_req_wstrb = '1;
    mon_req_valid = 1'b0;
    mon_tx_ready = 1'b1;
    mon_tx_rdata = '0;
    mon_tx_rvalid = 1'b0;

    repeat(5) @(src_cb);
    src_cb.src_rst_n <= 1'b1;
    repeat(4) @(dst_cb);
    dst_cb.dst_rst_n <= 1'b1;

    fork
        begin: core_path_test
            int got0;
            int got1;
            got0 = 0;
            got1 = 0;
            fork
                begin
                    send_read_pair(8'h10,8'h20);
                    send_read_pair(8'h11,8'h21);
                end
                begin
                    while( got0<2 || got1<2 ) begin
                        @(src_cb);
                        if( src_cb.m_rsp_rvalid[0] ) begin
                            if( src_cb.m_rsp_rdata[0] !==
                                F_read_data(got0==0 ? 8'h10 : 8'h11) )
                                $fatal(1, "csr core master0 response mismatch");
                            got0 = got0 + 1;
                        end
                        if( src_cb.m_rsp_rvalid[1] ) begin
                            if( src_cb.m_rsp_rdata[1] !==
                                F_read_data(got1==0 ? 8'h20 : 8'h21) )
                                $fatal(1, "csr core master1 response mismatch");
                            got1 = got1 + 1;
                        end
                    end
                end
            join
            if( core_req_timeout || core_rsp_timeout )
                $fatal(1, "csr core unexpected timeout");
        end
        begin: timeout_test
            @(src_cb);
            mon_tx_ready = 1'b0;
            mon_req_valid = 1'b1;
            do @(src_cb); while( !mon_req_ready );
            if( !mon_req_timeout )
                $fatal(1, "csr request timeout pulse missing");
            if( !mon_rsp_rvalid || mon_rsp_rdata!='0 )
                $fatal(1, "csr request timeout response takeover missing");
            mon_req_valid = 1'b0;

            @(src_cb);
            mon_tx_ready = 1'b1;
            mon_req_valid = 1'b1;
            repeat(3) @(src_cb);
            mon_req_valid = 1'b0;

            // A real response restarts the timeout window for the next read.
            if( mon_rsp_timeout )
                $fatal(1, "csr response timeout was not restarted");
            mon_tx_rdata = 32'h1234_5678;
            mon_tx_rvalid = 1'b1;
            @(src_cb);
            if( !mon_rsp_rvalid || mon_rsp_rdata!=32'h1234_5678 )
                $fatal(1, "csr real response pass-through mismatch");
            mon_tx_rvalid = 1'b0;

            do @(src_cb); while( !mon_rsp_rvalid );
            if( !mon_rsp_timeout )
                $fatal(1, "csr response timeout pulse missing");
            if( mon_rsp_rdata!='0 )
                $fatal(1, "csr response timeout data must be zero");

            @(src_cb);
            if( !mon_rsp_rvalid || mon_rsp_rdata!='0 )
                $fatal(1, "csr timeout takeover did not drain all responses");

            // A late downstream response is ignored during timeout takeover.
            mon_tx_rdata = 32'hdead_beef;
            mon_tx_rvalid = 1'b1;
            @(src_cb);
            if( mon_rsp_rvalid )
                $fatal(1, "csr late response was not ignored");
            if( !u_com_csr_timeout_monitor.r_rsp_timeout_flag )
                $fatal(1, "csr response timeout flag was cleared without software clear");
            mon_tx_rvalid = 1'b0;

            // New requests are consumed without reaching downstream.
            mon_req_valid = 1'b1;
            @(src_cb);
            if( !mon_req_ready || mon_tx_valid )
                $fatal(1, "csr request was backpressured during timeout takeover");
            if( !mon_rsp_rvalid || mon_rsp_rdata!='0 )
                $fatal(1, "csr ignored read did not receive a timeout response");
            mon_req_valid = 1'b0;
        end
    join

    @(src_cb);
    src_cb.clear <= 1'b1;
    @(src_cb);
    src_cb.clear <= 1'b0;
    @(src_cb);
    if( u_com_csr_timeout_monitor.r_rsp_timeout_flag )
        $fatal(1, "csr response timeout flag was not cleared");

    repeat(5) @(src_cb);
    o_done = 1'b1;
end

assign dst_req_ready = 1'b1;
assign dst_rsp_rvalid = r_dst_rsp_vld_pipe[2];
assign dst_rsp_rdata = r_dst_rsp_data_pipe[2];

always @(posedge dst_clk or negedge dst_rst_n) begin
    if( !dst_rst_n )
        r_dst_rsp_vld_pipe <= '0;
    else begin
        r_dst_rsp_vld_pipe[0] <= dst_req_valid && dst_req_ready &&
                                 !dst_req_write;
        r_dst_rsp_vld_pipe[1] <= r_dst_rsp_vld_pipe[0];
        r_dst_rsp_vld_pipe[2] <= r_dst_rsp_vld_pipe[1];
    end
end

always @(posedge dst_clk) begin
    if( dst_req_valid && dst_req_ready && !dst_req_write )
        r_dst_rsp_data_pipe[0] <= F_read_data(dst_req_addr);
    r_dst_rsp_data_pipe[1] <= r_dst_rsp_data_pipe[0];
    r_dst_rsp_data_pipe[2] <= r_dst_rsp_data_pipe[1];
end

always @(posedge src_clk) begin
    if( src_rst_n && u_com_csr_arbiter.u_owner_o_wr_full ) begin
        for( int i=0; i<REQ_N; i=i+1 ) begin
            if( !m_req_write[i] && m_req_ready[i] )
                $fatal(1, "CSR arbiter accepted a read while owner FIFO was full");
        end
    end
end

com_csr_arbiter #(
    .REQ_N  (REQ_N ),
    .CSR_AW (CSR_AW),
    .CSR_DW (CSR_DW),
    .RD_OSD (2      )
)u_com_csr_arbiter
(
    .clk                 (src_clk       ),
    .rst_n               (src_rst_n     ),
    .clear               (clear         ),
    .i_rx_csr_req_write  (m_req_write   ),
    .i_rx_csr_req_addr   (m_req_addr    ),
    .i_rx_csr_req_wdata  (m_req_wdata   ),
    .i_rx_csr_req_wstrb  (m_req_wstrb   ),
    .i_rx_csr_req_valid  (m_req_valid   ),
    .o_rx_csr_req_ready  (m_req_ready   ),
    .o_rx_csr_rsp_rdata  (m_rsp_rdata   ),
    .o_rx_csr_rsp_rvalid (m_rsp_rvalid  ),
    .o_tx_csr_req_write  (arb_req_write ),
    .o_tx_csr_req_addr   (arb_req_addr  ),
    .o_tx_csr_req_wdata  (arb_req_wdata ),
    .o_tx_csr_req_wstrb  (arb_req_wstrb ),
    .o_tx_csr_req_valid  (arb_req_valid ),
    .i_tx_csr_req_ready  (arb_req_ready ),
    .i_tx_csr_rsp_rdata  (arb_rsp_rdata ),
    .i_tx_csr_rsp_rvalid (arb_rsp_rvalid)
);

com_csr_timeout #(
    .CSR_AW        (CSR_AW),
    .CSR_DW        (CSR_DW),
    .TIMEOUT_CYCLE (20     )
)u_com_csr_timeout_core
(
    .clk                   (src_clk          ),
    .rst_n                 (src_rst_n        ),
    .clear                 (clear            ),
    .i_rx_csr_req_write    (arb_req_write    ),
    .i_rx_csr_req_addr     (arb_req_addr     ),
    .i_rx_csr_req_wdata    (arb_req_wdata    ),
    .i_rx_csr_req_wstrb    (arb_req_wstrb    ),
    .i_rx_csr_req_valid    (arb_req_valid    ),
    .o_rx_csr_req_ready    (arb_req_ready    ),
    .o_rx_csr_rsp_rdata    (arb_rsp_rdata    ),
    .o_rx_csr_rsp_rvalid   (arb_rsp_rvalid   ),
    .o_tx_csr_req_write    (to_req_write     ),
    .o_tx_csr_req_addr     (to_req_addr      ),
    .o_tx_csr_req_wdata    (to_req_wdata     ),
    .o_tx_csr_req_wstrb    (to_req_wstrb     ),
    .o_tx_csr_req_valid    (to_req_valid     ),
    .i_tx_csr_req_ready    (to_req_ready     ),
    .i_tx_csr_rsp_rdata    (to_rsp_rdata     ),
    .i_tx_csr_rsp_rvalid   (to_rsp_rvalid    ),
    .o_pls_err_req_timeout (core_req_timeout ),
    .o_pls_err_rsp_timeout (core_rsp_timeout )
);

com_csr_cdc #(
    .CSR_AW    (CSR_AW),
    .CSR_DW    (CSR_DW),
    .REQ_DEPTH (4     ),
    .RD_OSD    (4     ),
    .SYNC_S    (2     )
)u_com_csr_cdc
(
    .src_clk                 (src_clk          ),
    .src_rst_n               (src_rst_n        ),
    .dst_clk                 (dst_clk          ),
    .dst_rst_n               (dst_rst_n        ),
    .i_src_csr_req_write     (slice_req_write  ),
    .i_src_csr_req_addr      (slice_req_addr   ),
    .i_src_csr_req_wdata     (slice_req_wdata  ),
    .i_src_csr_req_wstrb     (slice_req_wstrb  ),
    .i_src_csr_req_valid     (slice_req_valid  ),
    .o_src_csr_req_ready     (slice_req_ready  ),
    .o_src_csr_rsp_rdata     (slice_rsp_rdata  ),
    .o_src_csr_rsp_rvalid    (slice_rsp_rvalid ),
    .o_dst_csr_req_write     (dst_req_write    ),
    .o_dst_csr_req_addr      (dst_req_addr     ),
    .o_dst_csr_req_wdata     (dst_req_wdata    ),
    .o_dst_csr_req_wstrb     (dst_req_wstrb    ),
    .o_dst_csr_req_valid     (dst_req_valid    ),
    .i_dst_csr_req_ready     (dst_req_ready    ),
    .i_dst_csr_rsp_rdata     (dst_rsp_rdata    ),
    .i_dst_csr_rsp_rvalid    (dst_rsp_rvalid   )
);

com_csr_regslice #(
    .CSR_AW    (CSR_AW),
    .CSR_DW    (CSR_DW),
    .REQ_DEPTH (4     ),
    .RSP_DEPTH (4     )
)u_com_csr_regslice
(
    .clk                 (src_clk          ),
    .rst_n               (src_rst_n        ),
    .clear               (clear            ),
    .i_rx_csr_req_write  (to_req_write     ),
    .i_rx_csr_req_addr   (to_req_addr      ),
    .i_rx_csr_req_wdata  (to_req_wdata     ),
    .i_rx_csr_req_wstrb  (to_req_wstrb     ),
    .i_rx_csr_req_valid  (to_req_valid     ),
    .o_rx_csr_req_ready  (to_req_ready     ),
    .o_rx_csr_rsp_rdata  (to_rsp_rdata     ),
    .o_rx_csr_rsp_rvalid (to_rsp_rvalid    ),
    .o_tx_csr_req_write  (slice_req_write  ),
    .o_tx_csr_req_addr   (slice_req_addr   ),
    .o_tx_csr_req_wdata  (slice_req_wdata  ),
    .o_tx_csr_req_wstrb  (slice_req_wstrb  ),
    .o_tx_csr_req_valid  (slice_req_valid  ),
    .i_tx_csr_req_ready  (slice_req_ready  ),
    .i_tx_csr_rsp_rdata  (slice_rsp_rdata  ),
    .i_tx_csr_rsp_rvalid (slice_rsp_rvalid )
);

com_csr_timeout #(
    .CSR_AW        (CSR_AW),
    .CSR_DW        (CSR_DW),
    .TIMEOUT_CYCLE (4      )
)u_com_csr_timeout_monitor
(
    .clk                   (src_clk         ),
    .rst_n                 (src_rst_n       ),
    .clear                 (clear           ),
    .i_rx_csr_req_write    (mon_req_write   ),
    .i_rx_csr_req_addr     (mon_req_addr    ),
    .i_rx_csr_req_wdata    (mon_req_wdata   ),
    .i_rx_csr_req_wstrb    (mon_req_wstrb   ),
    .i_rx_csr_req_valid    (mon_req_valid   ),
    .o_rx_csr_req_ready    (mon_req_ready   ),
    .o_rx_csr_rsp_rdata    (mon_rsp_rdata   ),
    .o_rx_csr_rsp_rvalid   (mon_rsp_rvalid  ),
    .o_tx_csr_req_write    (                ),
    .o_tx_csr_req_addr     (                ),
    .o_tx_csr_req_wdata    (                ),
    .o_tx_csr_req_wstrb    (                ),
    .o_tx_csr_req_valid    (mon_tx_valid    ),
    .i_tx_csr_req_ready    (mon_tx_ready    ),
    .i_tx_csr_rsp_rdata    (mon_tx_rdata    ),
    .i_tx_csr_rsp_rvalid   (mon_tx_rvalid   ),
    .o_pls_err_req_timeout (mon_req_timeout ),
    .o_pls_err_rsp_timeout (mon_rsp_timeout )
);

endmodule
