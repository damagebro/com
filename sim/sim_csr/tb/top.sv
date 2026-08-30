`timescale 1ns/1ps

module top;

wire core_done;
wire bridge_done;
wire regslice_done;

csr_core_case u_csr_core_case
(
    .o_done (core_done)
);

csr_bridge_case u_csr_bridge_case
(
    .o_done (bridge_done)
);

csr_regslice_case u_csr_regslice_case
(
    .o_done (regslice_done)
);

initial begin
    wait( core_done && bridge_done && regslice_done );
    #20;
    $display("SIM_CSR PASS");
    $finish;
end

initial begin
    #20000;
    $fatal(1, "sim csr timeout");
end

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
