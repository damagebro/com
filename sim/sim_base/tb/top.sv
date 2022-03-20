module top();

bit clk   ;
bit rst_n ;
bit clear ;

bit dst_clk   ;

always #2   clk= ~clk;
always #3   dst_clk= ~dst_clk;

task reset();
    #10; rst_n = 1'b1;
    #15; rst_n = 1'b0;
    #20; rst_n = 1'b1;
endtask //reset_isp
task xclear();
    @( posedge clk ); clear <= 1'b0;
    @( posedge clk ); clear <= 1'b1;
    @( posedge clk ); clear <= 1'b0;
endtask //reset_isp


//-------------------------------------------------------
//dut
//-------------------------------------------------------


//#batch#######################################################################
//-------------------------------------------------------
//arb
//-------------------------------------------------------
import ArbPkg::*;
ArbIf #(.PORT_N(PORT_N)) arb_if( .clk(clk) );
arb_test arb_t1( arb_if );
com_arbiter_lite #(
    .MODE       ( "round_from_small" ), //small_first, large_first, round_from_small, round_from_large, round_hold_small, round_hold_large
    .PORT_N     ( PORT_N     )  //2
)u_com_arbiter_lite
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .requests             ( arb_if.requests      ), //i
    .grant_id             ( arb_if.grant_id      )  //o
);

//-------------------------------------------------------
//pipe
//-------------------------------------------------------
import PipePkg::*;
PipeIf #(.NUM_PIPE(PIPE_N)) pipe_if( .clk(clk) );
pipe_test pipe_t1( pipe_if );
com_pipe_ctrl #(
    .NUM_PIPE   ( PIPE_N   )  //2
)u_com_pipe_ctrl
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( pipe_if.ivld         ), //i
    .irdy                 ( pipe_if.irdy         ), //o
    .ovld                 ( pipe_if.ovld         ), //o
    .ordy                 ( pipe_if.ordy         ), //i
    .pipe_upen            ( pipe_if.pipe_upen    )  //o
);

//-------------------------------------------------------
//spram_mate
//-------------------------------------------------------
import RamMatePkg::*;
RamMateIf spram_if( .clk(clk) );
ram_mate_test ram_mate_t1( spram_if );
com_spram_mate #(
    .DEPTH      ( RAM_MATE_DEPTH      ), //16
    .DW         ( RAM_MATE_DW         ), //8
    .WSTB       ( RAM_MATE_WSTB       ), //1
    .WCH        ( RAM_MATE_WCH        ), //3
    .RCH        ( RAM_MATE_RCH        ), //2
    .WREG       ( RAM_MATE_WREG       ), //0
    .WRPRI      ( RAM_MATE_WRPRI      ), //1
    .CASCADE    ( RAM_MATE_CASCADE    )  //0
)u_com_spram_mate
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .arr_wr_vld           ( spram_if.arr_wr_vld  ), //i
    .arr_wr_addr          ( spram_if.arr_wr_addr ), //i
    .arr_wr_data          ( spram_if.arr_wr_data ), //i
    .arr_wr_rdy           ( spram_if.arr_wr_rdy  ), //o
    .arr_rd_vld           ( spram_if.arr_rd_vld  ), //i
    .arr_rd_addr          ( spram_if.arr_rd_addr ), //i
    .arr_rd_data          ( spram_if.arr_rd_data ), //o
    .arr_rd_ack           ( spram_if.arr_rd_ack  ), //o
    .arr_rd_rdy           ( spram_if.arr_rd_rdy  ), //o

    .cen                  ( spram_if.cen         ), //o
    .we                   ( spram_if.we          ), //o
    .addr                 ( spram_if.addr        ), //o
    .din                  ( spram_if.din         ), //o
    .qout                 ( spram_if.qout        ), //i
    .rd_ack               ( spram_if.rd_ack      ), //i
    .rd_rdy               ( spram_if.rd_rdy      ), //i
    .wr_rdy               ( spram_if.wr_rdy      )  //i
);

//-------------------------------------------------------
//tpram1ck_mate
//-------------------------------------------------------
RamMateIf tpram_if( .clk(clk) );
ram_mate_test ram_mate_t2( tpram_if );
com_tpram1ck_mate #(
    .DEPTH      ( RAM_MATE_DEPTH      ), //16
    .DW         ( RAM_MATE_DW         ), //8
    .WSTB       ( RAM_MATE_WSTB       ), //1
    .WCH        ( RAM_MATE_WCH        ), //3
    .RCH        ( RAM_MATE_RCH        ), //2
    .WREG       ( RAM_MATE_WREG       ), //0
    .CASCADE    ( RAM_MATE_CASCADE    )  //0
)u_com_tpram1ck_mate
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .arr_wr_vld           ( tpram_if.arr_wr_vld  ), //i
    .arr_wr_addr          ( tpram_if.arr_wr_addr ), //i
    .arr_wr_data          ( tpram_if.arr_wr_data ), //i
    .arr_wr_rdy           ( tpram_if.arr_wr_rdy  ), //o
    .arr_rd_vld           ( tpram_if.arr_rd_vld  ), //i
    .arr_rd_addr          ( tpram_if.arr_rd_addr ), //i
    .arr_rd_data          ( tpram_if.arr_rd_data ), //o
    .arr_rd_ack           ( tpram_if.arr_rd_ack  ), //o
    .arr_rd_rdy           ( tpram_if.arr_rd_rdy  ), //o

    .wr_en                ( tpram_if.wr_en       ), //o
    .wr_addr              ( tpram_if.wr_addr     ), //o
    .wr_data              ( tpram_if.wr_data     ), //o
    .rd_en                ( tpram_if.rd_en       ), //o
    .rd_addr              ( tpram_if.rd_addr     ), //o
    .rd_data              ( tpram_if.rd_data     ), //i
    .rd_ack               ( tpram_if.rd_ack      ), //i
    .rd_rdy               ( tpram_if.rd_rdy      ), //i
    .wr_rdy               ( tpram_if.wr_rdy      )  //i
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
