`timescale 1ns/1ps

program automatic ram_case_prog #( parameter
    AW      = 4,
    DW      = 16,
    STRB_W  = 2
)
(
ram_if #(AW,DW,STRB_W).drv ram_bus,
output logic                    o_done
);

ram_drv #(AW,DW,STRB_W) drv;

initial begin
    o_done = 1'b0;
    drv = new(ram_bus);
    drv.run();
    o_done = 1'b1;
end

endprogram
