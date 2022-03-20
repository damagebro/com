class EmiEnv;

`include "EmiPkg.sv"

vEmiIf m_emi_vif;
vEmiIf m_emi_vif_wch[];
vEmiIf m_emi_vif_rch[];
event all_done;

DRAM cDRAM;
EmiResp cEmiResp;
EmiStimWch pcEmiStimWch[];
EmiStimRch pcEmiStimRch[];
mailbox m_gen2resp;

extern function new( input vEmiIf emi_vif,
                     input vEmiIf emi_vif_wch[],
                     input vEmiIf emi_vif_rch[]  );
extern function build();
extern task run();

endclass:EmiEnv

function EmiEnv::new( input vEmiIf emi_vif,
                      input vEmiIf emi_vif_wch[],
                      input vEmiIf emi_vif_rch[] );
    m_emi_vif = emi_vif;
    m_emi_vif_wch = new[ emi_vif_wch.size() ];
    foreach( emi_vif_wch[i] ) m_emi_vif_wch[i] = emi_vif_wch[i];
    m_emi_vif_rch = new[ emi_vif_rch.size() ];
    foreach( emi_vif_rch[i] ) m_emi_vif_rch[i] = emi_vif_rch[i];
endfunction:new
function EmiEnv::build();
    pcEmiStimWch = new[EmiPkg::EMI_WCH];
    pcEmiStimRch = new[EmiPkg::EMI_RCH];
    cDRAM = new();
    cDRAM.create();
    cDRAM.init( top.tc_dir );

    cEmiResp = new( m_emi_vif, cDRAM );
    foreach( pcEmiStimWch[i] ) pcEmiStimWch[i] = new( m_emi_vif_wch[i] );
    foreach( pcEmiStimRch[i] ) pcEmiStimRch[i] = new( m_emi_vif_rch[i] );
endfunction:build

task EmiEnv::run();
    fork
        foreach( pcEmiStimWch[i] ) pcEmiStimWch[i].run();
        foreach( pcEmiStimRch[i] ) pcEmiStimRch[i].run();
        cEmiResp.run();
    join_none

    @all_done;
    cDRAM.destroy();
endtask:run
