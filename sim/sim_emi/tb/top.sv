module top();

bit clk   ;
bit rst_n ;
bit clear ;
bit pclk   ;
bit prst_n ;

always #2   clk= ~clk;
always #3   pclk= ~pclk;

task reset();
    prst_n = 1'b0;
    #10; rst_n = 1'b1; prst_n = 1'b1;
    #15; rst_n = 1'b0;
    #20; rst_n = 1'b1;
endtask //reset_isp
task xclear();
    @( posedge clk ); clear <= 1'b0;
    @( posedge clk ); clear <= 1'b1;
    @( posedge clk ); clear <= 1'b0;
endtask //reset_isp

//-------------------------------------------------------
//ENV ARGV
//-------------------------------------------------------
string tc_dir = "../tc/";
initial begin
    $value$plusargs("TC_DIR=%s", tc_dir);
    #10;
    $display("argv tc_dir:%s",tc_dir);
end

//-------------------------------------------------------
//com_emi_rch
//-------------------------------------------------------
import EmiPkg::*;
com_emi_if #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH) )  usr_emi_wrif[EMI_WCH-1:0] ();
com_emi_if #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH) )  usr_emi_rdif[EMI_RCH-1:0] ();
com_emi_if #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH) )  ext_emi_if();

wire [7:0]               max_burst_len = 8'h7;
wire                     clr_ongoing   ;
com_emi_wrap #(
    .AW         ( EMI_AW         ), //32
    .DW         ( EMI_DW         ), //128
    .USR_W      ( EMI_USR_W      ), //0
    .RCH        ( EMI_RCH        ), //4
    .WCH        ( EMI_WCH        ), //4
    .MAX_CH     ( EMI_MAX_CH     ), //16
    .STR_LOG_PREFIX ( STR_LOG_PREFIX )
)u_com_emi_wrap
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg&status---
    .max_burst_len        ( max_burst_len        ), //i
    .clr_ongoing          ( clr_ongoing          ), //o
    //dp---
    .usr_emi_rdifs        ( usr_emi_rdif         ), //if
    .usr_emi_wrifs        ( usr_emi_wrif         ), //if
    .ext_emi_ifm          ( ext_emi_if           )  //if
);


//-------------------------------------------------------
//emi tb
//-------------------------------------------------------
com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH) )  wch_if[EMI_WCH-1:0] (clk);
com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH) )  rch_if[EMI_RCH-1:0] (clk);
com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH) )  resp_if(clk);
`include "emi_connect.sv";
emi_test inst_test();

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


// initial begin
//     #10;
//     $finish;
// end

endmodule
