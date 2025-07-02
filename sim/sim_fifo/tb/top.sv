module top();

bit clk   ;
bit rst_n ;
bit clear ;

bit dst_clk   ;
wire [`COM_SYS_W-1:0] mem_cfg;

always #2   clk= ~clk;
always #3   dst_clk= ~dst_clk;

task reset();
    #10; rst_n = 1'b1;
    #15; rst_n = 1'b0;
    #20; rst_n = 1'b1;
endtask //
task xclear();
    @( posedge clk ); clear <= 1'b0;
    @( posedge clk ); clear <= 1'b1;
    @( posedge clk ); clear <= 1'b0;
endtask //


//-------------------------------------------------------
//dut
//-------------------------------------------------------

//#batch#######################################################################
//-------------------------------------------------------
//com_syncfifo_reg
//-------------------------------------------------------
import FifoPkg::*;
// bit [FIFO_AW-0:0]       water_level         ;

FifoIf #( .DW(FIFO_DW), .DEPTH(FIFO_DEPTH) ) fifo_if( clk );
fifo_test #( virtual FifoIf #(.DW(FIFO_DW), .DEPTH(FIFO_DEPTH)) ) fifo_t1( fifo_if );
com_sync_fifo_reg #(
    .DW         ( FIFO_DW         ), //8
    .DEPTH      ( FIFO_DEPTH      )  //4
)u_com_sync_fifo_reg
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( fifo_if.wr_en        ), //i
    .wr_data              ( fifo_if.wr_data      ), //i
    .wr_full              ( fifo_if.wr_full      ), //o
    .rd_en                ( fifo_if.rd_en        ), //i
    .rd_data              ( fifo_if.rd_data      ), //o
    .rd_empty             ( fifo_if.rd_empty     ), //o
    .water_level          (                      )  //o
);

//-------------------------------------------------------
//com_sync_fifo_ram_1p2bank
//-------------------------------------------------------
localparam RAM_RD_DELAY = 1;
FifoIf #( .DW(FIFO_RAM1P_DW), .DEPTH(FIFO_RAM1P_DEPTH) ) fifo_ram1p_if( clk );
fifo_test #( virtual FifoIf #(.DW(FIFO_RAM1P_DW), .DEPTH(FIFO_RAM1P_DEPTH)) ) fifo_ram1p_t1( fifo_ram1p_if );

wire [1:0]                        ram1p_cen  ;
wire [1:0]                        ram1p_we   ;
wire [1:0][FIFO_RAM1P_ONE_AW-1:0] ram1p_addr ;
wire [1:0][FIFO_RAM1P_DW-1:0]     ram1p_din  ;
wire [1:0][FIFO_RAM1P_DW-1:0]     ram1p_qout ;
wire [1:0][FIFO_RAM1P_DW-1:0]     ram1p_qout_d ;
generate
if (RAM_RD_DELAY>1) begin
    reg  [RAM_RD_DELAY-2:0][1:0][FIFO_RAM1P_DW-1:0] r_rdata;
    assign ram1p_qout_d = r_rdata[RAM_RD_DELAY-2];
    always @( posedge clk )begin
        r_rdata[0] <= ram1p_qout;
        for( int i=0; i<RAM_RD_DELAY-2; i++ )
            r_rdata[i+1] <= r_rdata[i];
    end
end
else begin
    assign ram1p_qout_d = ram1p_qout;
end
com_sync_fifo_ram_1p2bank #(
    .RAM_RD_DELAY( RAM_RD_DELAY    ), //1
    .DW         ( FIFO_RAM1P_DW     ), //8
    .RAM_DEPTH  ( FIFO_RAM1P_DEPTH  )//, //4
)u_com_sync_fifo_ram_1p2bank
(
    .clk                  ( clk                    ), //i
    .rst_n                ( rst_n                  ), //i
    .clear                ( clear                  ), //i

    .wr_en                ( fifo_ram1p_if.wr_en    ), //i
    .wr_data              ( fifo_ram1p_if.wr_data  ), //i
    .wr_full              ( fifo_ram1p_if.wr_full  ), //o
    .rd_en                ( fifo_ram1p_if.rd_en    ), //i
    .rd_data              ( fifo_ram1p_if.rd_data  ), //o
    .rd_empty             ( fifo_ram1p_if.rd_empty ), //o
    .water_level          (                        ), //o

    .ram_cen              ( ram1p_cen              ), //o
    .ram_we               ( ram1p_we               ), //o
    .ram_addr             ( ram1p_addr             ), //o
    .ram_din              ( ram1p_din              ), //o
    .ram_qout             ( ram1p_qout_d           )  //i
);
com_spram_cell #(
    .DATA_W     ( FIFO_RAM1P_DW        ), //32
    .DEPTH      ( FIFO_RAM1P_ONE_DEPTH )//, //512
)zt_com_spram_cell_1p[1:0]
(
    .clk                  ( clk                  ), //i
    .mem_cfg              ( mem_cfg              ), //i

    .cen                  ( ram1p_cen            ), //i
    .we                   ( ram1p_we             ), //i
    .addr                 ( ram1p_addr           ), //i
    .din                  ( ram1p_din            ), //i
    .qout                 ( ram1p_qout           )  //o
);

//-------------------------------------------------------
//com_sync_fifo_ram_2p1ck
//-------------------------------------------------------
FifoIf #( .DW(FIFO_RAM2P_DW), .DEPTH(FIFO_RAM2P_DEPTH) ) fifo_ram2p_if( clk );
fifo_test #( virtual FifoIf #(.DW(FIFO_RAM2P_DW), .DEPTH(FIFO_RAM2P_DEPTH)) ) fifo_ram2p_t1( fifo_ram2p_if );
wire [FIFO_RAM2P_TOL_AW-1:0] ram2p_water_level;
wire                     ram2p1ck_wr_en   ;
wire [FIFO_RAM2P_AW-1:0] ram2p1ck_wr_addr ;
wire [FIFO_RAM2P_DW-1:0] ram2p1ck_wr_data ;
wire                     ram2p1ck_rd_en   ;
wire [FIFO_RAM2P_AW-1:0] ram2p1ck_rd_addr ;
wire [FIFO_RAM2P_DW-1:0] ram2p1ck_rd_data ;
wire [FIFO_RAM2P_AW-1:0] ram2p1ck_wr_addr_t = ram2p1ck_wr_addr;
wire [FIFO_RAM2P_AW-1:0] ram2p1ck_rd_addr_t = ram2p1ck_rd_addr;
endgenerate
com_sync_fifo_ram_2p1ck #(
    .DW         ( FIFO_RAM2P_DW    ), //8
    .RAM_DEPTH  ( FIFO_RAM2P_DEPTH )  //4
)u_com_sync_fifo_ram_2p1ck
(
    .clk                  ( clk                    ), //i
    .rst_n                ( rst_n                  ), //i
    .clear                ( clear                  ), //i

    .wr_en                ( fifo_ram2p_if.wr_en    ), //i
    .wr_data              ( fifo_ram2p_if.wr_data  ), //i
    .wr_full              ( fifo_ram2p_if.wr_full  ), //o
    .rd_en                ( fifo_ram2p_if.rd_en    ), //i
    .rd_data              ( fifo_ram2p_if.rd_data  ), //o
    .rd_empty             ( fifo_ram2p_if.rd_empty ), //o
    .water_level          ( ram2p_water_level      ), //o

    .ram_wr_en            ( ram2p1ck_wr_en         ), //o
    .ram_wr_addr          ( ram2p1ck_wr_addr       ), //o
    .ram_wr_data          ( ram2p1ck_wr_data       ), //o
    .ram_rd_en            ( ram2p1ck_rd_en         ), //o
    .ram_rd_addr          ( ram2p1ck_rd_addr       ), //o
    .ram_rd_data          ( ram2p1ck_rd_data       )  //i
);
com_tpram1ck_cell #(
    .DATA_W       ( FIFO_RAM2P_DW    ), //
    .DEPTH        ( FIFO_RAM2P_DEPTH )  //
)zt_com_tpram1ck_cell
(
    .clk                  ( clk                  ), //i
    .mem_cfg              ( mem_cfg              ), //i

    .wr_en                ( ram2p1ck_wr_en       ), //i
    .wr_addr              ( ram2p1ck_wr_addr_t   ), //i
    .wr_data              ( ram2p1ck_wr_data     ), //i
    .rd_en                ( ram2p1ck_rd_en       ), //i
    .rd_addr              ( ram2p1ck_rd_addr_t   ), //i
    .rd_data              ( ram2p1ck_rd_data     )  //o
);

//-------------------------------------------------------
//com_asyncfifo_reg
//-------------------------------------------------------
import AFifoPkg::*;

AFifoIf #(.DW(AFIFO_DW), .DEPTH(AFIFO_DEPTH)) afifo_if( .wr_clk(clk), .rd_clk(dst_clk) );
afifo_test #( virtual AFifoIf #(.DW(AFIFO_DW), .DEPTH(AFIFO_DEPTH)) ) afifo_t1( afifo_if );
com_async_fifo_reg #(
    .DW         ( AFIFO_DW         ), //8
    .DEPTH      ( AFIFO_DEPTH      )  //4
)u_com_async_fifo_reg
(
    .wr_clk               ( clk                  ), //i
    .wr_rst_n             ( rst_n                ), //i
    .wr_clear             ( clear                ), //i
    .rd_clk               ( dst_clk              ), //i
    .rd_rst_n             ( rst_n                ), //i
    .rd_clear             ( 1'b0                 ), //i

    .wr_en                ( afifo_if.wr_en       ), //i
    .wr_data              ( afifo_if.wr_data     ), //i
    .wr_full              ( afifo_if.wr_full     ), //o
    .rd_en                ( afifo_if.rd_en       ), //i
    .rd_data              ( afifo_if.rd_data     ), //o
    .rd_empty             ( afifo_if.rd_empty    ), //o
    .water_level          (                      )  //o
);

//-------------------------------------------------------
//com_asyncfifo_reg_2p2ck
//-------------------------------------------------------
AFifoIf #(.DW(AFIFO_RAM2CK_DW), .DEPTH(AFIFO_RAM2CK_DEPTH)) afifo2ck_if( .wr_clk(clk), .rd_clk(dst_clk) );
afifo_test #( virtual AFifoIf #(.DW(AFIFO_RAM2CK_DW), .DEPTH(AFIFO_RAM2CK_DEPTH)) ) afifo2ck_t1( afifo2ck_if );

wire                       ram2ck_wr_en   ;
wire [AFIFO_RAM2CK_AW-1:0] ram2ck_wr_addr ;
wire [AFIFO_RAM2CK_DW-1:0] ram2ck_wr_data ;
wire                       ram2ck_rd_en   ;
wire [AFIFO_RAM2CK_AW-1:0] ram2ck_rd_addr ;
wire [AFIFO_RAM2CK_DW-1:0] ram2ck_rd_data ;
wire [AFIFO_RAM2CK_CW-1:0] afifo2ck_water_level ;
wire [AFIFO_RAM2CK_AW-1:0] ram2ck_wr_addr_t = ram2ck_wr_addr;
wire [AFIFO_RAM2CK_AW-1:0] ram2ck_rd_addr_t = ram2ck_rd_addr;
com_async_fifo_ram_2p2ck #(
    .DW         ( AFIFO_RAM2CK_DW     ), //8
    .RAM_DEPTH  ( AFIFO_RAM2CK_DEPTH  )  //4
)u_com_async_fifo_ram_2p2ck
(
    .wr_clk               ( clk                  ), //i
    .wr_rst_n             ( rst_n                ), //i
    .wr_clear             ( clear                ), //i
    .rd_clk               ( dst_clk              ), //i
    .rd_rst_n             ( rst_n                ), //i
    .rd_clear             ( 1'b0                 ), //i

    .wr_en                ( afifo2ck_if.wr_en    ), //i
    .wr_data              ( afifo2ck_if.wr_data  ), //i
    .wr_full              ( afifo2ck_if.wr_full  ), //o
    .rd_en                ( afifo2ck_if.rd_en    ), //i
    .rd_data              ( afifo2ck_if.rd_data  ), //o
    .rd_empty             ( afifo2ck_if.rd_empty ), //o
    .water_level          ( afifo2ck_water_level ), //o

    .ram_wr_en            ( ram2ck_wr_en         ), //o
    .ram_wr_addr          ( ram2ck_wr_addr       ), //o
    .ram_wr_data          ( ram2ck_wr_data       ), //o
    .ram_rd_en            ( ram2ck_rd_en         ), //o
    .ram_rd_addr          ( ram2ck_rd_addr       ), //o
    .ram_rd_data          ( ram2ck_rd_data       )  //i
);
com_tpram2ck_cell #(
    .DATA_W       ( AFIFO_RAM2CK_DW    ), //
    .DEPTH        ( AFIFO_RAM2CK_DEPTH )  //
)zt_com_tpram2ck_cell_afifo2ck
(
    .wr_clk               ( clk                  ), //i
    .rd_clk               ( dst_clk              ), //i
    .mem_cfg              ( mem_cfg              ), //i

    .wr_en                ( ram2ck_wr_en         ), //i
    .wr_addr              ( ram2ck_wr_addr_t     ), //i
    .wr_data              ( ram2ck_wr_data       ), //i
    .rd_en                ( ram2ck_rd_en         ), //i
    .rd_addr              ( ram2ck_rd_addr_t     ), //i
    .rd_data              ( ram2ck_rd_data       )  //o
);

//-------------------------------------------------------
//com_asyncfifo_reg_2p1ck
//-------------------------------------------------------
AFifoIf #(.DW(AFIFO_RAM1CK_DW), .DEPTH(AFIFO_RAM1CK_DEPTH)) afifo1ck_if( .wr_clk(clk), .rd_clk(dst_clk) );
afifo_test #( virtual AFifoIf #(.DW(AFIFO_RAM1CK_DW), .DEPTH(AFIFO_RAM1CK_DEPTH)) ) afifo1ck_t1( afifo1ck_if );

wire [AFIFO_RAM1CK_TOL_AW-1:0] afifo1ck_water_level ;
wire                       ram1ck_wr_en   ;
wire [AFIFO_RAM1CK_AW-1:0] ram1ck_wr_addr ;
wire [AFIFO_RAM1CK_DW-1:0] ram1ck_wr_data ;
wire                       ram1ck_rd_en   ;
wire [AFIFO_RAM1CK_AW-1:0] ram1ck_rd_addr ;
wire [AFIFO_RAM1CK_DW-1:0] ram1ck_rd_data ;
wire [AFIFO_RAM1CK_AW-1:0] ram1ck_wr_addr_t = ram1ck_wr_addr;
wire [AFIFO_RAM1CK_AW-1:0] ram1ck_rd_addr_t = ram1ck_rd_addr;
com_async_fifo_ram_2p1ck #(
    .DW         ( AFIFO_RAM1CK_DW        ), //8
    .RAM_DEPTH  ( AFIFO_RAM1CK_DEPTH     ), //4
    .OUT_DEPTH  ( AFIFO_RAM1CK_OUT_DEPTH )  //8
)u_com_async_fifo_ram_2p1ck
(
    .wr_clk               ( clk                  ), //i
    .wr_rst_n             ( rst_n                ), //i
    .wr_clear             ( clear                ), //i
    .rd_clk               ( dst_clk              ), //i
    .rd_rst_n             ( rst_n                ), //i
    .rd_clear             ( 1'b0                 ), //i

    .wr_en                ( afifo1ck_if.wr_en    ), //i
    .wr_data              ( afifo1ck_if.wr_data  ), //i
    .wr_full              ( afifo1ck_if.wr_full  ), //o
    .rd_en                ( afifo1ck_if.rd_en    ), //i
    .rd_data              ( afifo1ck_if.rd_data  ), //o
    .rd_empty             ( afifo1ck_if.rd_empty ), //o
    .water_level          ( afifo1ck_water_level ), //o

    .ram_wr_en            ( ram1ck_wr_en         ), //o
    .ram_wr_addr          ( ram1ck_wr_addr       ), //o
    .ram_wr_data          ( ram1ck_wr_data       ), //o
    .ram_rd_en            ( ram1ck_rd_en         ), //o
    .ram_rd_addr          ( ram1ck_rd_addr       ), //o
    .ram_rd_data          ( ram1ck_rd_data       )  //i
);
com_tpram2ck_cell #(
    .DATA_W       ( AFIFO_RAM1CK_DW    ), //
    .DEPTH        ( AFIFO_RAM1CK_DEPTH )  //
)zt_com_tpram2ck_cell_afifo1ck
(
    .wr_clk               ( clk                  ), //i
    .rd_clk               ( dst_clk              ), //i
    .mem_cfg              ( mem_cfg              ), //i

    .wr_en                ( ram1ck_wr_en         ), //i
    .wr_addr              ( ram1ck_wr_addr_t     ), //i
    .wr_data              ( ram1ck_wr_data       ), //i
    .rd_en                ( ram1ck_rd_en         ), //i
    .rd_addr              ( ram1ck_rd_addr_t     ), //i
    .rd_data              ( ram1ck_rd_data       )  //o
);

//-------------------------------------------------------
//dump fsdb
//-------------------------------------------------------
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("run.fsdb");
    $fsdbDumpMDA(0,top)  ;   //dump array
    $fsdbDumpvars(0,top) ;  //dump struct
    $fsdbDumpvars(top,"+all");  //dump struct
    $fsdbDumpon();
end
`endif

endmodule
