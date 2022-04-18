class EmiResp;
// import EmiPkg::*;
localparam EMI_AW = EmiPkg::EMI_AW;
localparam EMI_DW = EmiPkg::EMI_DW;
localparam EMI_SW = EMI_DW/8;
localparam EMI_RCH = EmiPkg::EMI_RCH;
localparam EMI_WCH = EmiPkg::EMI_WCH;
localparam EMI_MAX_CH = EmiPkg::EMI_MAX_CH;

typedef struct{
    int  addr;
    int  len;
    int  id;
} StuCmd;
typedef struct{
    bit [EMI_DW-1:0] data;
    bit [EMI_SW-1:0] strb;
} StuDat;

vEmiIf m_emi_vif;
// mailbox m_gen2resp;
DRAM m_pcDRAM;

StuCmd m_as_rcmd[EMI_MAX_CH][$];
bit    m_ra_que[$];
StuCmd m_stu_wcmd[$];
int    m_wb_que[$];

extern function new( vEmiIf emi_vif, DRAM pcDRAM );
extern function build();
extern task run();

extern task emi_ra_resp();
extern task emi_rd_resp();
extern task emi_wa_resp();
extern task emi_wd_resp();
extern task emi_wb_resp();

endclass:EmiResp

function EmiResp::new( vEmiIf emi_vif, DRAM pcDRAM );
    m_emi_vif = emi_vif;
    m_pcDRAM = pcDRAM;
endfunction:new
function EmiResp::build();
endfunction:build

task EmiResp::emi_ra_resp();
    forever begin
        @(m_emi_vif.cb);
        if( m_emi_vif.cb.emi_arvalid )begin
            StuCmd stu_cmd;
            bit rdy;
            rdy = $random%2;
            while( !rdy )begin
                rdy = $random%2;
                @(m_emi_vif.cb);
            end
            m_emi_vif.cb.emi_arready <= 1'b1;
            stu_cmd.id   = m_emi_vif.cb.emi_arid;
            stu_cmd.addr = m_emi_vif.cb.emi_araddr;
            stu_cmd.len  = m_emi_vif.cb.emi_arlen;
            m_as_rcmd[ m_emi_vif.cb.emi_arid ].push_back( stu_cmd );
            // $display("tydbg, ra, addr:%x, len:%1d, id:%1d",stu_cmd.addr,stu_cmd.len,stu_cmd.id);
            m_ra_que.push_back(1);
            @(m_emi_vif.cb);
            m_emi_vif.cb.emi_arready <= 1'b0;
        end
    end
endtask:emi_ra_resp
task EmiResp::emi_rd_resp();
    bit a;
    bit rd_resp_flag;
    int rid;
    StuCmd stu_cmd;
    int rd_cnt;
    int rd_addr;
    bit [7:0] pc_data[];
    bit [EMI_DW-1:0] rd_data;
    pc_data = new[EMI_SW];

    forever begin
        @(m_emi_vif.cb);
        if( rd_resp_flag==0 && m_ra_que.size() )begin
            int rid_s;
            rid_s = $urandom%EMI_MAX_CH;
            for( int i=0; i<EMI_MAX_CH; i++ )begin
                rid = (rid_s+i)%EMI_MAX_CH;
                // $display("tydbg, time:%1d, rid:%1d, tid_s:%1d",$time,rid,rid_s);
                if( m_as_rcmd[rid].size() )begin
                    stu_cmd = m_as_rcmd[rid].pop_front();
                    a = m_ra_que.pop_front();
                    rd_resp_flag = 1;
                    @(m_emi_vif.cb);
                    break;

                end
            end
        end//end if( rd_resp_flag==0 )

        if( rd_resp_flag==1 )begin
            for( int i=0; i<stu_cmd.len+1; i++ )begin
                rd_addr = stu_cmd.addr + i*EMI_SW;
                m_pcDRAM.read_mem( rd_addr, EMI_SW, pc_data );
                for( int j=0; j<EMI_SW; j++ )
                    rd_data[j*8 +:8] = pc_data[j];
                m_emi_vif.cb.emi_rvalid <= 1'b1;
                m_emi_vif.cb.emi_rid    <= rid;
                m_emi_vif.cb.emi_rdata  <= rd_data;
                m_emi_vif.cb.emi_rlast  <= i==stu_cmd.len;
                do
                    @(m_emi_vif.cb);
                while( !m_emi_vif.cb.emi_rready );
                m_emi_vif.cb.emi_rvalid <= 1'b0;
                m_emi_vif.cb.emi_rlast  <= 1'b0;

                if( i==stu_cmd.len )begin
                    rd_resp_flag = 0;
                end
            end
        end//end if( rd_resp_flag==1 )
    end//end forever
endtask:emi_rd_resp
task EmiResp::emi_wa_resp();
    forever begin
        @(m_emi_vif.cb);
        if( m_emi_vif.cb.emi_awvalid )begin
            StuCmd stu_cmd;
            bit rdy;

            // rdy = $random%2;
            // m_emi_vif.cb.emi_awready <= 1'b0;
            // while( !rdy )begin
            //     rdy = $random%2;
            //     @(m_emi_vif.cb);
            // end
            m_emi_vif.cb.emi_awready <= 1'b1;

            stu_cmd.id   = m_emi_vif.cb.emi_awid;
            stu_cmd.addr = m_emi_vif.cb.emi_awaddr;
            stu_cmd.len  = m_emi_vif.cb.emi_awlen;
            m_stu_wcmd.push_back( stu_cmd );
            // $display("tydbg, wa, addr:%x, len:%1d, id:%1d",stu_cmd.addr,stu_cmd.len,stu_cmd.id);
            @(m_emi_vif.cb);
            m_emi_vif.cb.emi_awready <= 1'b0;
        end
    end
endtask:emi_wa_resp
task EmiResp::emi_wd_resp();
    StuDat stu_dat_que[$];
    StuDat stu_dat;
    StuCmd stu_cmd;
    int rdy;

    fork
        m_emi_vif.cb.emi_wready <= 1'b1;
        forever begin:wd_hs
            @(m_emi_vif.cb);
            if( m_emi_vif.cb.emi_wvalid )begin
            // do begin
            //     rdy = $urandom%2;
            //     m_emi_vif.cb.emi_wready <= rdy;
            //     @(m_emi_vif.cb);
            // end
            // while(!rdy);
            // m_emi_vif.cb.emi_wready <= 1'b0;
            stu_dat.data = m_emi_vif.cb.emi_wdata;
            stu_dat.strb = m_emi_vif.cb.emi_wstrb;
            stu_dat_que.push_back( stu_dat );
            end
        end:wd_hs

        forever begin:wd_to_ddr
            @(m_emi_vif.cb);
            if( m_stu_wcmd.size()>0 )begin
                stu_cmd = m_stu_wcmd.pop_front();
                while( stu_dat_que.size()<stu_cmd.len+1 )
                    @(m_emi_vif.cb);

                @(m_emi_vif.cb);
                for( int i=0; i<stu_cmd.len+1; i++ )begin
                    int byte_addr = stu_cmd.addr + i*EMI_SW;
                    bit [7:0] pc_data[];
                    pc_data = new[EMI_SW];
                    stu_dat = stu_dat_que.pop_front();
                    for( int j=0; j<EMI_SW; j++ )
                        pc_data[j] = stu_dat.data[j*8 +:8];
                    m_pcDRAM.write_mem( byte_addr, EMI_SW, pc_data );
                    // $display("tydbg, wd,time:%1d, addr:%x, len:%1d, id:%1d, data:%h",$time,byte_addr,stu_cmd.len,stu_cmd.id, stu_dat.data);
                end

                m_wb_que.push_back(stu_cmd.id);
            end
        end:wd_to_ddr
    join
endtask:emi_wd_resp
task EmiResp::emi_wb_resp();
    int bid;

    m_emi_vif.cb.emi_bid <= 0;
    m_emi_vif.cb.emi_bvalid <= 1'b0;
    forever begin
        @(m_emi_vif.cb);
        if( m_wb_que.size() )begin
            int delay_cnt = 0;
            int delay_tol = 0;
            delay_tol = $random%16;
            while( delay_cnt<delay_tol )begin
                @(m_emi_vif.cb);
                delay_cnt++;
            end
            bid = m_wb_que.pop_front();
            m_emi_vif.cb.emi_bvalid <= 1'b1;
            m_emi_vif.cb.emi_bid <= bid;
            @(m_emi_vif.cb);
            m_emi_vif.cb.emi_bvalid <= 1'b0;
        end
    end
endtask:emi_wb_resp

task EmiResp::run();
    m_emi_vif.cb.emi_awready <= 1'b0;
    m_emi_vif.cb.emi_wready  <= 1'b0;
    m_emi_vif.cb.emi_arready <= 1'b0;
    m_emi_vif.cb.emi_rvalid  <= 1'b0;

    fork
        emi_ra_resp();
        emi_rd_resp();
        emi_wa_resp();
        emi_wd_resp();
        emi_wb_resp();
    join_none
endtask:run