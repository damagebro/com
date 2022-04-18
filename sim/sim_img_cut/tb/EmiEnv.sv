class EmiEnv;

vEmiIf m_emi_vif;
// event all_done;

DRAM cDRAM;
EmiResp cEmiResp;

extern function new( input vEmiIf emi_vif );
extern function build();
extern task run();

endclass:EmiEnv

function EmiEnv::new( input vEmiIf emi_vif );
    m_emi_vif = emi_vif;
endfunction:new
function EmiEnv::build();
    cDRAM = new();
    cDRAM.create();
    cDRAM.init( top.tc_dir );

    cEmiResp = new( m_emi_vif, cDRAM );
endfunction:build

task EmiEnv::run();
    fork
        cEmiResp.run();
    join_none

    @top.all_done;
    cDRAM.destroy();
endtask:run
