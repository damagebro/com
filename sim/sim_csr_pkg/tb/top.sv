`timescale 1ns/1ps

module top #(
    parameter EBUS_DW = 64
);

wire pkg_done;

csr_pkg_case #(
    .EBUS_DW (EBUS_DW)
)u_csr_pkg_case
(
    .o_done (pkg_done)
);

initial begin
    wait( pkg_done );
    #20;
    $display("SIM_CSR_PKG PASS");
    $finish;
end

initial begin
    #50000;
    $fatal(1, "sim csr pkg timeout");
end

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
