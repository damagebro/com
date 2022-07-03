/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/19-09:36:51
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_wch_perf_v
`define com_emi_wch_perf_v
module com_emi_wch_perf #( parameter
    AW      = 32        ,
    DW      = 128       ,
    MAX_WCH = 16        ,
    MAX_OSD = 16        ,
    USR_W   = 0         ,
    STR_LOG_PREFIX = "" ,

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_WCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
//cfg&status---
input  wire                     sw_stat_enable      , //0:hw stat, 1:sw control stat
input  wire                     sw_stat_start       , //pulse signal
input  wire                     sw_stat_done        , //pulse signal
input  wire                     sw_stat_clear       , //pulse signal
input  wire [31:0]              sw_stat_bw_period   ,
//dp---
input  wire                     awvalid             ,
input  wire                     awready             ,
input  wire [7:0]               awlen               , //spyglass disable W240

input  wire                     wvalid              ,
input  wire                     wready              ,
input  wire                     wlast               //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  rcb_perf_stat_flag;

reg  [15:0] rc_la_cnt; //ring cnt of 0~2^16;
reg  [31:0] rc_bw_cnt; //every bw period, number of data transfer;
reg  [7:0][15:0] arc_la_val; // the latest 8's burst transfer, the latency record value;
reg  [7:0][31:0] arc_bw_val; // the latest 8's bw stat period, the bw record value;
//wire declare---------------------------------------------------------------
wire clear = sw_stat_clear;

wire hw_stat_start = !rcb_perf_stat_flag && (awvalid&&awready) && !sw_stat_enable;
wire [31:0] hw_stat_bw_period = 32'd100_0000;

wire stat_start = sw_stat_enable ? sw_stat_start : hw_stat_start;
wire stat_done  = sw_stat_enable ? sw_stat_done  : 1'b0;
wire [31:0] stat_bw_period = sw_stat_enable ? sw_stat_bw_period : hw_stat_bw_period;
//statement------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rcb_perf_stat_flag <= 1'b0;
    end
    else if( clear || stat_done )begin
        rcb_perf_stat_flag <= 1'b0;
    end
    else if( stat_start )begin
        rcb_perf_stat_flag <= 1'b1;
    end
end

//latency---
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_la_cnt <= 'b0;
    else if( clear || stat_start )
        rc_la_cnt <= 'b0;
    else if( rcb_perf_stat_flag )
        rc_la_cnt <= rc_la_cnt + 1'b1;
end

wire wa_hs = awvalid && awready;
wire wd_hs = wvalid && wready && wlast;

wire        la_wr_en    = (rcb_perf_stat_flag||stat_start) && wa_hs;
wire [15:0] la_wr_data  = stat_start ? 16'b0 : rc_la_cnt;
wire        la_wr_full  ;
wire        la_rd_en    ;
wire [15:0] la_rd_data  ;
wire        la_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 16       ), //8
    .DEPTH      ( MAX_OSD+4)  //4
)r_com_sync_fifo_reg_la
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( la_wr_en             ), //i
    .wr_data              ( la_wr_data           ), //i
    .wr_full              ( la_wr_full           ), //o
    .rd_en                ( la_rd_en             ), //i
    .rd_data              ( la_rd_data           ), //o
    .rd_empty             ( la_rd_empty          ), //o
    .water_level          (                      )  //o
);
wire        ld_wr_en    = (rcb_perf_stat_flag||stat_start) && wd_hs;
wire [15:0] ld_wr_data  = stat_start ? 16'b0 : rc_la_cnt;
wire        ld_wr_full  ;
wire        ld_rd_en    ;
wire [15:0] ld_rd_data  ;
wire        ld_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 16       ), //8
    .DEPTH      ( MAX_OSD+4)  //4
)r_com_sync_fifo_reg_ld
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( ld_wr_en             ), //i
    .wr_data              ( ld_wr_data           ), //i
    .wr_full              ( ld_wr_full           ), //o
    .rd_en                ( ld_rd_en             ), //i
    .rd_data              ( ld_rd_data           ), //o
    .rd_empty             ( ld_rd_empty          ), //o
    .water_level          (                      )  //o
);
assign la_rd_en = !la_rd_empty && !ld_rd_empty;
assign ld_rd_en = !la_rd_empty && !ld_rd_empty;
//assert( !la_wr_full );
wire [15:0] ta = la_rd_data;
wire [15:0] td = ld_rd_data;
wire [16:0] td_comp = 17'h1_0000 - ta;
wire [16:0] t_minus = td - ta; //spyglass disable W164b
wire b_wd_before_wa = td<=ta && ta[15]==td[15]; //ta[15]==td[15] means not la_cnt ovf;
wire [15:0] t_span = b_wd_before_wa ? 16'b0 : !t_minus[16] ? t_minus[15:0] : (td+td_comp[15:0]);

reg  [18:0] rb_la_sum;
wire [15:0] la_avg = rb_la_sum>>3; //spyglass disable W528
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_la_val <= 'b0;
    else if( clear )
        arc_la_val <= 'b0;
    else if( la_rd_en )begin
        arc_la_val[0] <= t_span;//spyglass disable W164b
        for( int i=1; i<8; i++ )
            arc_la_val[i] <= arc_la_val[i-1];
    end
end
always @*
begin
    rb_la_sum = 0;
    for( int i=0; i<8; i++ )
        rb_la_sum = rb_la_sum + arc_la_val[i];  //spyglass disable SelfAssignment-ML,W415a
end

//bandwidth---
reg  [31:0] rc_bw_runcnt;
wire bw_done = rc_bw_runcnt==stat_bw_period;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bw_runcnt <= 'b0;
    else if( clear || bw_done )
        rc_bw_runcnt <= 'b0;
    else if( rcb_perf_stat_flag )
        rc_bw_runcnt <= rc_bw_runcnt + 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bw_cnt <= 'b0;
    else if( clear || bw_done )
        rc_bw_cnt <= 'b0;
    else if( rcb_perf_stat_flag && wvalid&&wready )
        rc_bw_cnt <= rc_bw_cnt + 1'b1;
end

reg  [2:0] rc_bw_idx;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bw_idx <= 'b0;
    else if( clear )
        rc_bw_idx <= 'b0;
    else if( bw_done )
        rc_bw_idx <= rc_bw_idx + 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_bw_val <= 'b0;
    else if( clear )
        arc_bw_val <= 'b0;
    else if( bw_done )
        arc_bw_val[rc_bw_idx] <= rc_bw_cnt; //spyglass disable W528
end


//synopsys translate_off
`ifdef DUMP_EMI
  //init---
  string  dump_dir;
  string  cmd;
  initial begin
      dump_dir = "./dump_emi/";

      cmd = $sformatf("if [ ! -d %s ]; then mkdir %s; echo '###mkdir %s directory'; fi",dump_dir,dump_dir,dump_dir);
      $system(cmd);
      cmd = $sformatf("rm `find ./%s | grep 'emi_perf*'`; echo ' ###rm `find ./%s | grep 'emi_perf*'` '",dump_dir,dump_dir);
      $system(cmd);
  end

  always @(posedge clk)
  begin
      if( la_rd_en )
          F_fwrite_latency( t_span );
      if( bw_done )
          F_fwrite_bandwidth( rc_bw_cnt );
  end

  //func declare---
  //function----------------------------------------------------------------
  function automatic F_fwrite_latency( int cnt );
      //file:emi_perf_latency.txt
      //time:dddddddd,  delay:ddddd
      integer fp;
      string fn = {dump_dir,STR_LOG_PREFIX,"emi_perf_wch_latency.txt"};
      string s1 = $sformatf( "time:%-8d,  delay:%-5d\n",$time, cnt);

      fp = $fopen(fn,"at");
      if( fp==0 )begin
          $display("NOTICE(), no such file or dictionary: %s\n",fn);
          $stop;
      end

      $fwrite(fp, "%s", s1);
      $fclose(fp);
  endfunction
  function automatic F_fwrite_bandwidth( int cnt );
      //file:emi_perf_bandwidth.txt
      //time:dddddddd,  data_cnt:dddddddd
      integer fp;
      string fn = {dump_dir,STR_LOG_PREFIX,"emi_perf_wch_bandwidth.txt"};
      string s1 = $sformatf( "time:%-8d,  data_cnt:%-8d\n",$time, cnt);

      fp = $fopen(fn,"at");
      if( fp==0 )begin
          $display("NOTICE(), no such file or dictionary: %s\n",fn);
          $stop;
      end

      $fwrite(fp, "%s", s1);
      $fclose(fp);
  endfunction
`endif //end of DUMP_EMI
//synopsys translate_on

endmodule //end of com_emi_wch_perf
`endif //end of com_emi_wch_perf_v

