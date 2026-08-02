`timescale 1ns/1ps

program automatic axi_case_prog #( parameter
    CASE_KIND = 0,
    WCH       = 1,
    RCH       = 1,
    AW        = 16,
    DW        = 32,
    EBUS_LW   = 16,
    LW        = 4,
    IW        = 1,
    UW        = 2
)
(
axi_if #(WCH,RCH,AW,DW,EBUS_LW,LW,IW,UW).drv axi_bus,
output logic                                      o_done
);

axi_drv #(CASE_KIND,WCH,RCH,AW,DW,EBUS_LW,LW,IW,UW) drv;

initial begin
    o_done = 1'b0;
    drv = new(axi_bus);
    drv.run();
    o_done = 1'b1;
end

endprogram
