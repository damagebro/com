class EmiStimWch;
import EmiPkg::*;
localparam EMI_SW = EMI_DW/8;
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

StuCmd m_stu_wcmd[$];
StuDat m_stu_wdat[$];

StuCmd m_stu_wa2wd_que[$];
bit m_ra_que[$];
bit m_wb_que[$];

extern function new( vEmiIf emi_vif );
extern function build();
extern function get_stim();
extern task run();

extern task emi_init_stim();
extern task emi_wa_stim();
extern task emi_wd_stim();
extern task emi_wb_stim();

endclass:EmiStimWch

function EmiStimWch::new( vEmiIf emi_vif );
    m_emi_vif = emi_vif;
endfunction:new
function EmiStimWch::build();
endfunction:build
function EmiStimWch::get_stim();
    StuCmd stu_cmd;
    StuDat stu_dat;
    int wa_cnt;

    wa_cnt = 0;
    stu_cmd.addr = 'h0000;
    stu_cmd.len  = 31;
    m_stu_wcmd.push_back(stu_cmd);
    wa_cnt = wa_cnt + stu_cmd.len+1;
    stu_cmd.addr = 'h00f0;
    m_stu_wcmd.push_back(stu_cmd);
    wa_cnt = wa_cnt + stu_cmd.len+1;
    for( int i=0; i<wa_cnt; i++ )begin
        stu_dat.data = i;
        m_stu_wdat.push_back(stu_dat);
    end
endfunction:get_stim

task EmiStimWch::emi_init_stim();
    @(m_emi_vif.rcb);
    m_emi_vif.rcb.emi_arvalid <= 0;
    m_emi_vif.rcb.emi_araddr  <= 0;
    m_emi_vif.rcb.emi_arlen   <= 0;
    m_emi_vif.rcb.emi_aruser  <= 0;

    m_emi_vif.wcb.emi_awvalid <= 0;
    m_emi_vif.wcb.emi_awaddr  <= 0;
    m_emi_vif.wcb.emi_awlen   <= 0;
    m_emi_vif.wcb.emi_awuser  <= 0;
    m_emi_vif.wcb.emi_wvalid <= 0;
    m_emi_vif.wcb.emi_wdata  <= 0;
    m_emi_vif.wcb.emi_wstrb  <= 0;
    m_emi_vif.wcb.emi_wlast  <= 0;
    m_emi_vif.wcb.emi_wuser  <= 0;
endtask:emi_init_stim
task EmiStimWch::emi_wa_stim();
    StuCmd stu_cmd;
    m_emi_vif.wcb.emi_awuser <= 0;
    forever begin
        @(m_emi_vif.wcb);
        if( m_stu_wcmd.size() )begin
            stu_cmd = m_stu_wcmd.pop_front();
            m_emi_vif.wcb.emi_awvalid <= 1'b1;
            m_emi_vif.wcb.emi_awaddr  <= stu_cmd.addr;
            m_emi_vif.wcb.emi_awlen   <= stu_cmd.len ;
            do
                @(m_emi_vif.wcb);
            while( !m_emi_vif.wcb.emi_awready );
            m_emi_vif.wcb.emi_awvalid <= 1'b0;
            m_stu_wa2wd_que.push_back(stu_cmd);
        end
    end
endtask:emi_wa_stim
task EmiStimWch::emi_wd_stim();
    StuCmd stu_cmd;
    StuDat stu_dat;
    bit vld;
    int wcnt = 0;
    forever begin
        @(m_emi_vif.wcb);
        if( m_stu_wa2wd_que.size() )begin
            wcnt = 0;
            stu_cmd = m_stu_wa2wd_que.pop_front();
            while( wcnt<stu_cmd.len+1 )begin
                @(m_emi_vif.wcb);
                vld = $random%2;
                if( vld )begin
                    stu_dat = m_stu_wdat.pop_front();
                    m_emi_vif.wcb.emi_wvalid<= 1'b1;
                    m_emi_vif.wcb.emi_wdata <= stu_dat.data;
                    m_emi_vif.wcb.emi_wstrb <= stu_dat.strb;
                    m_emi_vif.wcb.emi_wlast <= wcnt==stu_cmd.len;
                    do
                        @(m_emi_vif.wcb);
                    while( !m_emi_vif.wcb.emi_wready );
                    m_emi_vif.wcb.emi_wvalid <= 1'b0;
                    m_emi_vif.wcb.emi_wlast  <= 1'b0;
                    wcnt++;
                end//end if( m_emi_vif.emi_wvalid )
            end//end for
        end//end if( m_stu_wa2wd_que.size )
    end//end forever
endtask:emi_wd_stim
task EmiStimWch::emi_wb_stim();
endtask:emi_wb_stim

task EmiStimWch::run();
    get_stim();
    emi_init_stim();
    fork
        emi_wa_stim();
        emi_wd_stim();
    join_none
endtask:run
