/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/18-17:54:54
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_rch_dbg_v
`define com_emi_rch_dbg_v
module com_emi_rch_dbg #( parameter
    AW      = 32        ,
    DW      = 128       ,
    RCH     = 4         ,
    MAX_RCH = 16        ,
    MAX_OSD = 16        ,
    USR_W   = 0         ,
    STR_LOG_PREFIX = "" ,

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_RCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               , //spyglass disable W240
//dp---
input  wire                     arvalid             ,
input  wire                     arready             ,
input  wire [IW-1:0]            arid                ,
input  wire [AW-1:0]            araddr              , //spyglass disable W240
input  wire [7:0]               arlen               ,

input  wire                     rvalid              ,
input  wire                     rready              ,
input  wire [IW-1:0]            rid                 ,
input  wire [DW-1:0]            rdata               ,
input  wire                     rlast               //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  [31:0] rc_rareq_cnt;
reg  [31:0] rc_rdreq_cnt;
reg  [31:0] rc_ra_cnt;
reg  [31:0] rc_rd_cnt;
reg  [RCH-1:0][31:0] arc_rach_cnt;//max 16 channel;
reg  [RCH-1:0][31:0] arc_rdch_cnt;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_rareq_cnt <= 'b0;
        rc_rdreq_cnt <= 'b0;
        rc_ra_cnt <= 'b0;
        rc_rd_cnt <= 'b0;
        arc_rach_cnt <= 'b0;
        arc_rdch_cnt <= 'b0;
    end
    else begin
        if( arvalid&&arready )
            rc_rareq_cnt <= rc_rareq_cnt + 1'b1;
        if( rvalid&&rready && rlast )
            rc_rdreq_cnt <= rc_rdreq_cnt + 1'b1;

        if( arvalid&&arready )
            rc_ra_cnt <= rc_ra_cnt + arlen + 1'b1;
        if( rvalid&&rready )
            rc_rd_cnt <= rc_rd_cnt + 1'b1;

        for( int i=0; i<RCH; i++ )begin
            if( arvalid&&arready && arid==i )
                arc_rach_cnt[i] <= arc_rach_cnt[i] + arlen + 1'b1;
            if( rvalid&&rready && rid==i )
                arc_rdch_cnt[i] <= arc_rdch_cnt[i] + 1'b1;
        end
    end
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
      cmd = $sformatf("rm `find ./%s | grep 'emi_dbg_r*'`; echo ' ###rm `find ./%s | grep 'emi_dbg_r*'` ",dump_dir,dump_dir);
      $system(cmd);
  end

  //dump func---
  always @(posedge clk)
  begin
      if( arvalid&&arready )
          F_fwrite_ra( arid );
      if( rvalid&&rready )
          F_fwrite_rd( rid );
  end

  //func declare---
  //function----------------------------------------------------------------
  function automatic F_fwrite_ra( int ch_id );
      //file:emi_dbg_ra.txt
      //time:dddddddd,  addr:xxxxxxxx,  cnt:dddddddd
      integer fp;
      string fn = {dump_dir,STR_LOG_PREFIX,"emi_dbg_ra",$sformatf("%1d",ch_id),".txt"};
      string s1 = $sformatf( "time:%-8d,  addr:0x%8h, len:%1d, cnt:%-8d",$time, araddr,arlen, arc_rach_cnt[ch_id] );

      fp = $fopen(fn,"at");
      if( fp==0 )begin
          $display("NOTICE(), no such file or dictionary: %s\n",fn);
          $stop;
      end

      $fwrite(fp, "%s\n", s1);
      $fclose(fp);
  endfunction
  function automatic F_fwrite_rd( int ch_id );
      //file:emi_dbg_rd.txt
      //time:dddddddd,  data:xxxxxxxx..xxxxxxxx,  cnt:dddddddd
      integer fp;
      string fn = {dump_dir,STR_LOG_PREFIX,"emi_dbg_rd",$sformatf("%1d",ch_id),".txt"};
      string s1 = $sformatf( "time:%-8d,  data:%h,  cnt:%-8d",$time, rdata, arc_rdch_cnt[ch_id] );

      fp = $fopen(fn,"at");
      if( fp==0 )begin
          $display("NOTICE(), no such file or dictionary: %s\n",fn);
          $stop;
      end

      $fwrite(fp, "%s\n", s1);
      $fclose(fp);
  endfunction

`endif //end of DUMP_EMI
//synopsys translate_on

endmodule //end of com_emi_rch_dbg
`endif //end of com_emi_rch_dbg_v

