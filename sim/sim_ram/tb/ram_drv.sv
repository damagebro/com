`timescale 1ns/1ps

module ram_drv #( parameter
    AW      = 4,
    DW      = 16,
    STRB_W  = 2
)
(
    ram_if       ram_bus,
    output logic o_done
);

task automatic T_drive_idle;
begin
    ram_bus.drv_cb.clear       <= 1'b0;
    ram_bus.drv_cb.arb_wr_addr <= '0;
    ram_bus.drv_cb.arb_wr_data <= '0;
    ram_bus.drv_cb.arb_wr_vld  <= '0;
    ram_bus.drv_cb.arb_rd_addr <= '0;
    ram_bus.drv_cb.arb_rd_vld  <= '0;
    ram_bus.drv_cb.sp_wr_addr  <= '0;
    ram_bus.drv_cb.sp_wr_data  <= '0;
    ram_bus.drv_cb.sp_wr_vld   <= '0;
    ram_bus.drv_cb.sp_rd_addr  <= '0;
    ram_bus.drv_cb.sp_rd_vld   <= 1'b0;
    ram_bus.drv_cb.rmw_wr_addr <= '0;
    ram_bus.drv_cb.rmw_wr_data <= '0;
    ram_bus.drv_cb.rmw_wr_vld  <= '0;
    ram_bus.drv_cb.rmw_rd_addr <= '0;
    ram_bus.drv_cb.rmw_rd_vld  <= 1'b0;
    ram_bus.drv_cb.sp2_wr_addr <= '0;
    ram_bus.drv_cb.sp2_wr_data <= '0;
    ram_bus.drv_cb.sp2_wr_vld  <= '0;
    ram_bus.drv_cb.sp2_rd_addr <= '0;
    ram_bus.drv_cb.sp2_rd_vld  <= 1'b0;
end
endtask

task automatic T_smoke_access;
begin
    ram_bus.drv_cb.arb_wr_addr[0] <= 4'h1;
    ram_bus.drv_cb.arb_wr_data[0] <= 16'h1001;
    ram_bus.drv_cb.arb_wr_vld[0]  <= 2'b11;
    ram_bus.drv_cb.arb_rd_addr[1] <= 4'h2;
    ram_bus.drv_cb.arb_rd_vld[1]  <= 1'b1;
    ram_bus.drv_cb.sp_wr_addr     <= 4'h3;
    ram_bus.drv_cb.sp_wr_data     <= 16'h3003;
    ram_bus.drv_cb.sp_wr_vld      <= 2'b11;
    ram_bus.drv_cb.rmw_wr_addr    <= 4'h4;
    ram_bus.drv_cb.rmw_wr_data    <= 16'h40aa;
    ram_bus.drv_cb.rmw_wr_vld     <= 2'b01;
    ram_bus.drv_cb.sp2_wr_addr    <= 4'h5;
    ram_bus.drv_cb.sp2_wr_data    <= 16'h5005;
    ram_bus.drv_cb.sp2_wr_vld     <= 2'b11;
end
endtask

initial begin
    o_done              = 1'b0;
    ram_bus.rst_n       = 1'b0;
    ram_bus.clear       = 1'b0;
    ram_bus.arb_wr_addr = '0;
    ram_bus.arb_wr_data = '0;
    ram_bus.arb_wr_vld  = '0;
    ram_bus.arb_rd_addr = '0;
    ram_bus.arb_rd_vld  = '0;
    ram_bus.sp_wr_addr  = '0;
    ram_bus.sp_wr_data  = '0;
    ram_bus.sp_wr_vld   = '0;
    ram_bus.sp_rd_addr  = '0;
    ram_bus.sp_rd_vld   = 1'b0;
    ram_bus.rmw_wr_addr = '0;
    ram_bus.rmw_wr_data = '0;
    ram_bus.rmw_wr_vld  = '0;
    ram_bus.rmw_rd_addr = '0;
    ram_bus.rmw_rd_vld  = 1'b0;
    ram_bus.sp2_wr_addr = '0;
    ram_bus.sp2_wr_data = '0;
    ram_bus.sp2_wr_vld  = '0;
    ram_bus.sp2_rd_addr = '0;
    ram_bus.sp2_rd_vld  = 1'b0;

    repeat(5) @(ram_bus.drv_cb);
    ram_bus.drv_cb.rst_n <= 1'b1;
    repeat(2) @(ram_bus.drv_cb);
    T_smoke_access();
    @(ram_bus.drv_cb);
    T_drive_idle();
    repeat(20) @(ram_bus.drv_cb);
    o_done = 1'b1;
end

endmodule
