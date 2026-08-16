`timescale 1ns/1ps

module fifo_ram_rd_delay #( parameter
    DW    = 16,
    DELAY = 1
)
(
input  logic          clk,
input  logic [DW-1:0] i_data,
output logic [DW-1:0] o_data
);

generate
if( DELAY==1 ) begin:gen_direct
    always_comb o_data = i_data;
end
else begin:gen_delay
    logic [DW-1:0] r_data_pipe [0:DELAY-2];

    always_ff @(posedge clk) begin
        r_data_pipe[0] <= i_data;
        for( int i=1; i<DELAY-1; i=i+1 ) begin
            r_data_pipe[i] <= r_data_pipe[i-1];
        end
    end

    always_comb o_data = r_data_pipe[DELAY-2];
end
endgenerate

endmodule

module fifo_basic_case #( parameter
    DUT_TYPE = 0,
    CASE_ID  = 0,
    DW       = 16,
    DEPTH    = 4,
    RAM_DEPTH = 8,
    OUT_DEPTH = 4,
    RAM_RD_DELAY = 1,
    CYCLE_N  = 2000,
    SEED     = 32'h1234_5678,
    ALLOW_FULL_BYP = 0,
    localparam CW = $clog2(DEPTH+1),
    localparam RAM_ONE_DEPTH = RAM_DEPTH/2,
    localparam RAM_ONE_DW = DW*2,
    localparam RAM_ONE_AW = $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2),
    localparam RAM_AW = $clog2(RAM_DEPTH>2?RAM_DEPTH:2)
)
(
output logic o_done
);

logic clk;

fifo_if #(
    .DW ( DW ),
    .CW ( CW )
)fifo_bus
(
    .clk ( clk )
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

generate
if( DUT_TYPE==0 ) begin:gen_fifo_reg
    com_sync_fifo_reg #(
        .DW    ( DW    ),
        .DEPTH ( DEPTH )
    )u_dut
    (
        .clk           ( fifo_bus.clk           ),
        .rst_n         ( fifo_bus.rst_n         ),
        .clear         ( fifo_bus.clear         ),
        .i_wr_en       ( fifo_bus.i_wr_en       ),
        .i_wr_data     ( fifo_bus.i_wr_data     ),
        .o_wr_full     ( fifo_bus.o_wr_full     ),
        .i_rd_en       ( fifo_bus.i_rd_en       ),
        .o_rd_data     ( fifo_bus.o_rd_data     ),
        .o_rd_empty    ( fifo_bus.o_rd_empty    ),
        .o_water_level ( fifo_bus.o_water_level )
    );
end
else if( DUT_TYPE==1 ) begin:gen_fifo_reg_v2
    com_sync_fifo_reg_v2 #(
        .DW    ( DW    ),
        .DEPTH ( DEPTH )
    )u_dut
    (
        .clk           ( fifo_bus.clk           ),
        .rst_n         ( fifo_bus.rst_n         ),
        .clear         ( fifo_bus.clear         ),
        .i_wr_en       ( fifo_bus.i_wr_en       ),
        .i_wr_data     ( fifo_bus.i_wr_data     ),
        .o_wr_full     ( fifo_bus.o_wr_full     ),
        .i_rd_en       ( fifo_bus.i_rd_en       ),
        .o_rd_data     ( fifo_bus.o_rd_data     ),
        .o_rd_empty    ( fifo_bus.o_rd_empty    ),
        .o_water_level ( fifo_bus.o_water_level )
    );
end
else if( DUT_TYPE==2 ) begin:gen_fifo_reg_pfetch
    com_sync_fifo_reg_pfetch #(
        .DW    ( DW    ),
        .DEPTH ( DEPTH )
    )u_dut
    (
        .clk           ( fifo_bus.clk           ),
        .rst_n         ( fifo_bus.rst_n         ),
        .clear         ( fifo_bus.clear         ),
        .i_wr_en       ( fifo_bus.i_wr_en       ),
        .i_wr_data     ( fifo_bus.i_wr_data     ),
        .o_wr_full     ( fifo_bus.o_wr_full     ),
        .i_rd_en       ( fifo_bus.i_rd_en       ),
        .o_rd_data     ( fifo_bus.o_rd_data     ),
        .o_rd_empty    ( fifo_bus.o_rd_empty    ),
        .o_water_level ( fifo_bus.o_water_level )
    );
end
else if( DUT_TYPE==3 ) begin:gen_fifo_reg_fullbyp
    com_sync_fifo_reg_fullbyp #(
        .DW    ( DW    ),
        .DEPTH ( DEPTH )
    )u_dut
    (
        .clk           ( fifo_bus.clk           ),
        .rst_n         ( fifo_bus.rst_n         ),
        .clear         ( fifo_bus.clear         ),
        .i_wr_en       ( fifo_bus.i_wr_en       ),
        .i_wr_data     ( fifo_bus.i_wr_data     ),
        .o_wr_full     ( fifo_bus.o_wr_full     ),
        .i_rd_en       ( fifo_bus.i_rd_en       ),
        .o_rd_data     ( fifo_bus.o_rd_data     ),
        .o_rd_empty    ( fifo_bus.o_rd_empty    ),
        .o_water_level ( fifo_bus.o_water_level )
    );
end
else if( DUT_TYPE==4 ) begin:gen_fifo_ram_1p1bank
    wire                       u_ram_i_ce_n;
    wire                       u_ram_i_we_n;
    wire [RAM_ONE_AW-1:0]      u_ram_i_addr;
    wire [RAM_ONE_DW-1:0]      u_ram_i_wr_data;
    wire [RAM_ONE_DW-1:0]      u_ram_o_rd_data;
    wire [RAM_ONE_DW-1:0]      u_ram_o_rd_data_raw;

    com_sync_fifo_ram_1p1bank #(
        .DW           ( DW           ),
        .RAM_DEPTH    ( RAM_DEPTH    ),
        .OUT_DEPTH    ( OUT_DEPTH    ),
        .RAM_RD_DELAY ( RAM_RD_DELAY )
    )u_dut
    (
        .clk           ( fifo_bus.clk           ),
        .rst_n         ( fifo_bus.rst_n         ),
        .clear         ( fifo_bus.clear         ),

        .i_wr_en       ( fifo_bus.i_wr_en       ),
        .i_wr_data     ( fifo_bus.i_wr_data     ),
        .o_wr_full     ( fifo_bus.o_wr_full     ),
        .i_rd_en       ( fifo_bus.i_rd_en       ),
        .o_rd_data     ( fifo_bus.o_rd_data     ),
        .o_rd_empty    ( fifo_bus.o_rd_empty    ),
        .o_water_level ( fifo_bus.o_water_level ),

        .o_ram_ce_n    ( u_ram_i_ce_n           ),
        .o_ram_we_n    ( u_ram_i_we_n           ),
        .o_ram_addr    ( u_ram_i_addr           ),
        .o_ram_wr_data ( u_ram_i_wr_data        ),
        .i_ram_rd_data ( u_ram_o_rd_data        )
    );

    com_spram_shell #(
        .DATA_W   ( RAM_ONE_DW    ),
        .DEPTH    ( RAM_ONE_DEPTH ),
        .STRB_W   ( 1             )
    )u_ram
    (
        .clk            ( fifo_bus.clk          ),
        .i_cfg_mem_ctrl ( '0                    ),
        .i_ce_n         ( u_ram_i_ce_n          ),
        .i_we_n         ( u_ram_i_we_n          ),
        .i_addr         ( u_ram_i_addr          ),
        .i_wr_data      ( u_ram_i_wr_data       ),
        .o_rd_data      ( u_ram_o_rd_data_raw   )
    );

    fifo_ram_rd_delay #(
        .DW    ( RAM_ONE_DW    ),
        .DELAY ( RAM_RD_DELAY  )
    )u_ram_rd_delay
    (
        .clk    ( fifo_bus.clk         ),
        .i_data ( u_ram_o_rd_data_raw  ),
        .o_data ( u_ram_o_rd_data      )
    );
end
else if( DUT_TYPE==5 ) begin:gen_fifo_ram_1p2bank
    wire [1:0]                 u_ram_i_ce_n;
    wire [1:0]                 u_ram_i_we_n;
    wire [1:0][RAM_ONE_AW-1:0] u_ram_i_addr;
    wire [1:0][DW-1:0]         u_ram_i_wr_data;
    wire [1:0][DW-1:0]         u_ram_o_rd_data;
    wire [1:0][DW-1:0]         u_ram_o_rd_data_raw;

    com_sync_fifo_ram_1p2bank #(
        .DW           ( DW           ),
        .RAM_DEPTH    ( RAM_DEPTH    ),
        .OUT_DEPTH    ( OUT_DEPTH    ),
        .RAM_RD_DELAY ( RAM_RD_DELAY )
    )u_dut
    (
        .clk           ( fifo_bus.clk           ),
        .rst_n         ( fifo_bus.rst_n         ),
        .clear         ( fifo_bus.clear         ),

        .i_wr_en       ( fifo_bus.i_wr_en       ),
        .i_wr_data     ( fifo_bus.i_wr_data     ),
        .o_wr_full     ( fifo_bus.o_wr_full     ),
        .i_rd_en       ( fifo_bus.i_rd_en       ),
        .o_rd_data     ( fifo_bus.o_rd_data     ),
        .o_rd_empty    ( fifo_bus.o_rd_empty    ),
        .o_water_level ( fifo_bus.o_water_level ),

        .o_ram_ce_n    ( u_ram_i_ce_n           ),
        .o_ram_we_n    ( u_ram_i_we_n           ),
        .o_ram_addr    ( u_ram_i_addr           ),
        .o_ram_wr_data ( u_ram_i_wr_data        ),
        .i_ram_rd_data ( u_ram_o_rd_data        )
    );

    for( genvar gi=0; gi<2; gi=gi+1 ) begin:gen_ram_bank
        com_spram_shell #(
            .DATA_W   ( DW            ),
            .DEPTH    ( RAM_ONE_DEPTH ),
            .STRB_W   ( 1             )
        )u_ram
        (
            .clk            ( fifo_bus.clk           ),
            .i_cfg_mem_ctrl ( '0                     ),
            .i_ce_n         ( u_ram_i_ce_n[gi]       ),
            .i_we_n         ( u_ram_i_we_n[gi]       ),
            .i_addr         ( u_ram_i_addr[gi]       ),
            .i_wr_data      ( u_ram_i_wr_data[gi]    ),
            .o_rd_data      ( u_ram_o_rd_data_raw[gi] )
        );

        fifo_ram_rd_delay #(
            .DW    ( DW            ),
            .DELAY ( RAM_RD_DELAY  )
        )u_ram_rd_delay
        (
            .clk    ( fifo_bus.clk             ),
            .i_data ( u_ram_o_rd_data_raw[gi]  ),
            .o_data ( u_ram_o_rd_data[gi]      )
        );
    end
end
else begin:gen_fifo_ram_2p1ck
    wire              u_ram_i_wr_en;
    wire [RAM_AW-1:0] u_ram_i_wr_addr;
    wire [DW-1:0]     u_ram_i_wr_data;
    wire              u_ram_i_rd_en;
    wire [RAM_AW-1:0] u_ram_i_rd_addr;
    wire [DW-1:0]     u_ram_o_rd_data;
    wire [DW-1:0]     u_ram_o_rd_data_raw;

    com_sync_fifo_ram_2p1ck #(
        .DW           ( DW           ),
        .RAM_DEPTH    ( RAM_DEPTH    ),
        .OUT_DEPTH    ( OUT_DEPTH    ),
        .RAM_RD_DELAY ( RAM_RD_DELAY )
    )u_dut
    (
        .clk           ( fifo_bus.clk           ),
        .rst_n         ( fifo_bus.rst_n         ),
        .clear         ( fifo_bus.clear         ),

        .i_wr_en       ( fifo_bus.i_wr_en       ),
        .i_wr_data     ( fifo_bus.i_wr_data     ),
        .o_wr_full     ( fifo_bus.o_wr_full     ),
        .i_rd_en       ( fifo_bus.i_rd_en       ),
        .o_rd_data     ( fifo_bus.o_rd_data     ),
        .o_rd_empty    ( fifo_bus.o_rd_empty    ),
        .o_water_level ( fifo_bus.o_water_level ),

        .o_ram_wr_en   ( u_ram_i_wr_en          ),
        .o_ram_wr_addr ( u_ram_i_wr_addr        ),
        .o_ram_wr_data ( u_ram_i_wr_data        ),
        .o_ram_rd_en   ( u_ram_i_rd_en          ),
        .o_ram_rd_addr ( u_ram_i_rd_addr        ),
        .i_ram_rd_data ( u_ram_o_rd_data        )
    );

    com_tpram1ck_shell #(
        .DATA_W   ( DW            ),
        .DEPTH    ( RAM_DEPTH     ),
        .STRB_W   ( 1             )
    )u_ram
    (
        .clk            ( fifo_bus.clk          ),
        .i_cfg_mem_ctrl ( '0                    ),
        .i_wr_en        ( u_ram_i_wr_en         ),
        .i_wr_addr      ( u_ram_i_wr_addr       ),
        .i_wr_data      ( u_ram_i_wr_data       ),
        .i_rd_en        ( u_ram_i_rd_en         ),
        .i_rd_addr      ( u_ram_i_rd_addr       ),
        .o_rd_data      ( u_ram_o_rd_data_raw   )
    );

    fifo_ram_rd_delay #(
        .DW    ( DW            ),
        .DELAY ( RAM_RD_DELAY  )
    )u_ram_rd_delay
    (
        .clk    ( fifo_bus.clk         ),
        .i_data ( u_ram_o_rd_data_raw  ),
        .o_data ( u_ram_o_rd_data      )
    );
end
endgenerate

fifo_drv #(
    .DW             ( DW             ),
    .DEPTH          ( DEPTH          ),
    .CW             ( CW             ),
    .CASE_ID        ( CASE_ID        ),
    .DUT_TYPE       ( DUT_TYPE       ),
    .CYCLE_N        ( CYCLE_N        ),
    .SEED           ( SEED           ),
    .ALLOW_FULL_BYP ( ALLOW_FULL_BYP )
)u_drv
(
    .fifo_bus ( fifo_bus ),
    .o_done   ( o_done   )
);

endmodule
