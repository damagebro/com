module top();

bit clk   ;
bit rst_n ;
bit clear ;

always #2   clk= ~clk;

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
import ImgWinPkg::*;
ImgWinIf img_win_if( clk );
img_win_test img_win_t1( img_win_if );
com_img_gen_win #(
    .XW         ( XW         ), //12
    .YW         ( YW         ), //12
    .PW         ( PW         ), //8
    .WIN_W      ( WIN_W      ), //3
    .WIN_H      ( WIN_H      ), //3
    .PIC_W      ( 32      )  //4096
)u_com_img_gen_win
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i


    .pic_width_m1         ( img_win_if.pic_width-1          ), //i
    .pic_heigh_m1         ( img_win_if.pic_heigh-1          ), //i

    .in_sof               ( img_win_if.in_sof               ), //i
    .in_valid             ( img_win_if.in_valid             ), //i
    .in_ready             ( img_win_if.in_ready             ), //o
    .in_data              ( img_win_if.in_data              ), //i
    .in_last              ( img_win_if.in_last              ), //i

    .win_sof              ( img_win_if.win_sof              ), //o
    .win_valid            ( img_win_if.win_valid            ), //o
    .win_ready            ( img_win_if.win_ready            ), //i
    .win_data             ( img_win_if.win_data             ), //o
    .win_last             ( img_win_if.win_last             )  //o
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
