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
//pipe
//-------------------------------------------------------
import PipePkg::*;
PipeIf #(.NUM_PIPE(PIPE_N)) pipe_if( .clk(clk) );
pipe_test pipe_t1( pipe_if );
com_pipe_vld #(
    .PIPE_NUM                       ( PIPE_N                      )  //2
)u_com_pipe_vld(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( clear                ), //i
    .i_rx_vld            ( pipe_if.ivld            ), //i
    .o_rx_rdy            ( pipe_if.irdy            ), //o
    .o_tx_vld            ( pipe_if.ovld            ), //o
    .i_tx_rdy            ( pipe_if.ordy            ), //i
    .o_rx_pipe_upen      ( pipe_if.pipe_upen       )  //o
);

//-------------------------------------------------------
//tpram1ck_mate
//-------------------------------------------------------
/*
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
*/

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
