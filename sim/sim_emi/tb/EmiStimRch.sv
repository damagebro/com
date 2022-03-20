class EmiStimRch;
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

StuCmd m_stu_rcmd[$];
bit m_ra_que[$];

extern function new( vEmiIf emi_vif );
extern function build();
extern function get_stim();
extern task run();

extern task emi_init_stim();
extern task emi_ra_stim();
extern task emi_rd_stim();

endclass:EmiStimRch

function EmiStimRch::new( vEmiIf emi_vif );
    m_emi_vif = emi_vif;
endfunction:new
function EmiStimRch::build();
endfunction:build
function EmiStimRch::get_stim();
    StuCmd stu_cmd;
    StuDat stu_dat;
    int wa_cnt;
    stu_dat.strb = 'hffff;
    stu_cmd.addr = 'h0ff0;
    stu_cmd.len  = 9;
    m_stu_rcmd.push_back(stu_cmd);
    stu_cmd.addr = 'h1040;
    m_stu_rcmd.push_back(stu_cmd);
endfunction:get_stim

task EmiStimRch::emi_init_stim();
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
task EmiStimRch::emi_ra_stim();
    StuCmd stu_cmd;
    m_emi_vif.rcb.emi_aruser <= 0;
    forever begin
        @(m_emi_vif.rcb);
        if( m_stu_rcmd.size() )begin
            stu_cmd = m_stu_rcmd.pop_front();
            m_emi_vif.rcb.emi_arvalid <= 1'b1;
            m_emi_vif.rcb.emi_araddr  <= stu_cmd.addr;
            m_emi_vif.rcb.emi_arlen   <= stu_cmd.len ;
            do
                @(m_emi_vif.rcb);
            while( !m_emi_vif.rcb.emi_arready );
            m_emi_vif.rcb.emi_arvalid <= 1'b0;
        end
    end
endtask:emi_ra_stim
task EmiStimRch::emi_rd_stim();
endtask:emi_rd_stim

task EmiStimRch::run();
    get_stim();
    emi_init_stim();
    fork
        emi_ra_stim();
        emi_rd_stim();
    join_none
endtask:run
