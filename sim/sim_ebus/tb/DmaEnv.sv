class DmaEnv;

// mailbox mbx_gen2drv;
// event evt_gen2drv;
vDmaIf m_dma_vif;
vEmiIf m_emi_vif;

DRAM cDRAM;
DmaDrv cDmaDrv;
EmiResp cEmiResp;


extern function new( input vEmiIf emi_vif, input vDmaIf dma_vif );
extern function build();
extern task run();

endclass //DmaEnv

function DmaEnv::new( input vEmiIf emi_vif, input vDmaIf dma_vif );
    m_emi_vif = emi_vif;
    m_dma_vif = dma_vif;
endfunction:new
function DmaEnv::build();
    cDRAM = new();
    cDRAM.create();
    cDRAM.init( "../tc/" );

    cDmaDrv = new( m_dma_vif );
    cEmiResp = new( m_emi_vif, cDRAM );
endfunction:build

task DmaEnv::run();
    fork
        cDmaDrv.run();
        cEmiResp.run();
    join_none

    @top.all_done;
    cDRAM.destroy();
endtask:run

