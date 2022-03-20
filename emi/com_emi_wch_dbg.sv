/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/18-16:37:22
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_wch_dbg_v
`define com_emi_wch_dbg_v
module com_emi_wch_dbg #( parameter
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
input  wire                     clear               ,

input  wire                     awvalid             ,
input  wire                     awready             ,
input  wire [IW-1:0]            awid                ,
input  wire [AW-1:0]            awaddr              ,
input  wire [7:0]               awlen               ,

input  wire                     wvalid              ,
input  wire                     wready              ,
input  wire [DW-1:0]            wdata               ,
input  wire                     wlast               ,

input  wire                     bvalid              ,
input  wire                     bready              ,
input  wire [IW-1:0]            bid                 //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  [31:0] rc_wareq_cnt;//requset number
reg  [31:0] rc_wdreq_cnt;
reg  [31:0] rc_wbreq_cnt;
reg  [31:0] rc_wa_cnt;//data number
reg  [31:0] rc_wd_cnt;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_wareq_cnt <= 'b0;
        rc_wdreq_cnt <= 'b0;
        rc_wbreq_cnt <= 'b0;
        rc_wa_cnt <= 'b0;
        rc_wd_cnt <= 'b0;
    end
    else begin
        if( awvalid&&awready )
            rc_wareq_cnt <= rc_wareq_cnt + 1'b1;
        if( wvalid&&wready && wlast )
            rc_wdreq_cnt <= rc_wdreq_cnt + 1'b1;
        if( bvalid&&bready )
            rc_wbreq_cnt <= rc_wbreq_cnt + 1'b1;
        if( awvalid&&awready )
            rc_wa_cnt <= rc_wa_cnt + awlen + 1'b1;
        if( wvalid&&wready )
            rc_wd_cnt <= rc_wd_cnt + 1'b1;
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
      cmd = $sformatf("rm `find ./%s | grep 'emi_dbg_w*'`; echo ' ###rm `find ./%s | grep 'emi_dbg_w*'` '",dump_dir,dump_dir);
      $system(cmd);
  end

  //dump func---
  always @(posedge clk)
  begin
      if( awvalid&&awready )
          F_fwrite_wa();
      if( wvalid&&wready )
          F_fwrite_wd();
  end

  //func declare---
  //function----------------------------------------------------------------
  function automatic F_fwrite_wa();
      //file:emi_dbg_wa.txt
      //time:dddddddd,  addr:xxxxxxxx,  id:dd,  cnt:dddddddd
      integer fp;
      string fn = {dump_dir,STR_LOG_PREFIX,"emi_dbg_wa.txt"};
      string s1 = $sformatf( "time:%-8d,  addr:0x%8h, len:%1d,  id:%-2d,  cnt:%-8d",$time, awaddr,awlen, awid, rc_wa_cnt );

      fp = $fopen(fn,"at");
      if( fp==0 )begin
          $display("NOTICE(), no such file or dictionary: %s\n",fn);
          $stop;
      end

      $fwrite(fp, "%s\n", s1);
      $fclose(fp);
  endfunction
  function automatic F_fwrite_wd();
      //file:emi_dbg_wd.txt
      //time:dddddddd,  data:xxxxxxxx..xxxxxxxx,  cnt:dddddddd
      integer fp;
      string fn = {dump_dir,STR_LOG_PREFIX,"emi_dbg_wd.txt"};
      string s1 = $sformatf( "time:%-8d,  data:%h,  cnt:%-8d",$time, wdata, rc_wd_cnt );

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

endmodule //end of com_emi_wch_dbg
`endif //end of com_emi_wch_dbg_v

