`timescale 1ns/1ps

module csr_bridge_case
(
    output logic o_done
);

localparam AW = 16;
localparam DW = 32;

logic clk;
logic rst_n;
logic clear;

logic [AW-1:0]   apb_paddr;
logic            apb_psel;
logic            apb_penable;
logic            apb_pwrite;
logic [DW-1:0]   apb_pwdata;
logic [DW/8-1:0] apb_pstrb;
wire             apb_pready;
wire [DW-1:0]    apb_prdata;
wire             apb_csr_req_write;
wire [AW-1:0]    apb_csr_req_addr;
wire [DW-1:0]    apb_csr_req_wdata;
wire [DW/8-1:0]  apb_csr_req_wstrb;
wire             apb_csr_req_valid;
wire             apb_csr_req_ready;
wire [DW-1:0]    apb_csr_rsp_rdata;
wire             apb_csr_rsp_rvalid;
reg              r_apb_csr_rsp_vld;
reg  [DW-1:0]    r_apb_csr_rsp_data;

logic             ahb_hsel;
logic             ahb_hready;
logic [AW-1:0]    ahb_haddr;
logic [1:0]       ahb_htrans;
logic             ahb_hwrite;
logic [2:0]       ahb_hsize;
logic [DW-1:0]    ahb_hwdata;
wire [DW-1:0]     ahb_hrdata;
wire              ahb_hreadyout;
wire              ahb_csr_req_write;
wire [AW-1:0]     ahb_csr_req_addr;
wire [DW-1:0]     ahb_csr_req_wdata;
wire [DW/8-1:0]   ahb_csr_req_wstrb;
wire              ahb_csr_req_valid;
wire              ahb_csr_req_ready;
wire [DW-1:0]     ahb_csr_rsp_rdata;
wire              ahb_csr_rsp_rvalid;
reg               r_ahb_csr_rsp_vld;
reg  [DW-1:0]     r_ahb_csr_rsp_data;

logic [AW-1:0]    axil_awaddr;
logic             axil_awvalid;
wire              axil_awready;
logic [DW-1:0]    axil_wdata;
logic [DW/8-1:0]  axil_wstrb;
logic             axil_wvalid;
wire              axil_wready;
wire              axil_bvalid;
logic             axil_bready;
logic [AW-1:0]    axil_araddr;
logic             axil_arvalid;
wire              axil_arready;
wire [DW-1:0]     axil_rdata;
wire              axil_rvalid;
logic             axil_rready;
wire              axil_csr_req_write;
wire [AW-1:0]     axil_csr_req_addr;
wire [DW-1:0]     axil_csr_req_wdata;
wire [DW/8-1:0]   axil_csr_req_wstrb;
wire              axil_csr_req_valid;
logic             axil_csr_req_ready;
wire [DW-1:0]     axil_csr_rsp_rdata;
wire              axil_csr_rsp_rvalid;
reg               r_axil_csr_rsp_vld;
reg  [DW-1:0]     r_axil_csr_rsp_data;
integer           axil_read_req_cnt;
integer           axil_rsp_cnt;
integer           axil_write_req_cnt;

logic              c2a_csr_req_write;
logic [AW-1:0]     c2a_csr_req_addr;
logic [DW-1:0]     c2a_csr_req_wdata;
logic [DW/8-1:0]   c2a_csr_req_wstrb;
logic              c2a_csr_req_valid;
wire               c2a_csr_req_ready;
wire [DW-1:0]      c2a_csr_rsp_rdata;
wire               c2a_csr_rsp_rvalid;
wire [AW-1:0]      c2a_apb_paddr;
wire               c2a_apb_psel;
wire               c2a_apb_penable;
wire               c2a_apb_pwrite;
wire [DW-1:0]      c2a_apb_pwdata;
wire [DW/8-1:0]    c2a_apb_pstrb;
integer            c2a_apb_done_cnt;
reg                r_c2a_apb_started;

clocking cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output clear;
    output apb_paddr;
    output apb_psel;
    output apb_penable;
    output apb_pwrite;
    output apb_pwdata;
    output apb_pstrb;
    output ahb_hsel;
    output ahb_hready;
    output ahb_haddr;
    output ahb_htrans;
    output ahb_hwrite;
    output ahb_hsize;
    output ahb_hwdata;
    output axil_awaddr;
    output axil_awvalid;
    output axil_wdata;
    output axil_wstrb;
    output axil_wvalid;
    output axil_bready;
    output axil_araddr;
    output axil_arvalid;
    output axil_rready;
    output axil_csr_req_ready;
    output c2a_csr_req_write;
    output c2a_csr_req_addr;
    output c2a_csr_req_wdata;
    output c2a_csr_req_wstrb;
    output c2a_csr_req_valid;
    input  apb_pready;
    input  apb_prdata;
    input  ahb_hreadyout;
    input  ahb_hrdata;
    input  axil_awready;
    input  axil_wready;
    input  axil_bvalid;
    input  axil_arready;
    input  axil_rdata;
    input  axil_rvalid;
    input  c2a_csr_req_ready;
endclocking

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

function automatic [DW-1:0] F_read_data;
input [AW-1:0] addr;
begin
    F_read_data = 32'ha500_0000 | addr;
end
endfunction

task automatic apb_transfer;
input              write;
input [AW-1:0]     addr;
input [DW-1:0]     data;
begin
    cb.apb_paddr <= addr;
    cb.apb_pwrite <= write;
    cb.apb_pwdata <= data;
    cb.apb_psel <= 1'b1;
    cb.apb_penable <= 1'b0;
    @(cb);
    cb.apb_penable <= 1'b1;
    do @(cb); while( !cb.apb_pready );
    if( !write && cb.apb_prdata!==F_read_data(addr) )
        $fatal(1, "APB2CSR read data mismatch");
    cb.apb_penable <= 1'b0;
end
endtask

task automatic axil_send_read;
input [AW-1:0] addr;
begin
    @(cb);
    cb.axil_araddr <= addr;
    cb.axil_arvalid <= 1'b1;
    do @(cb); while( !cb.axil_arready );
    cb.axil_arvalid <= 1'b0;
end
endtask

task automatic c2a_push;
input              write;
input [AW-1:0]     addr;
input [DW-1:0]     data;
begin
    cb.c2a_csr_req_write <= write;
    cb.c2a_csr_req_addr <= addr;
    cb.c2a_csr_req_wdata <= data;
    cb.c2a_csr_req_valid <= 1'b1;
    do @(cb); while( !cb.c2a_csr_req_ready );
    cb.c2a_csr_req_valid <= 1'b0;
end
endtask

initial begin
    o_done = 1'b0;
    rst_n = 1'b0;
    clear = 1'b0;
    apb_paddr = '0;
    apb_psel = 1'b0;
    apb_penable = 1'b0;
    apb_pwrite = 1'b0;
    apb_pwdata = '0;
    apb_pstrb = '1;
    ahb_hsel = 1'b0;
    ahb_hready = 1'b1;
    ahb_haddr = '0;
    ahb_htrans = '0;
    ahb_hwrite = 1'b0;
    ahb_hsize = 3'd2;
    ahb_hwdata = '0;
    axil_awaddr = '0;
    axil_awvalid = 1'b0;
    axil_wdata = '0;
    axil_wstrb = '1;
    axil_wvalid = 1'b0;
    axil_bready = 1'b1;
    axil_araddr = '0;
    axil_arvalid = 1'b0;
    axil_rready = 1'b1;
    axil_csr_req_ready = 1'b0;
    c2a_csr_req_write = 1'b0;
    c2a_csr_req_addr = '0;
    c2a_csr_req_wdata = '0;
    c2a_csr_req_wstrb = '1;
    c2a_csr_req_valid = 1'b0;

    repeat(5) @(cb);
    cb.rst_n <= 1'b1;
    repeat(2) @(cb);

    // APB setup/access transfers remain back-to-back while PSEL stays high.
    apb_transfer(1'b1,16'h0010,32'h1111_0010);
    apb_transfer(1'b1,16'h0014,32'h1111_0014);
    apb_transfer(1'b0,16'h0020,'0);
    apb_transfer(1'b0,16'h0024,'0);
    cb.apb_psel <= 1'b0;

    // AHB-Lite read address phases run on consecutive accepted cycles.
    @(cb);
    cb.ahb_hsel <= 1'b1;
    cb.ahb_htrans <= 2'b10;
    for( int i=0; i<4; i=i+1 ) begin
        cb.ahb_haddr <= 16'h0100+AW'(i*4);
        @(cb);
        if( !cb.ahb_hreadyout )
            $fatal(1, "AHB2CSR inserted a read bubble");
    end
    cb.ahb_hsel <= 1'b0;
    cb.ahb_htrans <= 2'b00;
    repeat(2) @(cb);

    // Queue reads while CSR is stalled, then prove a later write cannot pass.
    cb.axil_arvalid <= 1'b1;
    for( int i=0; i<3; i=i+1 ) begin
        cb.axil_araddr <= 16'h0200+AW'(i*4);
        @(cb);
        if( !cb.axil_arready )
            $fatal(1, "AXI-Lite AR inserted a bubble at request %0d", i);
    end
    cb.axil_arvalid <= 1'b0;
    @(cb);
    cb.axil_awaddr <= 16'h0300;
    cb.axil_wdata <= 32'h55aa_0300;
    cb.axil_awvalid <= 1'b1;
    cb.axil_wvalid <= 1'b1;
    repeat(2) begin
        @(cb);
        if( cb.axil_awready || cb.axil_wready )
            $fatal(1, "AXI-Lite write overtook queued reads");
    end
    cb.axil_csr_req_ready <= 1'b1;
    while( !cb.axil_awready || !cb.axil_wready ) @(cb);
    cb.axil_awvalid <= 1'b0;
    cb.axil_wvalid <= 1'b0;
    while( axil_rsp_cnt<3 || axil_write_req_cnt<1 ) @(cb);

    // CSR requests are queued back-to-back; APB PSEL must not drop mid-stream.
    c2a_push(1'b1,16'h0400,32'h1000_0400);
    c2a_push(1'b1,16'h0404,32'h1000_0404);
    c2a_push(1'b0,16'h0408,'0);
    while( c2a_apb_done_cnt<3 ) @(cb);

    repeat(5) @(cb);
    o_done = 1'b1;
end

assign apb_csr_req_ready = 1'b1;
assign apb_csr_rsp_rvalid = r_apb_csr_rsp_vld;
assign apb_csr_rsp_rdata = r_apb_csr_rsp_data;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_apb_csr_rsp_vld <= 1'b0;
    else
        r_apb_csr_rsp_vld <= apb_csr_req_valid &&
                             apb_csr_req_ready && !apb_csr_req_write;
end
always @(posedge clk) begin
    if( rst_n && apb_psel && !apb_penable && apb_csr_req_valid )
        $fatal(1, "APB2CSR request was issued during setup phase");
    if( apb_csr_req_valid && apb_csr_req_ready && !apb_csr_req_write )
        r_apb_csr_rsp_data <= F_read_data(apb_csr_req_addr);
end

assign ahb_csr_req_ready = 1'b1;
assign ahb_csr_rsp_rvalid = r_ahb_csr_rsp_vld;
assign ahb_csr_rsp_rdata = r_ahb_csr_rsp_data;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ahb_csr_rsp_vld <= 1'b0;
    else
        r_ahb_csr_rsp_vld <= ahb_csr_req_valid &&
                             ahb_csr_req_ready && !ahb_csr_req_write;
end
always @(posedge clk) begin
    if( ahb_csr_req_valid && ahb_csr_req_ready && !ahb_csr_req_write )
        r_ahb_csr_rsp_data <= F_read_data(ahb_csr_req_addr);
end

assign axil_csr_rsp_rvalid = r_axil_csr_rsp_vld;
assign axil_csr_rsp_rdata = r_axil_csr_rsp_data;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_axil_csr_rsp_vld <= 1'b0;
        axil_read_req_cnt <= 0;
        axil_rsp_cnt <= 0;
        axil_write_req_cnt <= 0;
    end
    else begin
        r_axil_csr_rsp_vld <= axil_csr_req_valid &&
                              axil_csr_req_ready && !axil_csr_req_write;
        if( axil_csr_req_valid && axil_csr_req_ready ) begin
            if( axil_csr_req_write ) begin
                if( axil_read_req_cnt!=3 )
                    $fatal(1, "AXI-Lite CSR write issued before all reads");
                axil_write_req_cnt <= axil_write_req_cnt + 1;
            end
            else
                axil_read_req_cnt <= axil_read_req_cnt + 1;
        end
        if( axil_csr_req_ready && axil_read_req_cnt<3 && !axil_csr_req_valid )
            $fatal(1, "AXI-Lite CSR read request inserted a bubble");
        if( axil_rvalid ) begin
            if( axil_rdata!==F_read_data(16'h0200+AW'(axil_rsp_cnt*4)) )
                $fatal(1, "AXI-Lite read data mismatch");
            axil_rsp_cnt <= axil_rsp_cnt + 1;
        end
        if( axil_rsp_cnt>0 && axil_rsp_cnt<3 && !axil_rvalid )
            $fatal(1, "AXI-Lite R inserted a bubble");
    end
end
always @(posedge clk) begin
    if( axil_csr_req_valid && axil_csr_req_ready && !axil_csr_req_write )
        r_axil_csr_rsp_data <= F_read_data(axil_csr_req_addr);
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        c2a_apb_done_cnt <= 0;
        r_c2a_apb_started <= 1'b0;
    end
    else begin
        if( c2a_apb_psel )
            r_c2a_apb_started <= 1'b1;
        if( r_c2a_apb_started && c2a_apb_done_cnt<3 && !c2a_apb_psel )
            $fatal(1, "CSR2APB inserted an idle cycle between requests");
        if( c2a_apb_psel && c2a_apb_penable )
            c2a_apb_done_cnt <= c2a_apb_done_cnt + 1;
    end
end

com_csr_apb2csr #(
    .APB_AW (AW),
    .APB_DW (DW),
    .CSR_AW (AW),
    .CSR_DW (DW)
)u_com_csr_apb2csr
(
    .clk              (clk                 ),
    .rst_n            (rst_n               ),
    .clear            (clear               ),
    .i_apb_paddr      (apb_paddr           ),
    .i_apb_pprot      (3'b001              ),
    .i_apb_psel       (apb_psel            ),
    .i_apb_penable    (apb_penable         ),
    .i_apb_pwrite     (apb_pwrite          ),
    .i_apb_pwdata     (apb_pwdata          ),
    .i_apb_pstrb      (apb_pstrb           ),
    .o_apb_pready     (apb_pready          ),
    .o_apb_prdata     (apb_prdata          ),
    .o_apb_pslverr    (                    ),
    .o_csr_req_write  (apb_csr_req_write   ),
    .o_csr_req_addr   (apb_csr_req_addr    ),
    .o_csr_req_wdata  (apb_csr_req_wdata   ),
    .o_csr_req_wstrb  (apb_csr_req_wstrb   ),
    .o_csr_req_valid  (apb_csr_req_valid   ),
    .i_csr_req_ready  (apb_csr_req_ready   ),
    .i_csr_rsp_rdata  (apb_csr_rsp_rdata   ),
    .i_csr_rsp_rvalid (apb_csr_rsp_rvalid  )
);

com_csr_ahb2csr #(
    .AHB_AW (AW),
    .AHB_DW (DW),
    .CSR_AW (AW),
    .CSR_DW (DW)
)u_com_csr_ahb2csr
(
    .clk              (clk                 ),
    .rst_n            (rst_n               ),
    .clear            (clear               ),
    .i_ahb_hsel       (ahb_hsel            ),
    .i_ahb_hready     (ahb_hready          ),
    .i_ahb_haddr      (ahb_haddr           ),
    .i_ahb_htrans     (ahb_htrans          ),
    .i_ahb_hwrite     (ahb_hwrite          ),
    .i_ahb_hsize      (ahb_hsize           ),
    .i_ahb_hburst     (3'b000              ),
    .i_ahb_hprot      (4'b0011             ),
    .i_ahb_hwdata     (ahb_hwdata          ),
    .o_ahb_hrdata     (ahb_hrdata          ),
    .o_ahb_hreadyout  (ahb_hreadyout       ),
    .o_ahb_hresp      (                    ),
    .o_csr_req_write  (ahb_csr_req_write   ),
    .o_csr_req_addr   (ahb_csr_req_addr    ),
    .o_csr_req_wdata  (ahb_csr_req_wdata   ),
    .o_csr_req_wstrb  (ahb_csr_req_wstrb   ),
    .o_csr_req_valid  (ahb_csr_req_valid   ),
    .i_csr_req_ready  (ahb_csr_req_ready   ),
    .i_csr_rsp_rdata  (ahb_csr_rsp_rdata   ),
    .i_csr_rsp_rvalid (ahb_csr_rsp_rvalid  )
);

com_csr_axil2csr #(
    .AXI_AW      (AW),
    .AXI_DW      (DW),
    .CSR_AW      (AW),
    .CSR_DW      (DW),
    .RD_REQ_OSD  (4 ),
    .RD_DATA_OSD (0 )
)u_com_csr_axil2csr
(
    .clk              (clk                 ),
    .rst_n            (rst_n               ),
    .clear            (clear               ),
    .i_axil_awaddr    (axil_awaddr         ),
    .i_axil_awprot    (3'b000              ),
    .i_axil_awvalid   (axil_awvalid        ),
    .o_axil_awready   (axil_awready        ),
    .i_axil_wdata     (axil_wdata          ),
    .i_axil_wstrb     (axil_wstrb          ),
    .i_axil_wvalid    (axil_wvalid         ),
    .o_axil_wready    (axil_wready         ),
    .o_axil_bresp     (                    ),
    .o_axil_bvalid    (axil_bvalid         ),
    .i_axil_bready    (axil_bready         ),
    .i_axil_araddr    (axil_araddr         ),
    .i_axil_arprot    (3'b000              ),
    .i_axil_arvalid   (axil_arvalid        ),
    .o_axil_arready   (axil_arready        ),
    .o_axil_rdata     (axil_rdata          ),
    .o_axil_rresp     (                    ),
    .o_axil_rvalid    (axil_rvalid         ),
    .i_axil_rready    (axil_rready         ),
    .o_csr_req_write  (axil_csr_req_write  ),
    .o_csr_req_addr   (axil_csr_req_addr   ),
    .o_csr_req_wdata  (axil_csr_req_wdata  ),
    .o_csr_req_wstrb  (axil_csr_req_wstrb  ),
    .o_csr_req_valid  (axil_csr_req_valid  ),
    .i_csr_req_ready  (axil_csr_req_ready  ),
    .i_csr_rsp_rdata  (axil_csr_rsp_rdata  ),
    .i_csr_rsp_rvalid (axil_csr_rsp_rvalid )
);

com_csr2apb #(
    .CSR_AW    (AW),
    .CSR_DW    (DW),
    .APB_AW    (AW),
    .REQ_DEPTH (4 )
)u_com_csr2apb
(
    .clk                   (clk                  ),
    .rst_n                 (rst_n                ),
    .clear                 (clear                ),
    .i_csr_req_write       (c2a_csr_req_write   ),
    .i_csr_req_addr        (c2a_csr_req_addr    ),
    .i_csr_req_wdata       (c2a_csr_req_wdata   ),
    .i_csr_req_wstrb       (c2a_csr_req_wstrb   ),
    .i_csr_req_valid       (c2a_csr_req_valid   ),
    .o_csr_req_ready       (c2a_csr_req_ready   ),
    .o_csr_rsp_rdata       (c2a_csr_rsp_rdata   ),
    .o_csr_rsp_rvalid      (c2a_csr_rsp_rvalid  ),
    .o_apb_paddr           (c2a_apb_paddr       ),
    .o_apb_pprot           (                     ),
    .o_apb_psel            (c2a_apb_psel        ),
    .o_apb_penable         (c2a_apb_penable     ),
    .o_apb_pwrite          (c2a_apb_pwrite      ),
    .o_apb_pwdata          (c2a_apb_pwdata      ),
    .o_apb_pstrb           (c2a_apb_pstrb       ),
    .i_apb_pready          (1'b1                ),
    .i_apb_prdata          (F_read_data(c2a_apb_paddr)),
    .i_apb_pslverr         (1'b0                ),
    .o_pls_err_pslverr     (                     )
);

endmodule
