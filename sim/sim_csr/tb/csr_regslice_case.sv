`timescale 1ns/1ps

module csr_regslice_case
(
    output logic o_done
);

localparam CSR_AW = 8;
localparam CSR_DW = 32;
localparam WRITE_NUM = 10;
localparam READ_NUM = 10;
localparam REQ_NUM = WRITE_NUM+READ_NUM;

logic clk;
logic rst_n;
logic clear;
logic rx_req_write;
logic [CSR_AW-1:0] rx_req_addr;
logic [CSR_DW-1:0] rx_req_wdata;
logic [CSR_DW/8-1:0] rx_req_wstrb;
logic rx_req_valid;
wire  rx_req_ready;
wire  [CSR_DW-1:0] rx_rsp_rdata;
wire  rx_rsp_rvalid;
wire  tx_req_write;
wire  [CSR_AW-1:0] tx_req_addr;
wire  [CSR_DW-1:0] tx_req_wdata;
wire  [CSR_DW/8-1:0] tx_req_wstrb;
wire  tx_req_valid;
logic tx_req_ready;
logic [CSR_DW-1:0] tx_rsp_rdata;
logic tx_rsp_rvalid;

clocking cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output clear;
    output rx_req_write;
    output rx_req_addr;
    output rx_req_wdata;
    output rx_req_wstrb;
    output rx_req_valid;
    output tx_req_ready;
    output tx_rsp_rdata;
    output tx_rsp_rvalid;
    input  rx_req_ready;
    input  rx_rsp_rdata;
    input  rx_rsp_rvalid;
    input  tx_req_write;
    input  tx_req_addr;
    input  tx_req_wdata;
    input  tx_req_wstrb;
    input  tx_req_valid;
endclocking

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

function automatic [CSR_DW-1:0] F_rsp_data;
input integer idx;
begin
    F_rsp_data = 32'h5a00_0000 | CSR_DW'(idx);
end
endfunction

initial begin
    o_done = 1'b0;
    rst_n = 1'b0;
    clear = 1'b0;
    rx_req_write = 1'b0;
    rx_req_addr = '0;
    rx_req_wdata = '0;
    rx_req_wstrb = '1;
    rx_req_valid = 1'b0;
    tx_req_ready = 1'b0;
    tx_rsp_rdata = '0;
    tx_rsp_rvalid = 1'b0;

    repeat(5) @(cb);
    cb.rst_n <= 1'b1;
    repeat(2) @(cb);

    // Stream 10 writes followed by 10 reads through a depth-2 request FIFO.
    cb.tx_req_ready <= 1'b1;
    fork
        begin
            cb.rx_req_valid <= 1'b1;
            cb.rx_req_write <= 1'b1;
            for( int i=0; i<WRITE_NUM; i=i+1 ) begin
                cb.rx_req_addr <= CSR_AW'(8'h20+i);
                cb.rx_req_wdata <= 32'hcafe_0000 | CSR_DW'(i);
                do @(cb); while( !cb.rx_req_ready );
            end
            cb.rx_req_write <= 1'b0;
            for( int i=0; i<READ_NUM; i=i+1 ) begin
                cb.rx_req_addr <= CSR_AW'(8'h40+i);
                cb.rx_req_wdata <= '0;
                do @(cb); while( !cb.rx_req_ready );
            end
            cb.rx_req_valid <= 1'b0;
        end
        begin
            for( int i=0; i<REQ_NUM; i=i+1 ) begin
                if( i==0 )
                    do @(cb); while( !cb.tx_req_valid );
                else begin
                    @(cb);
                    if( !cb.tx_req_valid )
                        $fatal(1, "CSR regslice request bubble at %0d", i);
                end
                if( i<WRITE_NUM ) begin
                    if( !cb.tx_req_write || cb.tx_req_addr!==CSR_AW'(8'h20+i) ||
                        cb.tx_req_wdata!==(32'hcafe_0000 | CSR_DW'(i)) || cb.tx_req_wstrb!=='1 )
                        $fatal(1, "CSR regslice write request mismatch at %0d", i);
                end
                else begin
                    if( cb.tx_req_write || cb.tx_req_addr!==CSR_AW'(8'h40+i-WRITE_NUM) )
                        $fatal(1, "CSR regslice read request mismatch at %0d", i-WRITE_NUM);
                end
            end
        end
    join

    // Return and monitor responses in parallel because CSR response has no ready.
    fork
        begin
            for( int i=0; i<READ_NUM; i=i+1 ) begin
                cb.tx_rsp_rdata <= F_rsp_data(i);
                cb.tx_rsp_rvalid <= 1'b1;
                @(cb);
            end
            cb.tx_rsp_rvalid <= 1'b0;
        end
        begin
            for( int i=0; i<READ_NUM; i=i+1 ) begin
                if( i==0 )
                    do @(cb); while( !cb.rx_rsp_rvalid );
                else begin
                    @(cb);
                    if( !cb.rx_rsp_rvalid )
                        $fatal(1, "CSR regslice response bubble at %0d", i);
                end
                if( cb.rx_rsp_rdata!==F_rsp_data(i) )
                    $fatal(1, "CSR regslice response mismatch at %0d", i);
            end
        end
    join

    repeat(3) @(cb);
    o_done = 1'b1;
end

com_csr_regslice #(
    .CSR_AW    (CSR_AW ),
    .CSR_DW    (CSR_DW ),
    .REQ_DEPTH (2     ),
    .RSP_DEPTH (4     )
)u_com_csr_regslice
(
    .clk                (clk          ),
    .rst_n              (rst_n        ),
    .clear              (clear        ),
    .i_rx_csr_req_write (rx_req_write ),
    .i_rx_csr_req_addr  (rx_req_addr  ),
    .i_rx_csr_req_wdata (rx_req_wdata ),
    .i_rx_csr_req_wstrb (rx_req_wstrb ),
    .i_rx_csr_req_valid (rx_req_valid ),
    .o_rx_csr_req_ready (rx_req_ready ),
    .o_rx_csr_rsp_rdata (rx_rsp_rdata ),
    .o_rx_csr_rsp_rvalid(rx_rsp_rvalid),
    .o_tx_csr_req_write (tx_req_write ),
    .o_tx_csr_req_addr  (tx_req_addr  ),
    .o_tx_csr_req_wdata (tx_req_wdata ),
    .o_tx_csr_req_wstrb (tx_req_wstrb ),
    .o_tx_csr_req_valid (tx_req_valid ),
    .i_tx_csr_req_ready (tx_req_ready ),
    .i_tx_csr_rsp_rdata (tx_rsp_rdata ),
    .i_tx_csr_rsp_rvalid(tx_rsp_rvalid)
);

endmodule
